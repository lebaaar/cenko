import 'dart:convert';

import 'package:cenko/core/constants/constants.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class BarcodeService {
  /// Lookup barcode across multiple providers until a product is found.
  /// Returns a map with `status` (1 found / 0 not found) and optional `product` map.
  static Future<Map<String, dynamic>> lookupBarcodeProduct(String barcode) async {
    final providers = <Future<Map<String, dynamic>?> Function()>[
      () => _lookupOpenFoodFacts(barcode),
      () => _lookupUpcItemDb(barcode),
      () => _lookupGtinSearch(barcode),
    ];

    for (final provider in providers) {
      try {
        final result = await provider();
        if (result != null) {
          return result;
        }
      } catch (e) {
        debugPrint('Barcode lookup provider failed: $e');
      }
    }

    return {'status': 0};
  }

  static Future<Map<String, dynamic>?> _lookupOpenFoodFacts(String barcode) async {
    final uri = Uri.parse('$kOpenFoodFactsProductUrl$barcode.json');
    final response = await http.get(uri);

    if (response.statusCode != 200 && response.statusCode != 404) {
      throw StateError('Open Food Facts request failed (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Unexpected product response format from OpenFoodFacts');
    }

    if (_asInt(decoded['status']) == 1 && decoded['product'] is Map<String, dynamic>) {
      final product = Map<String, dynamic>.from(decoded['product'] as Map);
      if (_hasMeaningfulProductName(product)) {
        return {'status': 1, 'product': product};
      }
      return null;
    }

    return null;
  }

  static Future<Map<String, dynamic>?> _lookupUpcItemDb(String barcode) async {
    final uri = Uri.parse('$kUpcItemDbLookupUrl$barcode');
    final response = await http.get(uri);

    if (response.statusCode != 200 && response.statusCode != 404) {
      throw StateError('UPCItemDB request failed (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Unexpected product response format from UPCItemDB');
    }

    final total = _asInt(decoded['total']);
    if (total <= 0) return null;

    final items = decoded['items'] is List ? decoded['items'] as List : const <dynamic>[];
    if (items.isEmpty) return null;

    final item = items.firstWhere((_) => true, orElse: () => null);
    if (item == null || item is! Map<String, dynamic>) return null;

    final mapped = <String, dynamic>{
      'product_name': _asString(item['title']),
      'brands': _asString(item['brand']),
      'quantity': _asString(item['size'] ?? item['description'] ?? ''),
      'images': item['images'] is List ? List<String>.from(item['images'].whereType<String>()) : null,
      'quantity_value': null,
      'quantity_unit': null,
    };

    if (_hasMeaningfulProductName(mapped)) {
      return {'status': 1, 'product': mapped};
    }

    return null;
  }

  static Future<Map<String, dynamic>?> _lookupGtinSearch(String barcode) async {
    final uri = Uri.parse('$kGtinSearchItemUrl$barcode');
    final response = await http.get(uri);

    if (response.statusCode != 200 && response.statusCode != 404) {
      throw StateError('GTINSearch request failed (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FormatException('Unexpected product response format from GTINSearch');
    }

    if (decoded.isEmpty) return null;

    final item = decoded.firstWhere((_) => true, orElse: () => null);
    if (item == null || item is! Map<String, dynamic>) return null;

    final mapped = <String, dynamic>{
      'product_name': _composeName(brandName: _asString(item['brand_name']), name: _asString(item['name'])),
      'brands': _asString(item['brand_name']),
      'quantity': _asString(item['size']),
      'images': null,
      'quantity_value': null,
      'quantity_unit': null,
    };

    if (_hasMeaningfulProductName(mapped)) {
      return {'status': 1, 'product': mapped};
    }

    return null;
  }

  static bool _hasMeaningfulProductName(Map<String, dynamic> product) {
    final name = _asString(product['product_name'], fallback: _asString(product['product_name_en']));
    final cleaned = name.toLowerCase().trim();
    if (cleaned.isEmpty) return false;
    final bads = ['unknown', 'unknown product', 'product', 'n/a', 'na', '-'];
    if (bads.contains(cleaned)) return false;
    if (cleaned.length <= 2) return false;
    return true;
  }

  static String _asString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) {
      final parsed = num.tryParse(value);
      if (parsed != null) return parsed.round();
    }
    return fallback;
  }

  static String _composeName({required String brandName, required String name}) {
    final brand = brandName.trim();
    final productName = name.trim();

    if (brand.isEmpty) return productName;
    if (productName.isEmpty) return brand;
    return '$brand $productName';
  }
}
