import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Luxury Biometric Authentication Service (Face ID on iOS / Fingerprint & BiometricPrompt on Android)
/// Supports quick app unlock and sensitive transaction authorization (Store checkouts / Membership upgrades).
class BiometricAuthService {
  static final BiometricAuthService instance = BiometricAuthService._internal();
  BiometricAuthService._internal();

  final LocalAuthentication _auth = LocalAuthentication();
  static const String _prefBiometricEnabled = 'incline_biometric_lock_enabled';

  /// Checks if the hardware supports biometrics and is enrolled by the member
  Future<bool> isBiometricAvailable() async {
    if (kIsWeb) return false;
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck && isSupported;
    } on PlatformException catch (e) {
      debugPrint('[INCLINE] isBiometricAvailable error: $e');
      return false;
    }
  }

  /// Lists available biometric types (Face ID, Fingerprint, Iris)
  Future<List<BiometricType>> getAvailableBiometrics() async {
    if (kIsWeb) return [];
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException catch (e) {
      debugPrint('[INCLINE] getAvailableBiometrics error: $e');
      return [];
    }
  }

  /// Human-readable label for the device's biometric sensor (e.g. "Face ID", "Touch ID", "Fingerprint")
  Future<String> getBiometricLabel() async {
    if (kIsWeb) return 'Biometrics';
    final available = await getAvailableBiometrics();
    if (available.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (available.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    } else if (available.contains(BiometricType.iris)) {
      return 'Iris Scanner';
    } else if (available.contains(BiometricType.strong)) {
      return 'Biometric Unlock';
    }
    return 'Biometrics';
  }

  /// Whether the member has enabled biometric lock in Incline app settings
  Future<bool> isBiometricLockEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefBiometricEnabled) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Toggle biometric lock preference
  Future<void> setBiometricLockEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefBiometricEnabled, enabled);
    } catch (e) {
      debugPrint('[INCLINE] setBiometricLockEnabled error: $e');
    }
  }

  /// Authenticate the member using Face ID or Fingerprint
  Future<bool> authenticate({
    required String reason,
    bool biometricOnly = true,
  }) async {
    if (kIsWeb) return true; // Graceful pass-through on web sandbox
    try {
      final available = await isBiometricAvailable();
      if (!available) return true;

      return await _auth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: biometricOnly,
          useErrorDialogs: true,
          sensitiveTransaction: true,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('[INCLINE] Biometric authentication error: $e');
      return false;
    }
  }
}
