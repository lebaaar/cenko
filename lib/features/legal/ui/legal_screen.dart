import 'dart:convert';

import 'package:cenko/core/constants/constants.dart';
import 'package:cenko/core/utils/date_util.dart';
import 'package:cenko/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

class LegalScreen extends StatefulWidget {
  const LegalScreen({super.key});

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  late Future<Map<String, dynamic>> _future;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final locale = Localizations.localeOf(context);
      final url = locale.languageCode == 'sl' ? kLegalContentSlUrl : kLegalContentEnUrl;
      _future = _fetchLegal(url);
    }
  }

  Future<Map<String, dynamic>> _fetchLegal(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.profileLegal)),
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data!;
            final title = data['title'] as String? ?? '';
            final lastUpdated = data['lastUpdated'] as String?;
            final contactEmail = data['contactEmail'] as String? ?? kContactEmail;
            final sections = (data['sections'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

            final lastUpdatedDate = lastUpdated != null ? DateTime.tryParse(lastUpdated) : null;

            return _LegalContent(title: title, lastUpdatedDate: lastUpdatedDate, contactEmail: contactEmail, sections: sections);
          },
        ),
      ),
    );
  }
}

class _LegalContent extends StatelessWidget {
  const _LegalContent({required this.title, required this.lastUpdatedDate, required this.contactEmail, required this.sections});

  final String title;
  final DateTime? lastUpdatedDate;
  final String contactEmail;
  final List<Map<String, dynamic>> sections;

  static IconData _iconFor(String id) => switch (id) {
    'use' => Icons.check_circle_outline_rounded,
    'data' => Icons.data_usage_rounded,
    'rights' => Icons.tune_rounded,
    'use-of-data' => Icons.manage_search_rounded,
    'legal-basis' => Icons.balance_rounded,
    'data-retention' => Icons.history_rounded,
    'sharing' => Icons.share_outlined,
    'children' => Icons.child_care_rounded,
    'third-party' => Icons.link_rounded,
    'liability' => Icons.gpp_maybe_rounded,
    'breach' => Icons.warning_amber_rounded,
    'governing-law' => Icons.account_balance_rounded,
    'updates' => Icons.update_rounded,
    _ => Icons.info_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colorScheme.primaryContainer, colorScheme.secondaryContainer],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: colorScheme.surface.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(16)),
                child: Icon(Icons.gavel_rounded, color: colorScheme.onSurface, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                    if (lastUpdatedDate != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        l10n.legalLastUpdated(displayWordedDate(lastUpdatedDate!, lang: Localizations.localeOf(context).languageCode)),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final section in sections)
          _SectionCard(
            title: section['title'] as String? ?? '',
            icon: _iconFor(section['id'] as String? ?? ''),
            bullets: (section['bullets'] as List<dynamic>? ?? []).cast<String>(),
          ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(18)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.legalQuestions, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(l10n.legalQuestionsBody, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: 6),
              Text(contactEmail, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.push('/contact'),
                  style: FilledButton.styleFrom(foregroundColor: Colors.white),
                  label: Text(l10n.legalContactUs),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.icon, required this.bullets});

  final String title;
  final IconData icon;
  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(18)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colorScheme.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final bullet in bullets) _BulletPoint(bullet),
          ],
        ),
      ),
    );
  }
}

class _BulletPoint extends StatelessWidget {
  const _BulletPoint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
