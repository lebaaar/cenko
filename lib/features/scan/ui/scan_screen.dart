import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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

  late _ScanMode _mode;
  bool _isHandlingDetection = false;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode == 'barcode' ? _ScanMode.barcode : _ScanMode.receipt;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              final isFrontCamera = state.cameraDirection == CameraFacing.front;
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()..scale(isFrontCamera ? -1.0 : 1.0, 1.0, 1.0),
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
          ),
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
                                  onTap: () => setState(() => _mode = _ScanMode.barcode),
                                ),
                                _ModeTab(
                                  label: 'Receipt',
                                  selected: _mode == _ScanMode.receipt,
                                  onTap: () => setState(() => _mode = _ScanMode.receipt),
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
                  ValueListenableBuilder<MobileScannerState>(
                    valueListenable: _controller,
                    builder: (context, state, _) {
                      final isOn = state.torchState == TorchState.on;
                      return _ControlButton(icon: isOn ? Icons.flash_on_rounded : Icons.flash_off_rounded, onTap: _controller.toggleTorch);
                    },
                  ),
                  const SizedBox(width: 18),
                  _ControlButton(icon: Icons.photo_library_rounded, onTap: _pickFromGallery),
                  const SizedBox(width: 18),
                  _ControlButton(icon: Icons.cameraswitch_rounded, onTap: _controller.switchCamera),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
    final file = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (file == null) {
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

  void _closeScanner() {
    if (context.canPop()) {
      context.pop();
      return;
    }

    context.go('/home');
  }
}

enum _ScanMode { receipt, barcode }

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
