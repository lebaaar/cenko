import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:cenko/core/utils/price_util.dart';
import 'package:cenko/features/deals/data/catalog_deal_item.dart';
import 'package:cenko/features/shopping_list/data/shopping_list_repository.dart';
import 'package:cenko/shared/repository/catalog_deals_repository.dart';
import 'package:cenko/shared/services/deal_text_matcher_service.dart';

const _processingHints = <String>["Scanning", "Processing", "Validating", "Finalizing"];

const _commonBoughtProductWindowDays = 90;
const _commonBoughtProductInactivityDays = 45;
const _commonBoughtProductMinPurchases = 4;

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, this.initialMode, this.returnTo});

  final String? initialMode;
  final String? returnTo;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController(autoStart: false);
  final ImagePicker _imagePicker = ImagePicker();
  final ShoppingListRepository _shoppingListRepository = ShoppingListRepository();
  final CatalogDealsRepository _catalogDealsRepository = CatalogDealsRepository();
  final DealTextMatcherService _dealTextMatcherService = const DealTextMatcherService();
  ScaffoldMessengerState? _scaffoldMessenger;

  CameraController? _receiptCamera;
  List<CameraDescription> _cameras = <CameraDescription>[];
  int _receiptCameraIndex = 0;
  bool _receiptCameraInitializing = false;
  bool _receiptTorchOn = false;

  late final GenerativeModel _receiptModel = FirebaseAI.googleAI().generativeModel(
    model: 'gemini-2.5-flash-lite',
    generationConfig: GenerationConfig(
      temperature: 0,
      maxOutputTokens: 4096,
      responseMimeType: 'application/json',
      responseSchema: Schema.object(
        properties: {
          'receipt': Schema.object(
            properties: {
              'receipt_id': Schema.string(),
              'store_name': Schema.string(),
              'total_price': Schema.integer(description: 'Total in cents.'),
              'item_count': Schema.integer(),
              'raw_ocr': Schema.string(description: 'Full OCR text extracted from receipt image.'),
              'date': Schema.string(description: 'ISO-8601 timestamp string.'),
            },
            propertyOrdering: const ['receipt_id', 'store_name', 'total_price', 'item_count', 'raw_ocr', 'date'],
          ),
          'items': Schema.array(
            items: Schema.object(
              properties: {
                'item_id': Schema.string(),
                'raw_name': Schema.string(),
                'unit_price': Schema.integer(description: 'Price per unit in cents.'),
                'quantity': Schema.number(description: 'Quantity purchased.'),
                'total_price': Schema.integer(description: 'Line total in cents.'),
              },
              propertyOrdering: const ['item_id', 'raw_name', 'unit_price', 'quantity', 'total_price'],
            ),
          ),
        },
        propertyOrdering: const ['receipt', 'items'],
      ),
    ),
  );

  late _ScanMode _mode;
  bool _isHandlingDetection = false;
  bool _isProcessingReceipt = false;
  bool _isCapturingReceipt = false;
  bool _isSwitchingScannerMode = false;
  bool _isShowingManualAddSheet = false;
  bool _receiptPreviewLocked = false;
  Uint8List? _frozenReceiptImageBytes;
  _ReceiptFlowState _receiptFlowState = _ReceiptFlowState.idle;
  Map<String, dynamic>? _pendingReceiptPayload;
  final Random _random = Random();
  String _processingHint = _processingHints.first;
  Timer? _processingHintTimer;
  String? _receiptFlowMessage;
  _BarcodeFlowState _barcodeFlowState = _BarcodeFlowState.idle;
  String? _barcodeFlowMessage;
  Map<String, dynamic>? _barcodeProduct;
  String? _barcodeValue;
  DateTime? _barcodeDetectionCooldownUntil;
  late final AnimationController _scanBarController;
  int _processingHintDots = 1;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode == 'barcode' ? _ScanMode.barcode : _ScanMode.receipt;
    _scanBarController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
    _setScanBarAnimationActive(_mode == _ScanMode.barcode);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeMode();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
  }

  @override
  void dispose() {
    _processingHintTimer?.cancel();
    _scanBarController.dispose();
    _controller.dispose();
    _receiptCamera?.dispose();
    _scaffoldMessenger = null;
    super.dispose();
  }

  void _showSnackBar(SnackBar snackBar) {
    _scaffoldMessenger?.showSnackBar(snackBar);
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
      },
      child: Actions(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _onEnterPressed();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: Stack(
              children: [
                _buildPreview(),
                if (_mode == _ScanMode.barcode && _barcodeFlowState == _BarcodeFlowState.idle)
                  Positioned.fill(child: IgnorePointer(child: _buildViewfinder(context))),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Column(children: [_buildModeHeader(context)]),
                  ),
                ),
                Positioned(left: 0, right: 0, bottom: 18, child: SafeArea(top: false, child: _buildBottomControls(context))),
                if (_mode == _ScanMode.receipt)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 108,
                    child: SafeArea(
                      top: false,
                      child: Center(
                        child: GestureDetector(
                          onTap: _isProcessingReceipt || _isCapturingReceipt || _receiptFlowState != _ReceiptFlowState.idle
                              ? null
                              : _captureReceiptFromCamera,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 78,
                            height: 78,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.12),
                              border: Border.all(color: Colors.white, width: 4),
                            ),
                            child: Center(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0, 4))],
                                ),
                                child: _isProcessingReceipt || _isCapturingReceipt
                                    ? const Padding(padding: EdgeInsets.all(15), child: CircularProgressIndicator(strokeWidth: 2))
                                    : const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_mode == _ScanMode.receipt && _receiptFlowState != _ReceiptFlowState.idle) _buildReceiptFlowOverlay(context),
                if (_mode == _ScanMode.barcode && _barcodeFlowState != _BarcodeFlowState.idle) _buildBarcodeFlowOverlay(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptFlowOverlay(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned.fill(
      child: AbsorbPointer(
        absorbing: _receiptFlowState == _ReceiptFlowState.processing,
        child: Container(
          color: Colors.black.withValues(alpha: 0.72),
          padding: const EdgeInsets.fromLTRB(20, 96, 20, 40),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_receiptFlowState == _ReceiptFlowState.readyToSubmit) ...[
                  Text(
                    'Receipt extracted',
                    style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _readySummaryText(),
                    style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white.withValues(alpha: 0.92), height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Press Enter to store this receipt.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.76)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saveExtractedReceipt,
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Store receipt'),
                      style: _primaryActionStyle(context),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(onPressed: _resetReceiptFlow, style: _secondaryActionStyle(context), child: const Text('Scan again')),
                  ),
                ],
                if (_receiptFlowState == _ReceiptFlowState.processing) ...[
                  const SizedBox(width: 72, height: 72, child: CircularProgressIndicator(strokeWidth: 3)),
                  const SizedBox(height: 20),
                  Text(
                    _processingHintWithDots(),
                    style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (_receiptFlowState == _ReceiptFlowState.failure) ...[
                  Text(
                    ':(',
                    style: theme.textTheme.displayLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Could not save receipt',
                    style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _receiptFlowMessage ?? 'Please try again.',
                    style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white.withValues(alpha: 0.92), height: 1.35),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _resetReceiptFlow,
                      icon: const Icon(Icons.document_scanner_rounded),
                      label: const Text('Scan again'),
                      style: _primaryActionStyle(context),
                    ),
                  ),
                ],
                if (_receiptFlowState == _ReceiptFlowState.success) ...[
                  const Icon(Icons.check_circle_rounded, size: 64, color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    'Receipt saved',
                    style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Your spending data has been updated.',
                    style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white.withValues(alpha: 0.92), height: 1.35),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _resetReceiptFlow,
                      icon: const Icon(Icons.document_scanner_rounded),
                      label: const Text('Scan another'),
                      style: _primaryActionStyle(context),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => context.go('/profile'),
                      style: _secondaryActionStyle(context),
                      child: const Text('See spendings breakdown'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBarcodeFlowOverlay(BuildContext context) {
    final theme = Theme.of(context);
    final product = _barcodeProduct;
    final productName = product == null ? null : _formatBarcodeProductName(product);
    final productLabel = product == null ? null : _formatBarcodeSuccessLabel(product);

    return Positioned.fill(
      child: AbsorbPointer(
        absorbing: _barcodeFlowState == _BarcodeFlowState.processing,
        child: Container(
          color: Colors.black.withValues(alpha: 0.72),
          padding: const EdgeInsets.fromLTRB(20, 96, 20, 40),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_barcodeFlowState == _BarcodeFlowState.processing) ...[
                  const SizedBox(width: 72, height: 72, child: CircularProgressIndicator(strokeWidth: 3)),
                ],
                if (_barcodeFlowState == _BarcodeFlowState.failure) ...[
                  Text(
                    ':(',
                    style: theme.textTheme.displayLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Could not load product',
                    style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _barcodeFlowMessage ?? 'Could not get product details. Please try again.',
                    style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white.withValues(alpha: 0.92), height: 1.35),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _showBarcodeManualAddSheet,
                      icon: const Icon(Icons.edit_note_rounded),
                      label: const Text('Add manually'),
                      style: _primaryActionStyle(context),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(onPressed: _resumeBarcodeScanning, style: _secondaryActionStyle(context), child: const Text('Try again')),
                  ),
                ],
                if (_barcodeFlowState == _BarcodeFlowState.success) ...[
                  const Icon(Icons.inventory_2_rounded, size: 64, color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    productName ?? 'Product found',
                    style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    productLabel ?? 'Ready to add to shopping list.',
                    style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white.withValues(alpha: 0.92), height: 1.35),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _addBarcodeProductToShoppingList,
                      icon: const Icon(Icons.playlist_add_rounded),
                      label: const Text('Add to shopping list'),
                      style: _primaryActionStyle(context),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _resumeBarcodeScanning,
                      style: _secondaryActionStyle(context),
                      child: const Text('Scan another'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeHeader(BuildContext context) {
    final isBarcode = _mode == _ScanMode.barcode;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.black.withValues(alpha: 0.58), Colors.black.withValues(alpha: 0.32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ModeTab(label: 'Barcode', selected: isBarcode, onTap: () => _onModeSelected(_ScanMode.barcode)),
                      _ModeTab(label: 'Receipt', selected: !isBarcode, onTap: () => _onModeSelected(_ScanMode.receipt)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: SizedBox(
                    key: ValueKey(_mode),
                    width: MediaQuery.sizeOf(context).width * 0.8,
                    child: Text(
                      _modeInstruction(),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: _ControlButton(icon: Icons.arrow_back_rounded, onTap: _closeScanner),
          ),
        ],
      ),
    );
  }

  Widget _buildViewfinder(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final availableFromWidth = media.width - 56;
    final availableFromHeight = media.height * 0.42;
    final side = availableFromWidth < availableFromHeight ? availableFromWidth : availableFromHeight;
    final viewfinderSize = side.clamp(220.0, 320.0).toDouble();
    final cornerRadius = (viewfinderSize * 0.12).clamp(24.0, 36.0).toDouble();
    final scanInset = (viewfinderSize * 0.08).clamp(18.0, 24.0).toDouble();
    final scanTravel = viewfinderSize - (scanInset * 2);

    return Center(
      child: Container(
        width: viewfinderSize,
        height: viewfinderSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(cornerRadius),
          border: Border.all(color: Colors.white.withValues(alpha: 0.88), width: 1.8),
          color: Colors.white.withValues(alpha: 0.03),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 24, offset: const Offset(0, 10))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(cornerRadius),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black.withValues(alpha: 0.16), Colors.transparent, Colors.black.withValues(alpha: 0.2)],
                      stops: const [0.0, 0.52, 1.0],
                    ),
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _scanBarController,
                builder: (context, _) {
                  final top = scanInset + (_scanBarController.value * scanTravel);
                  return Positioned(
                    left: scanInset,
                    right: scanInset,
                    top: top,
                    child: IgnorePointer(
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.white.withValues(alpha: 0.98),
                              Colors.white.withValues(alpha: 0.72),
                              Colors.transparent,
                            ],
                          ),
                          boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.34), blurRadius: 14, spreadRadius: 1)],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black.withValues(alpha: 0.56), Colors.black.withValues(alpha: 0.34)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 18, offset: const Offset(0, 8))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFlashButton(),
            const SizedBox(width: 12),
            _ControlButton(icon: Icons.photo_library_rounded, onTap: _pickFromGallery),
            const SizedBox(width: 12),
            _ControlButton(icon: Icons.cameraswitch_rounded, onTap: _switchActiveCamera),
          ],
        ),
      ),
    );
  }

  String _modeInstruction() {
    return _mode == _ScanMode.barcode ? 'Scan a barcode to add item to your shopping list.' : 'Scan a receipt to track your spendings.';
  }

  String _readySummaryText() {
    final receipt = _pendingReceiptPayload?['receipt'];
    if (receipt is! Map<String, dynamic>) {
      return 'Review and store this receipt.';
    }
    final storeName = _asString(receipt['store_name'], fallback: 'Unknown store');
    final total = _asInt(receipt['total_price']);
    final itemCount = _asInt(receipt['item_count']);
    return '$storeName\n${_formatCents(total)} • $itemCount items';
  }

  String _formatCents(int cents) {
    final amount = cents / 100;
    return '\$${amount.toStringAsFixed(2)}';
  }

  Widget _buildPreview() {
    if (_mode == _ScanMode.receipt) {
      if (_receiptPreviewLocked) {
        final frozenBytes = _frozenReceiptImageBytes;
        if (frozenBytes == null) {
          return const ColoredBox(color: Colors.black);
        }

        return SizedBox.expand(
          child: Image.memory(
            frozenBytes,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const ColoredBox(color: Colors.black),
          ),
        );
      }

      if (_receiptCameraInitializing) {
        return const Center(child: CircularProgressIndicator());
      }

      final camera = _receiptCamera;
      if (camera == null || !camera.value.isInitialized) {
        return const Center(
          child: Padding(padding: EdgeInsets.all(24), child: Text('Camera is not ready.')),
        );
      }
      final previewSize = camera.value.previewSize;
      if (previewSize == null) {
        return CameraPreview(camera);
      }

      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(width: previewSize.height, height: previewSize.width, child: CameraPreview(camera)),
        ),
      );
    }

    return ValueListenableBuilder<MobileScannerState>(
      valueListenable: _controller,
      builder: (context, state, _) {
        final isFrontCamera = state.cameraDirection == CameraFacing.front;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()..scaleByDouble(isFrontCamera ? -1.0 : 1.0, 1.0, 1.0, 1.0),
          child: MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Camera unavailable: ${error.errorCode.name}', textAlign: TextAlign.center),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildFlashButton() {
    if (_mode == _ScanMode.receipt) {
      return _ControlButton(icon: _receiptTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded, onTap: _toggleReceiptTorch);
    }

    return ValueListenableBuilder<MobileScannerState>(
      valueListenable: _controller,
      builder: (context, state, _) {
        final isOn = state.torchState == TorchState.on;
        return _ControlButton(icon: isOn ? Icons.flash_on_rounded : Icons.flash_off_rounded, onTap: _controller.toggleTorch);
      },
    );
  }

  Future<void> _initializeMode() async {
    if (_mode == _ScanMode.receipt) {
      await _controller.stop();
      await _initializeReceiptCamera();
      return;
    }

    _resetBarcodeFlow();
    await _startBarcodeScanner(force: true);
  }

  Future<void> _onModeSelected(_ScanMode mode) async {
    if (_mode == mode || _isSwitchingScannerMode) {
      return;
    }

    _isSwitchingScannerMode = true;
    setState(() {
      _mode = mode;
    });
    _setScanBarAnimationActive(mode == _ScanMode.barcode);
    _resetBarcodeFlow();
    _resetReceiptFlow();

    if (mode == _ScanMode.receipt) {
      await _controller.stop();
      await _initializeReceiptCamera();
      _isSwitchingScannerMode = false;
      return;
    }

    await _receiptCamera?.dispose();
    _receiptCamera = null;
    _receiptTorchOn = false;
    _isSwitchingScannerMode = false;
    await _startBarcodeScanner(force: true);
  }

  Future<void> _startBarcodeScanner({bool force = false}) async {
    if (_isSwitchingScannerMode && !force) {
      return;
    }

    if (_controller.value.isStarting || _controller.value.isRunning) {
      return;
    }

    await _controller.start();
  }

  void _setScanBarAnimationActive(bool active) {
    if (active) {
      if (!_scanBarController.isAnimating) {
        _scanBarController.repeat(reverse: true);
      }
      return;
    }

    if (_scanBarController.isAnimating) {
      _scanBarController.stop();
    }
    _scanBarController.value = 0;
  }

  Future<void> _initializeReceiptCamera({int? cameraIndex}) async {
    if (_receiptCameraInitializing) {
      return;
    }

    setState(() {
      _receiptCameraInitializing = true;
    });
    _resetReceiptFlow();

    try {
      if (_cameras.isEmpty) {
        _cameras = await availableCameras();
      }

      if (_cameras.isEmpty) {
        throw StateError('No camera available on this device.');
      }

      final targetIndex = cameraIndex ?? _findBackCameraIndex(_cameras);
      _receiptCameraIndex = targetIndex;

      await _receiptCamera?.dispose();

      final camera = CameraController(_cameras[targetIndex], ResolutionPreset.high, enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg);

      await camera.initialize();
      await camera.setFlashMode(FlashMode.off);

      if (!mounted) {
        await camera.dispose();
        return;
      }

      setState(() {
        _receiptCamera = camera;
        _receiptTorchOn = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _receiptFlowMessage = 'Camera init failed: $e';
          _receiptFlowState = _ReceiptFlowState.failure;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _receiptCameraInitializing = false;
        });
      }
    }
  }

  int _findBackCameraIndex(List<CameraDescription> cameras) {
    final backIndex = cameras.indexWhere((camera) => camera.lensDirection == CameraLensDirection.back);
    return backIndex == -1 ? 0 : backIndex;
  }

  Future<void> _toggleReceiptTorch() async {
    final camera = _receiptCamera;
    if (camera == null || !camera.value.isInitialized) {
      return;
    }

    final nextIsOn = !_receiptTorchOn;
    await camera.setFlashMode(nextIsOn ? FlashMode.torch : FlashMode.off);

    if (mounted) {
      setState(() {
        _receiptTorchOn = nextIsOn;
      });
    }
  }

  Future<void> _switchActiveCamera() async {
    if (_mode == _ScanMode.barcode) {
      await _controller.switchCamera();
      return;
    }

    if (_cameras.length < 2) {
      return;
    }

    final nextIndex = (_receiptCameraIndex + 1) % _cameras.length;
    await _initializeReceiptCamera(cameraIndex: nextIndex);
  }

  void _resetBarcodeFlow() {
    _stopProcessingHints();
    if (!mounted) {
      return;
    }
    setState(() {
      _barcodeFlowState = _BarcodeFlowState.idle;
      _barcodeFlowMessage = null;
      _barcodeProduct = null;
      _barcodeValue = null;
      _isHandlingDetection = false;
    });
  }

  void _resumeBarcodeScanning() {
    _barcodeDetectionCooldownUntil = DateTime.now().add(const Duration(seconds: 2));
    _resetBarcodeFlow();
    unawaited(_startBarcodeScanner(force: true));
  }

  Future<void> _addBarcodeProductToShoppingList() async {
    final product = _barcodeProduct;
    if (product == null) {
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _barcodeFlowState = _BarcodeFlowState.failure;
        _barcodeFlowMessage = 'You must be logged in to add items to your shopping list.';
      });
      return;
    }

    final name = _formatBarcodeProductName(product);
    final brand = _asString(product['brands'], fallback: '').trim();
    final barcode = _barcodeValue ?? _asString(product['code']);

    // Resume live scanning immediately after user confirms add.
    _resetBarcodeFlow();
    _barcodeDetectionCooldownUntil = DateTime.now().add(const Duration(seconds: 2));
    unawaited(_startBarcodeScanner(force: true));

    try {
      await _shoppingListRepository.addItem(uid: uid, name: name, brand: brand.isEmpty ? null : brand, barcode: barcode.isEmpty ? null : barcode);
      if (!mounted) {
        return;
      }

      await _showProductInsightsSheet(productNames: {name});
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showSnackBar(const SnackBar(content: Text('Could not add product to shopping list. Please try again.')));
    }
  }

  Future<void> _showBarcodeManualAddSheet() async {
    if (_isShowingManualAddSheet) {
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _barcodeFlowState = _BarcodeFlowState.failure;
        _barcodeFlowMessage = 'You must be logged in to add items to your shopping list.';
      });
      return;
    }

    _isShowingManualAddSheet = true;

    var itemName = '';
    String? formError;
    var saving = false;
    var itemSaved = false;
    String? savedItemName;

    try {
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (context, setSheetState) {
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Add item manually', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text('Enter the item name and save it to your shopping list.', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 16),
                    if (formError != null) ...[
                      Text(formError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      onChanged: (value) {
                        itemName = value;
                      },
                      onSubmitted: (_) {
                        if (saving) {
                          return;
                        }
                        FocusManager.instance.primaryFocus?.unfocus();
                      },
                      decoration: const InputDecoration(labelText: 'Item name'),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: saving
                            ? null
                            : () async {
                                final name = itemName.trim();
                                if (name.isEmpty) {
                                  setSheetState(() {
                                    formError = 'Item name is required';
                                  });
                                  return;
                                }

                                setSheetState(() {
                                  saving = true;
                                  formError = null;
                                });

                                try {
                                  await _shoppingListRepository.addItem(uid: uid, name: name);
                                  itemSaved = true;
                                  savedItemName = name;
                                  if (sheetContext.mounted) {
                                    FocusManager.instance.primaryFocus?.unfocus();
                                    Navigator.of(sheetContext).pop();
                                  }
                                } catch (error) {
                                  if (!sheetContext.mounted) {
                                    return;
                                  }
                                  setSheetState(() {
                                    formError = 'Could not save item. Please try again.';
                                    saving = false;
                                  });
                                }
                              },
                        style: _primaryActionStyle(context),
                        child: Text(saving ? 'Saving...' : 'Add item'),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } finally {
      _isShowingManualAddSheet = false;
    }

    if (!mounted || !itemSaved) {
      return;
    }

    _resetBarcodeFlow();
    unawaited(_startBarcodeScanner(force: true));
    if (savedItemName != null && savedItemName!.trim().isNotEmpty) {
      await _showProductInsightsSheet(productNames: {savedItemName!.trim()});
    }
  }

  ButtonStyle _primaryActionStyle(BuildContext context) {
    return FilledButton.styleFrom(
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    );
  }

  ButtonStyle _secondaryActionStyle(BuildContext context) {
    return OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      side: BorderSide(color: Colors.white.withValues(alpha: 0.45)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    );
  }

  String _formatBarcodeProductName(Map<String, dynamic> product) {
    final name = _asString(product['product_name'], fallback: _asString(product['product_name_en'], fallback: 'Unknown product'));
    final amount = _barcodeAmountLabel(product);
    return '$name${amount.isEmpty ? '' : ' ($amount)'}';
  }

  String _formatBarcodeSuccessLabel(Map<String, dynamic> product) {
    return _formatBarcodeProductName(product);
  }

  String _barcodeAmountLabel(Map<String, dynamic> product) {
    final quantity = _asString(product['quantity']).trim();
    if (quantity.isNotEmpty) {
      final parsed = _normalizeAmountLabel(quantity);
      if (parsed.isNotEmpty) {
        return parsed;
      }
    }

    final quantityValue = _asString(product['quantity_value']).trim();
    final quantityUnit = _asString(product['quantity_unit']).trim();
    if (quantityValue.isNotEmpty && quantityUnit.isNotEmpty) {
      return _normalizeAmountLabel('$quantityValue $quantityUnit');
    }

    return '';
  }

  String _normalizeAmountLabel(String raw) {
    final normalized = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    final match = RegExp(r'^([0-9]+(?:[\.,][0-9]+)?)\s*(kg|g|mg|l|ml|cl|dl)$', caseSensitive: false).firstMatch(normalized);
    if (match == null) {
      return normalized;
    }

    final value = double.tryParse(match.group(1)!.replaceAll(',', '.'));
    final unit = match.group(2)!.toLowerCase();
    if (value == null) {
      return normalized;
    }

    switch (unit) {
      case 'kg':
        return '${(value * 1000).round()} g';
      case 'g':
        return '${value % 1 == 0 ? value.round() : value} g';
      case 'mg':
        return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)} g';
      case 'l':
        return '${(value * 1000).round()} ml';
      case 'cl':
        return '${(value * 10).round()} ml';
      case 'dl':
        return '${(value * 100).round()} ml';
      case 'ml':
        return '${value % 1 == 0 ? value.round() : value} ml';
      default:
        return normalized;
    }
  }

  void _onDetect(BarcodeCapture capture) {
    final cooldownUntil = _barcodeDetectionCooldownUntil;
    if (_mode == _ScanMode.barcode && cooldownUntil != null && DateTime.now().isBefore(cooldownUntil)) {
      return;
    }

    if (_isHandlingDetection) {
      return;
    }

    if (_mode == _ScanMode.barcode && _barcodeFlowState != _BarcodeFlowState.idle) {
      return;
    }

    _isHandlingDetection = true;

    if (_mode == _ScanMode.barcode) {
      _handleBarcodeDetection(capture);
    } else {
      _showSnackBar(const SnackBar(content: Text('Receipt captured. Cloud parsing is next.')));
      Future<void>.delayed(const Duration(milliseconds: 1200), () {
        if (!mounted) {
          return;
        }
        setState(() {
          _isHandlingDetection = false;
        });
      });
    }
  }

  Future<void> _handleBarcodeDetection(BarcodeCapture capture) async {
    try {
      final detectedCode = _firstBarcodeValue(capture);
      if (detectedCode == null) {
        return;
      }

      setState(() {
        _barcodeValue = detectedCode;
        _barcodeFlowMessage = null;
        _barcodeProduct = null;
        _barcodeFlowState = _BarcodeFlowState.processing;
      });
      HapticFeedback.lightImpact();
      final lookup = await _lookupBarcodeProduct(detectedCode);
      if (!mounted) {
        return;
      }

      final isFound = lookup['status'] == 1;
      final product = lookup['product'] is Map<String, dynamic> ? lookup['product'] as Map<String, dynamic> : <String, dynamic>{};

      if (!isFound || product.isEmpty) {
        setState(() {
          _barcodeProduct = null;
          _barcodeFlowState = _BarcodeFlowState.failure;
          _barcodeFlowMessage = 'No product was found for this barcode.';
        });
        return;
      }

      setState(() {
        _barcodeProduct = product;
        _barcodeFlowState = _BarcodeFlowState.success;
        _barcodeFlowMessage = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _barcodeProduct = null;
          _barcodeFlowState = _BarcodeFlowState.failure;
          _barcodeFlowMessage = 'Could not get product details. Please try again or add the item manually.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isHandlingDetection = false;
        });
      }
    }
  }

  String? _firstBarcodeValue(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final value = barcode.displayValue ?? barcode.rawValue;
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> _lookupBarcodeProduct(String barcode) async {
    final uri = Uri.parse('https://world.openfoodfacts.net/api/v2/product/$barcode.json');
    final response = await http.get(uri);

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Unexpected product response format.');
    }

    if (response.statusCode != 200 && response.statusCode != 404) {
      throw StateError('Open Food Facts request failed (${response.statusCode}).');
    }

    return decoded;
  }

  Future<void> _pickFromGallery() async {
    if (_receiptFlowState == _ReceiptFlowState.processing) {
      return;
    }

    final file = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (file == null) {
      return;
    }

    if (_mode == _ScanMode.receipt) {
      await _extractReceiptJson(file);
      return;
    }

    final capture = await _controller.analyzeImage(file.path);
    if (!mounted) {
      return;
    }

    if (capture == null || capture.barcodes.isEmpty) {
      _showSnackBar(const SnackBar(content: Text('No barcode detected in selected image.')));
      return;
    }

    await _handleBarcodeDetection(capture);
  }

  Future<void> _captureReceiptFromCamera() async {
    final camera = _receiptCamera;
    if (camera == null || !camera.value.isInitialized) {
      setState(() {
        _receiptFlowMessage = 'Camera not ready for capture.';
        _receiptFlowState = _ReceiptFlowState.failure;
      });
      return;
    }

    setState(() {
      _isCapturingReceipt = true;
      _receiptPreviewLocked = true;
      _frozenReceiptImageBytes = null;
    });

    try {
      final file = await camera.takePicture();
      final bytes = await file.readAsBytes();
      if (mounted) {
        setState(() {
          _frozenReceiptImageBytes = bytes;
        });
      }
      await _extractReceiptJson(file, autoStore: true, imageBytes: bytes);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _receiptFlowMessage = 'Could not capture receipt image. Please try again.';
        _receiptFlowState = _ReceiptFlowState.failure;
      });
    } finally {
      if (mounted) {
        setState(() => _isCapturingReceipt = false);
      }
    }
  }

  Future<void> _extractReceiptJson(XFile file, {bool autoStore = false, Uint8List? imageBytes}) async {
    setState(() {
      _isProcessingReceipt = true;
      _receiptFlowMessage = null;
      _receiptFlowState = _ReceiptFlowState.processing;
      _pendingReceiptPayload = null;
    });
    _startProcessingHints();

    try {
      final bytes = imageBytes ?? await file.readAsBytes();
      final mimeType = _mimeTypeForPath(file.path);

      final response = await _receiptModel.generateContent(_buildReceiptExtractionPrompt(imageBytes: bytes, mimeType: mimeType));

      final rawText = response.text?.trim();
      if (rawText == null || rawText.isEmpty) {
        throw StateError('Gemini returned no JSON text.');
      }

      final decoded = await _decodeReceiptPayload(rawText: rawText, imageBytes: bytes, mimeType: mimeType);

      final dbReadyPayload = _normalizeDbPayload(decoded, rawText);
      if (!_isReceiptDetected(dbReadyPayload)) {
        throw const _UserVisibleError('No receipt detected. Make sure a full receipt is visible and try again.');
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _pendingReceiptPayload = dbReadyPayload;
      });

      if (autoStore) {
        await _persistReceiptPayload(dbReadyPayload);
        if (!mounted) {
          return;
        }
        setState(() {
          _receiptFlowState = _ReceiptFlowState.success;
        });
      } else {
        setState(() {
          _receiptFlowState = _ReceiptFlowState.readyToSubmit;
        });
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _receiptFlowMessage = e.toString();
        _receiptFlowState = _ReceiptFlowState.failure;
      });
    } finally {
      _stopProcessingHints();
      if (mounted) {
        setState(() => _isProcessingReceipt = false);
      }
    }
  }

  /// Builds the prompt for cloud OCR + structured receipt extraction.
  List<Content> _buildReceiptExtractionPrompt({required Uint8List imageBytes, required String mimeType}) {
    return [
      Content.text(
        'Extract receipt data from the provided receipt image and return JSON only in this exact DB-ready structure: '
        '{"receipt": {...}, "items": [...]} where fields are: '
        'receipt.receipt_id (string placeholder like "__AUTO_ID__"), '
        'receipt.store_name (string), '
        'receipt.total_price (integer cents), '
        'receipt.item_count (integer), '
        'receipt.raw_ocr (string full OCR text extracted from the image), '
        'receipt.date (ISO-8601 timestamp string), '
        'items[].item_id (string placeholder like "__AUTO_ID__"), '
        'items[].raw_name (string), '
        'items[].unit_price (integer cents), '
        'items[].quantity (number), '
        'items[].total_price (integer cents). '
        'All prices must be cents as integers.',
      ),
      Content.inlineData(mimeType, imageBytes),
    ];
  }

  Future<Map<String, dynamic>> _decodeReceiptPayload({required String rawText, required Uint8List imageBytes, required String mimeType}) async {
    final direct = _tryParseJsonObject(rawText);
    if (direct != null) {
      return direct;
    }

    final repairedResponse = await _receiptModel.generateContent([
      Content.text(
        'You previously returned malformed or truncated JSON for a receipt extraction task. '
        'Return ONLY one valid JSON object and no markdown, no prose. '
        'Required shape: '
        '{"receipt":{"receipt_id":string,"store_name":string,"total_price":int,"item_count":int,"raw_ocr":string,"date":string},'
        '"items":[{"item_id":string,"raw_name":string,"unit_price":int,"quantity":number,"total_price":int}]}. '
        'All prices must be integer cents. ISO-8601 date. '
        'Use the provided image and repair your output. '
        'Previous malformed output:\n$rawText',
      ),
      Content.inlineData(mimeType, imageBytes),
    ]);

    final repairedText = repairedResponse.text?.trim();
    if (repairedText == null || repairedText.isEmpty) {
      throw const FormatException('AI returned empty text when repairing receipt JSON.');
    }

    final repaired = _tryParseJsonObject(repairedText);
    if (repaired != null) {
      return repaired;
    }

    throw const FormatException('Unexpected end of input in AI JSON response.');
  }

  Map<String, dynamic>? _tryParseJsonObject(String input) {
    Map<String, dynamic>? decode(String candidate) {
      try {
        final decoded = jsonDecode(candidate);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      } catch (_) {}
      return null;
    }

    final direct = decode(input);
    if (direct != null) {
      return direct;
    }

    final withoutFence = _stripMarkdownCodeFence(input);
    final fencedDecoded = decode(withoutFence);
    if (fencedDecoded != null) {
      return fencedDecoded;
    }

    final objectSlice = _extractFirstJsonObject(withoutFence);
    if (objectSlice.isNotEmpty) {
      final sliceDecoded = decode(objectSlice);
      if (sliceDecoded != null) {
        return sliceDecoded;
      }

      final balancedSlice = _balanceObjectBraces(objectSlice);
      final balancedDecoded = decode(balancedSlice);
      if (balancedDecoded != null) {
        return balancedDecoded;
      }
    }

    return null;
  }

  String _stripMarkdownCodeFence(String text) {
    var cleaned = text.trim();
    if (cleaned.startsWith('```')) {
      final firstNewline = cleaned.indexOf('\n');
      if (firstNewline != -1) {
        cleaned = cleaned.substring(firstNewline + 1);
      }
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }
    }
    return cleaned.trim();
  }

  String _extractFirstJsonObject(String text) {
    final start = text.indexOf('{');
    if (start == -1) {
      return '';
    }

    var depth = 0;
    var inString = false;
    var escaped = false;

    for (var i = start; i < text.length; i++) {
      final ch = text[i];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (ch == '\\') {
          escaped = true;
        } else if (ch == '"') {
          inString = false;
        }
        continue;
      }

      if (ch == '"') {
        inString = true;
        continue;
      }
      if (ch == '{') {
        depth++;
        continue;
      }
      if (ch == '}') {
        depth--;
        if (depth == 0) {
          return text.substring(start, i + 1).trim();
        }
      }
    }

    return text.substring(start).trim();
  }

  String _balanceObjectBraces(String text) {
    var open = 0;
    var close = 0;
    for (final rune in text.runes) {
      if (rune == 123) {
        open++;
      } else if (rune == 125) {
        close++;
      }
    }
    if (open <= close) {
      return text;
    }
    return text + ('}' * (open - close));
  }

  void _onEnterPressed() {
    if (_mode != _ScanMode.receipt) {
      return;
    }

    if (_receiptFlowState == _ReceiptFlowState.readyToSubmit || _receiptFlowState == _ReceiptFlowState.failure) {
      _saveExtractedReceipt();
    }
  }

  void _startProcessingHints() {
    _processingHintTimer?.cancel();
    setState(() {
      _processingHint = _processingHints[_random.nextInt(_processingHints.length)];
      _processingHintDots = 1;
    });
    var tick = 0;
    _processingHintTimer = Timer.periodic(const Duration(milliseconds: 450), (_) {
      if (!mounted || !_isAnyProcessingFlowActive()) {
        return;
      }
      setState(() {
        _processingHintDots = _processingHintDots == 3 ? 1 : _processingHintDots + 1;
        tick += 1;
        if (tick % 11 == 0) {
          _processingHint = _processingHints[_random.nextInt(_processingHints.length)];
        }
      });
    });
  }

  String _processingHintWithDots() {
    final base = _processingHint.replaceAll(RegExp(r'\.+$'), '');
    return '$base${'.' * _processingHintDots}';
  }

  bool _isAnyProcessingFlowActive() {
    return _receiptFlowState == _ReceiptFlowState.processing || _barcodeFlowState == _BarcodeFlowState.processing;
  }

  void _stopProcessingHints() {
    _processingHintTimer?.cancel();
    _processingHintTimer = null;
  }

  void _resetReceiptFlow() {
    _stopProcessingHints();
    if (!mounted) {
      return;
    }
    setState(() {
      _receiptFlowState = _ReceiptFlowState.idle;
      _pendingReceiptPayload = null;
      _receiptFlowMessage = null;
      _receiptPreviewLocked = false;
      _frozenReceiptImageBytes = null;
    });
  }

  Future<void> _saveExtractedReceipt() async {
    if (_receiptFlowState == _ReceiptFlowState.processing) {
      return;
    }

    final payload = _pendingReceiptPayload;
    if (payload == null) {
      return;
    }

    setState(() {
      _receiptFlowState = _ReceiptFlowState.processing;
      _receiptFlowMessage = null;
    });
    _startProcessingHints();

    try {
      await _persistReceiptPayload(payload);
      if (!mounted) {
        return;
      }

      setState(() {
        _receiptFlowState = _ReceiptFlowState.success;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _receiptFlowState = _ReceiptFlowState.failure;
        _receiptFlowMessage = e.toString();
      });
    } finally {
      _stopProcessingHints();
    }
  }

  Future<void> _showProductInsightsSheet({required Set<String> productNames}) async {
    if (!mounted) {
      return;
    }

    final productInsights = await _buildProductInsights(productNames);
    if (!mounted || productInsights.insights.isEmpty) {
      return;
    }

    final productName = productNames.isNotEmpty ? productNames.first.trim() : '';
    final hasDeals = productInsights.hasDeals && productName.isNotEmpty;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quick insights', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                for (final insight in productInsights.insights) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(padding: EdgeInsets.only(top: 4), child: Icon(Icons.bolt_rounded, size: 16)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(insight, style: Theme.of(context).textTheme.bodyMedium)),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      if (hasDeals) {
                        context.go('/deals?query=${Uri.encodeQueryComponent(productName)}');
                      }
                    },
                    icon: Icon(hasDeals ? Icons.local_offer_rounded : Icons.check_rounded),
                    label: Text(hasDeals ? 'See deals now' : 'Continue'),
                    style: FilledButton.styleFrom(foregroundColor: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<({List<String> insights, bool hasDeals})> _buildProductInsights(Set<String> productNames) async {
    final names = productNames.map((name) => _asString(name)).where((name) => name.isNotEmpty).toSet();
    if (names.isEmpty) {
      return (insights: const <String>[], hasDeals: false);
    }

    final activeDeals = await _catalogDealsRepository.watchActiveCatalogDeals(fetchLimit: 400).first;
    if (activeDeals.isEmpty) {
      return (insights: const <String>[], hasDeals: false);
    }

    final matchedDeals = _dealTextMatcherService.matchDeals(shoppingListTexts: names, deals: activeDeals, minScore: 0.48);
    if (matchedDeals.isEmpty) {
      return (insights: const <String>['This product is not on sale right now, but we will keep watching for deals.'], hasDeals: false);
    }

    final uniqueDeals = <String, CatalogDealItem>{};
    for (final deal in matchedDeals) {
      uniqueDeals.putIfAbsent(deal.productId, () => deal);
    }

    final deals = uniqueDeals.values.toList(growable: false);
    final totalSavings = deals.fold<int>(0, (total, deal) => total + deal.savingsCents);
    final topDeal = deals.reduce((left, right) => (left.discountPercent ?? 0) >= (right.discountPercent ?? 0) ? left : right);

    final storeCounts = <String, int>{};
    for (final deal in deals) {
      storeCounts.update(deal.storeName, (value) => value + 1, ifAbsent: () => 1);
    }
    final topStore = storeCounts.entries.reduce((left, right) => left.value >= right.value ? left : right);

    final productCountLabel = names.length == 1 ? 'This product is' : '${deals.length} products are';

    return (
      insights: <String>[
        '$productCountLabel currently on sale.',
        'Best immediate pick: ${topDeal.title} at ${topDeal.storeName}${(topDeal.discountPercent ?? 0) > 0 ? ' (-${topDeal.discountPercent}%)' : ''}.',
        'Potential savings across matched items: ${formatCents(totalSavings)}.',
        'Most opportunities are at ${topStore.key} (${topStore.value} items).',
      ],
      hasDeals: true,
    );
  }

  Future<void> _persistReceiptPayload(Map<String, dynamic> payload) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError('You must be logged in to store a receipt.');
    }

    final receipt = payload['receipt'] as Map<String, dynamic>?;
    final items = payload['items'] as List<dynamic>?;
    if (receipt == null) {
      throw StateError('Receipt data is missing.');
    }

    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(uid);
    final receiptRef = userRef.collection('receipts').doc();
    final parsedDate = _parseDate(receipt['date']);
    final normalizedStoreName = _asString(receipt['store_name'], fallback: 'Unknown store');
    final totalPrice = _asInt(receipt['total_price']);

    await firestore.runTransaction((txn) async {
      final userSnapshot = await txn.get(userRef);
      final userData = userSnapshot.data() ?? <String, dynamic>{};
      final statsData = userData['stats'] is Map<String, dynamic> ? userData['stats'] as Map<String, dynamic> : <String, dynamic>{};
      final existingStores = statsData['most_visited_stores'] is List ? List<dynamic>.from(statsData['most_visited_stores'] as List) : <dynamic>[];

      final storeStats = existingStores.whereType<Map<String, dynamic>>().map((store) => Map<String, dynamic>.from(store)).toList();

      final existingIndex = storeStats.indexWhere((store) => _normalizedStoreKey(store['store_name']) == _normalizedStoreKey(normalizedStoreName));
      if (existingIndex == -1) {
        storeStats.add({'store_name': normalizedStoreName, 'logo_url': '', 'visit_count': 1});
      } else {
        final existingVisitCount = _asInt(storeStats[existingIndex]['visit_count']);
        storeStats[existingIndex] = {...storeStats[existingIndex], 'store_name': normalizedStoreName, 'visit_count': existingVisitCount + 1};
      }
      storeStats.sort((a, b) => _asInt(b['visit_count']).compareTo(_asInt(a['visit_count'])));

      txn.set(receiptRef, {
        'receipt_id': receiptRef.id,
        'store_name': normalizedStoreName,
        'total_price': totalPrice,
        'item_count': _asInt(receipt['item_count'], fallback: (items ?? const <dynamic>[]).length),
        'raw_ocr': _asString(receipt['raw_ocr']),
        'date': Timestamp.fromDate(parsedDate),
        'created_at': FieldValue.serverTimestamp(),
      });

      for (final rawItem in items ?? const <dynamic>[]) {
        if (rawItem is! Map<String, dynamic>) {
          continue;
        }

        final itemRef = receiptRef.collection('items').doc();
        final rawName = _asString(rawItem['raw_name'], fallback: 'Unknown item');
        txn.set(itemRef, {
          'item_id': itemRef.id,
          'raw_name': rawName,
          'name': rawName,
          'unit_price': _asInt(rawItem['unit_price']),
          'quantity': _asNum(rawItem['quantity']),
          'total_price': _asInt(rawItem['total_price']),
          'created_at': FieldValue.serverTimestamp(),
        });
      }

      txn.set(userRef, {
        'stats': {
          'total_spent': _asInt(statsData['total_spent']) + totalPrice,
          'receipts_scanned': _asInt(statsData['receipts_scanned']) + 1,
          'most_visited_stores': storeStats.take(10).toList(),
        },
      }, SetOptions(merge: true));
    });

    try {
      await _syncCommonBoughtProducts(uid: uid);
    } catch (error) {
      debugPrint('Could not update common bought products: $error');
    }
  }

  Future<void> _syncCommonBoughtProducts({required String uid}) async {
    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(uid);
    final receiptsRef = userRef.collection('receipts');
    final commonProductsRef = userRef.collection('common_products');

    final now = DateTime.now().toUtc();
    final recentReceiptCutoff = now.subtract(const Duration(days: _commonBoughtProductWindowDays));
    final inactiveCutoff = now.subtract(const Duration(days: _commonBoughtProductInactivityDays));

    final recentReceiptsSnapshot = await receiptsRef
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(recentReceiptCutoff))
        .orderBy('date', descending: true)
        .get();
    final productStatsByKey = <String, _CommonBoughtProductStats>{};

    for (final receiptDoc in recentReceiptsSnapshot.docs) {
      final receiptData = receiptDoc.data();
      final receiptDate = _dateFromReceipt(receiptData);
      final receiptItemsSnapshot = await receiptDoc.reference.collection('items').get();
      final keysSeenInReceipt = <String>{};

      for (final itemDoc in receiptItemsSnapshot.docs) {
        final rawName = _asString(itemDoc.data()['raw_name']);
        final productKey = _normalizeCommonProductKey(rawName);
        if (productKey.isEmpty || !keysSeenInReceipt.add(productKey)) {
          continue;
        }

        final stats = productStatsByKey.putIfAbsent(productKey, () => _CommonBoughtProductStats(name: rawName, lastPurchasedAt: receiptDate));
        stats.recordPurchase(candidateName: rawName, purchasedAt: receiptDate);
      }
    }

    final existingCommonProductsSnapshot = await commonProductsRef.get();
    final activeKeys = <String>{};
    final batch = firestore.batch();

    for (final entry in productStatsByKey.entries) {
      final productKey = entry.key;
      final stats = entry.value;
      final qualifies = stats.purchaseCount >= _commonBoughtProductMinPurchases && !stats.lastPurchasedAt.isBefore(inactiveCutoff);
      final docRef = commonProductsRef.doc(productKey);

      if (!qualifies) {
        continue;
      }

      activeKeys.add(productKey);
      batch.set(docRef, {
        'item_id': productKey,
        'name': stats.name,
        'brand': null,
        'image_url': null,
        'purchase_count': stats.purchaseCount,
        'last_purchased_at': Timestamp.fromDate(stats.lastPurchasedAt),
        'added_at': Timestamp.fromDate(stats.lastPurchasedAt),
      }, SetOptions(merge: true));
    }

    for (final doc in existingCommonProductsSnapshot.docs) {
      if (activeKeys.contains(doc.id)) {
        continue;
      }
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  DateTime _parseDate(dynamic value) {
    final parsed = DateTime.tryParse(_asString(value));
    return parsed?.toUtc() ?? DateTime.now().toUtc();
  }

  String _normalizedStoreKey(dynamic value) {
    return _asString(value).toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  DateTime _dateFromReceipt(Map<String, dynamic> receiptData) {
    final value = receiptData['date'];
    if (value is Timestamp) {
      return value.toDate().toUtc();
    }
    return _parseDate(value);
  }

  String _normalizeCommonProductKey(String value) {
    final normalized = value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) {
      return '';
    }
    return normalized.replaceAll(' ', '_');
  }

  Map<String, dynamic> _normalizeDbPayload(Map<String, dynamic> decoded, String fallbackRawOcr) {
    final receiptRaw = decoded['receipt'] is Map<String, dynamic> ? decoded['receipt'] as Map<String, dynamic> : <String, dynamic>{};
    final itemsRaw = decoded['items'] is List ? decoded['items'] as List : const <dynamic>[];

    final normalizedItems = <Map<String, dynamic>>[];
    for (final item in itemsRaw) {
      if (item is! Map<String, dynamic>) {
        continue;
      }

      normalizedItems.add({
        'item_id': _asString(item['item_id'], fallback: '__AUTO_ID__'),
        'raw_name': _asString(item['raw_name'], fallback: 'Unknown item'),
        'unit_price': _asInt(item['unit_price']),
        'quantity': _asNum(item['quantity']),
        'total_price': _asInt(item['total_price']),
      });
    }

    final normalizedReceipt = <String, dynamic>{
      'receipt_id': _asString(receiptRaw['receipt_id'], fallback: '__AUTO_ID__'),
      'store_name': _asString(receiptRaw['store_name'], fallback: 'Unknown store'),
      'total_price': _asInt(receiptRaw['total_price']),
      'item_count': _asInt(receiptRaw['item_count'], fallback: normalizedItems.length),
      'raw_ocr': _asString(receiptRaw['raw_ocr'], fallback: fallbackRawOcr),
      'date': _asString(receiptRaw['date'], fallback: DateTime.now().toUtc().toIso8601String()),
    };

    return {'receipt': normalizedReceipt, 'items': normalizedItems};
  }

  bool _isReceiptDetected(Map<String, dynamic> payload) {
    final receipt = payload['receipt'] is Map<String, dynamic> ? payload['receipt'] as Map<String, dynamic> : const <String, dynamic>{};
    final items = payload['items'] is List ? payload['items'] as List : const <dynamic>[];

    final storeName = _normalizedStoreKey(receipt['store_name']);
    final hasKnownStore =
        storeName.isNotEmpty && storeName != 'unknown' && storeName != 'unknown store' && storeName != 'store' && storeName != 'n a';

    final totalPrice = _asInt(receipt['total_price']);
    final itemCount = _asInt(receipt['item_count']);
    final rawOcr = _asString(receipt['raw_ocr']);

    final hasMeaningfulItems = items.whereType<Map<String, dynamic>>().any((item) {
      final name = _asString(item['raw_name']).toLowerCase();
      final unitPrice = _asInt(item['unit_price']);
      final lineTotal = _asInt(item['total_price']);
      return name.isNotEmpty && name != 'unknown item' && (unitPrice > 0 || lineTotal > 0);
    });

    final hasReceiptLikeOcr = _hasReceiptLikeOcr(rawOcr);
    final hasPositiveSignals = hasKnownStore || totalPrice > 0 || itemCount > 0 || hasMeaningfulItems || hasReceiptLikeOcr;
    return hasPositiveSignals;
  }

  bool _hasReceiptLikeOcr(String text) {
    final cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length < 24) {
      return false;
    }

    final digitCount = RegExp(r'\d').allMatches(cleaned).length;
    final hasPricePattern = RegExp(r'\d+[\.,]\d{2}').hasMatch(cleaned);
    final hasKeyword = RegExp(r'\b(total|subtotal|tax|vat|receipt|cash|card|change|qty)\b', caseSensitive: false).hasMatch(cleaned);

    return hasPricePattern || (hasKeyword && digitCount >= 4);
  }

  String _asString(dynamic value, {String fallback = ''}) {
    if (value == null) {
      return fallback;
    }
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    if (value is String) {
      final parsed = num.tryParse(value);
      if (parsed != null) {
        return parsed.round();
      }
    }
    return fallback;
  }

  num _asNum(dynamic value, {num fallback = 1}) {
    if (value is num) {
      return value;
    }
    if (value is String) {
      final parsed = num.tryParse(value);
      if (parsed != null) {
        return parsed;
      }
    }
    return fallback;
  }

  String _mimeTypeForPath(String path) {
    final lowerPath = path.toLowerCase();
    if (lowerPath.endsWith('.png')) return 'image/png';
    if (lowerPath.endsWith('.webp')) return 'image/webp';
    if (lowerPath.endsWith('.heic')) return 'image/heic';
    if (lowerPath.endsWith('.heif')) return 'image/heif';
    return 'image/jpeg';
  }

  void _closeScanner() {
    _setScanBarAnimationActive(false);

    final returnTo = _normalizedReturnTo(widget.returnTo);
    if (returnTo != null) {
      context.go(returnTo);
      return;
    }

    if (context.canPop()) {
      context.pop();
      return;
    }

    context.go('/home');
  }

  String? _normalizedReturnTo(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed.startsWith('/') ? trimmed : '/$trimmed';
  }
}

enum _ScanMode { receipt, barcode }

enum _ReceiptFlowState { idle, readyToSubmit, processing, failure, success }

enum _BarcodeFlowState { idle, processing, failure, success }

class _ModeTab extends StatelessWidget {
  const _ModeTab({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        decoration: BoxDecoration(color: selected ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(16)),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(color: selected ? Colors.black87 : Colors.white, fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}

class _CommonBoughtProductStats {
  _CommonBoughtProductStats({required this.name, required this.lastPurchasedAt}) : purchaseCount = 0;

  String name;
  DateTime lastPurchasedAt;
  int purchaseCount;

  void recordPurchase({required String candidateName, required DateTime purchasedAt}) {
    purchaseCount += 1;

    if (purchasedAt.isAfter(lastPurchasedAt)) {
      lastPurchasedAt = purchasedAt;
      name = candidateName;
    }
  }
}

class _UserVisibleError implements Exception {
  const _UserVisibleError(this.message);

  final String message;

  @override
  String toString() => message;
}
