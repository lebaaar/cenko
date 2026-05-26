import 'package:safe_device/safe_device.dart';

class DeviceSecurityService {
  DeviceSecurityService._();

  /// Returns null if device is safe, or a reason string if not
  /// Always returns null in debug mode
  static Future<String?> checkDevice() async {
    try {
      final isRealDevice = await SafeDevice.isRealDevice;
      if (!isRealDevice) return 'emulator';

      final isDeviceRooted = await SafeDevice.isJailBroken;
      if (isDeviceRooted) return 'rooted';

      return null;
    } catch (_) {
      // If check throws an exception, block the app.
      return 'unknown';
    }
  }
}
