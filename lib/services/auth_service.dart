import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static final _auth = LocalAuthentication();
  static const String _keyBiometricEnabled = 'biometric_enabled';

  // التحقق: هل البصمة مفعلة من الإعدادات؟
  static Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBiometricEnabled) ?? false; // الافتراضي: غير مفعل
  }

  // تفعيل/تعطيل البصمة
  static Future<void> setBiometricEnabled(bool isEnabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricEnabled, isEnabled);
  }

  // طلب المصادقة (يتم استدعاؤها فقط إذا كان الخيار مفعلاً)
  static Future<bool> authenticate() async {
    try {
      final isAvailable = await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (!isAvailable) return true;

      return await _auth.authenticate(
        localizedReason: 'يرجى المصادقة للدخول',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (e) {
      return false;
    }
  }
}