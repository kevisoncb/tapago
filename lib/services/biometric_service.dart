import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  final _auth = LocalAuthentication();

  bool get _supportedPlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<bool> get isSupported async {
    if (!_supportedPlatform) return false;
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      return await _auth.canCheckBiometrics;
    } catch (error) {
      debugPrint('Biometria indisponível: $error');
      return false;
    }
  }

  /// Sem digital, rosto nem senha de tela o bloqueio não tem como ser aberto.
  Future<bool> get canLock async {
    if (!_supportedPlatform) return false;
    try {
      return await _auth.isDeviceSupported();
    } catch (error) {
      debugPrint('Bloqueio indisponível: $error');
      return false;
    }
  }

  Future<bool> authenticate() async {
    if (!_supportedPlatform) return false;
    try {
      return await _auth.authenticate(
        localizedReason: 'Use sua digital ou o reconhecimento facial para abrir o Pagô.',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (error) {
      debugPrint('Falha na biometria: $error');
      return false;
    }
  }
}
