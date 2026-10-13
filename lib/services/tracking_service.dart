import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../utils/constants.dart';

/// Pedido de rastreio da Apple (App Tracking Transparency).
///
/// Só pode aparecer quando existir um SDK de anúncio/atribuição no app e a
/// ficha de privacidade da App Store declarar "rastreamento"; sem isso a Apple
/// reprova. Por isso fica desligado até `AppConstants.trackingEnabled`.
class TrackingService {
  TrackingService._();

  static final instance = TrackingService._();

  var _asked = false;

  bool get _available =>
      AppConstants.trackingEnabled &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.iOS;

  Future<TrackingStatus> status() async {
    if (!_available) return TrackingStatus.notSupported;
    try {
      return await AppTrackingTransparency.trackingAuthorizationStatus;
    } catch (error) {
      debugPrint('ATT indisponível: $error');
      return TrackingStatus.notSupported;
    }
  }

  /// Mostra o pedido uma única vez, com o app já na tela (o iOS ignora o
  /// pedido feito antes do app ficar ativo). Devolve se o rastreio foi aceito.
  Future<bool> requestIfNeeded() async {
    if (!_available || _asked) return await status() == TrackingStatus.authorized;
    _asked = true;
    try {
      final current = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (current != TrackingStatus.notDetermined) {
        return current == TrackingStatus.authorized;
      }
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 600));
      final result = await AppTrackingTransparency.requestTrackingAuthorization();
      return result == TrackingStatus.authorized;
    } catch (error) {
      debugPrint('Falha no pedido de rastreio: $error');
      return false;
    }
  }
}
