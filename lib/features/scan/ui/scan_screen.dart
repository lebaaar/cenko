import 'dart:async';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

const _processingHints = <String>['Cooking...', 'Thinking...', 'Analyzing...', 'Cross-checking...', 'Almost there...'];

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, this.initialMode, this.fromList = false});

  final String? initialMode;
  final bool fromList;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final ImagePicker _imagePicker = ImagePicker();

  CameraController? _receiptCamera;
  List<CameraDescription> _cameras = <CameraDescription>[];
  int _receiptCameraIndex = 0;
  bool _receiptCameraInitializing = false;
  bool _receiptTorchOn = false;

  late final GenerativeModel _receiptModel = FirebaseAI.googleAI().generativeModel(
    model: 'gemini-2.5-flash-lite',
    generationConfig: GenerationConfig(
      temperature: 0,
      maxOutputTokens: 2048,
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
  _ReceiptFlowState _receiptFlowState = _ReceiptFlowState.idle;
  Map<String, dynamic>? _pendingReceiptPayload;
  String _processingHint = _processingHints.first;
  Timer? _processingHintTimer;
  String? _receiptFlowMessage;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode == 'barcode' ? _ScanMode.barcode : _ScanMode.receipt;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeMode();
    });
  }

  @override
  void dispose() {
    _processingHintTimer?.cancel();
    _controller.dispose();
    _receiptCamera?.dispose();
    super.dispose();
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
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 56,
                          child: Stack(
                            children: [
                              Align(
                                alignment: Alignment.center,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(20)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _ModeTab(
                                        label: 'Barcode',
                                        selected: _mode == _ScanMode.barcode,
                                        onTap: () => _onModeSelected(_ScanMode.barcode),
                                      ),
                                      _ModeTab(
                                        label: 'Receipt',
                                        selected: _mode == _ScanMode.receipt,
                                        onTap: () => _onModeSelected(_ScanMode.receipt),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: _ControlButton(icon: Icons.close_rounded, onTap: _closeScanner),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 26,
                  child: SafeArea(
                    top: false,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildFlashButton(),
                        const SizedBox(width: 18),
                        _ControlButton(icon: Icons.photo_library_rounded, onTap: _pickFromGallery),
                        const SizedBox(width: 18),
                        _ControlButton(icon: Icons.cameraswitch_rounded, onTap: _switchActiveCamera),
                      ],
                    ),
                  ),
                ),
                if (_mode == _ScanMode.receipt)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 84,
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
                                    : const Icon(Icons.camera_alt_rounded, color: Colors.black87, size: 24),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_mode == _ScanMode.receipt && _receiptFlowState != _ReceiptFlowState.idle) _buildReceiptFlowOverlay(context),
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
                  const Icon(Icons.receipt_long_rounded, size: 56, color: Colors.white),
                  const SizedBox(height: 18),
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
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _resetReceiptFlow,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.45)),
                      ),
                      child: const Text('Scan again'),
                    ),
                  ),
                ],
                if (_receiptFlowState == _ReceiptFlowState.processing) ...[
                  const SizedBox(width: 72, height: 72, child: CircularProgressIndicator(strokeWidth: 3)),
                  const SizedBox(height: 20),
                  Text(
                    _processingHint,
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
                      onPressed: _saveExtractedReceipt,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try again'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _resetReceiptFlow,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.45)),
                      ),
                      child: const Text('Back to scan'),
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
                      label: const Text('Store another'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => context.go('/profile'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.45)),
                      ),
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
      if (_receiptCameraInitializing) {
        return const Center(child: CircularProgressIndicator());
      }

      final camera = _receiptCamera;
      if (camera == null || !camera.value.isInitialized) {
        return const Center(
          child: Padding(padding: EdgeInsets.all(24), child: Text('Camera is not ready.')),
        );
      }

      return CameraPreview(camera);
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
    }
  }

  Future<void> _onModeSelected(_ScanMode mode) async {
    if (_mode == mode) {
      return;
    }

    setState(() {
      _mode = mode;
    });
    _resetReceiptFlow();

    if (mode == _ScanMode.receipt) {
      await _controller.stop();
      await _initializeReceiptCamera();
      return;
    }

    await _receiptCamera?.dispose();
    _receiptCamera = null;
    _receiptTorchOn = false;
    await _controller.start();
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

  void _onDetect(BarcodeCapture capture) {
    if (_isHandlingDetection) {
      return;
    }

    _isHandlingDetection = true;

    if (_mode == _ScanMode.barcode) {
      String? detectedCode;

      for (final barcode in capture.barcodes) {
        final value = barcode.displayValue ?? barcode.rawValue;
        if (value != null && value.trim().isNotEmpty) {
          detectedCode = value.trim();
          break;
        }
      }

      final message = detectedCode == null ? 'No valid barcode detected yet.' : 'Barcode: $detectedCode';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Receipt captured. OCR parsing is next.')));
    }

    Future<void>.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) {
        return;
      }
      _isHandlingDetection = false;
    });
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

    final didDetect = capture != null && capture.barcodes.isNotEmpty;
    final message = didDetect ? 'Image analyzed successfully.' : 'No barcode detected in selected image.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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

    setState(() => _isCapturingReceipt = true);

    try {
      final file = await camera.takePicture();
      await _extractReceiptJson(file, autoStore: true);
    } finally {
      if (mounted) {
        setState(() => _isCapturingReceipt = false);
      }
    }
  }

  Future<void> _extractReceiptJson(XFile file, {bool autoStore = false}) async {
    setState(() {
      _isProcessingReceipt = true;
      _receiptFlowMessage = null;
      _receiptFlowState = _ReceiptFlowState.processing;
      _pendingReceiptPayload = null;
    });
    _startProcessingHints();

    try {
      final bytes = await file.readAsBytes();
      final mimeType = _mimeTypeForPath(file.path);
      final response = await _receiptModel.generateContent([
        Content.text(
          'Extract receipt data and return JSON only in this exact DB-ready structure: '
          '{"receipt": {...}, "items": [...]} where fields are: '
          'receipt.receipt_id (string placeholder like "__AUTO_ID__"), '
          'receipt.store_name (string), '
          'receipt.total_price (integer cents), '
          'receipt.item_count (integer), '
          'receipt.raw_ocr (string full OCR text), '
          'receipt.date (ISO-8601 timestamp string), '
          'items[].item_id (string placeholder like "__AUTO_ID__"), '
          'items[].raw_name (string), '
          'items[].unit_price (integer cents), '
          'items[].quantity (number), '
          'items[].total_price (integer cents). '
          'All prices must be cents as integers.',
        ),
        Content.inlineData(mimeType, bytes),
      ]);

      final rawText = response.text?.trim();
      if (rawText == null || rawText.isEmpty) {
        throw StateError('Gemini returned no JSON text.');
      }

      final decoded = jsonDecode(rawText);
      if (decoded is! Map<String, dynamic>) {
        throw StateError('Unexpected JSON format returned by Gemini.');
      }

      final dbReadyPayload = _normalizeDbPayload(decoded, rawText);

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
    var index = 0;
    setState(() => _processingHint = _processingHints.first);
    _processingHintTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _receiptFlowState != _ReceiptFlowState.processing) {
        return;
      }
      index = (index + 1) % _processingHints.length;
      setState(() => _processingHint = _processingHints[index]);
    });
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
  }

  DateTime _parseDate(dynamic value) {
    final parsed = DateTime.tryParse(_asString(value));
    return parsed?.toUtc() ?? DateTime.now().toUtc();
  }

  String _normalizedStoreKey(dynamic value) {
    return _asString(value).toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
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
    if (context.canPop()) {
      context.pop();
      return;
    }

    context.go('/home');
  }
}

enum _ScanMode { receipt, barcode }

enum _ReceiptFlowState { idle, readyToSubmit, processing, failure, success }

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
