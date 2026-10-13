import 'dart:async';

import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';

/// Atribuição de instalação e campanhas (AppsFlyer).
///
/// Desligado enquanto o build não trouxer a chave:
///   --dart-define=PAGO_AF_DEV_KEY=...         (AppsFlyer → App Settings → Dev key)
///   --dart-define=PAGO_AF_APPLE_APP_ID=...    (só iOS: Apple ID numérico do app, sem "id")
/// Antes de ligar: privacidade do site/app e "Segurança dos dados" da Play
/// (e a ficha da App Store) precisam citar a AppsFlyer.
class MmpService {
  MmpService._();

  static final instance = MmpService._();

  static const devKeyFromEnv = String.fromEnvironment('PAGO_AF_DEV_KEY');
  static const appleAppIdFromEnv = String.fromEnvironment('PAGO_AF_APPLE_APP_ID');

  final _sdk = AppsFlyerSdk.instance;
  Future<void>? _starting;
  String? _userId;
  String? _appsFlyerId;

  /// Id do aparelho na AppsFlyer. Vai junto na confirmação da compra para o
  /// servidor mandar a receita (S2S) ligada a esta instalação.
  String? get appsFlyerId => _appsFlyerId;

  bool get started => _starting != null;

  static bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  static bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  /// Chamar depois da resposta do ATT ([trackingAuthorized]): no iPhone o SDK
  /// só pode ler o IDFA com o consentimento, e a sessão de instalação já sai
  /// com o status certo. Seguro chamar de novo (troca de conta só muda o id).
  Future<void> init({
    required String userId,
    required bool trackingAuthorized,
    String devKey = devKeyFromEnv,
    String appleAppId = appleAppIdFromEnv,
  }) {
    if (kIsWeb || !(_isAndroid || _isIOS) || devKey.isEmpty) return Future.value();
    if (_isIOS && appleAppId.isEmpty) return Future.value();
    if (_starting != null) return _switchUser(userId);
    _userId = userId;
    return _starting = _start(devKey, appleAppId, trackingAuthorized);
  }

  Future<void> _start(String devKey, String appleAppId, bool trackingAuthorized) async {
    try {
      await _sdk.init(devKey: devKey, appId: _isIOS ? appleAppId : null);
      if (_isIOS) await _sdk.setDisableAdvertisingIdentifiers(!trackingAuthorized);
      await _sdk.setCustomerUserId(_userId!);
      await _sdk.setCurrencyCode('BRL');
      if (_isAndroid) {
        try {
          await _sdk.collectDataFromLauncherActivity();
        } on AppsFlyerException catch (error) {
          debugPrint('AppsFlyer sem referrer da activity: $error');
        }
      }
      await _sdk.registerSessionReadyListener(() => unawaited(_startSession()));
    } catch (error) {
      debugPrint('AppsFlyer não iniciou: $error');
    }
  }

  Future<void> _startSession() async {
    try {
      await _sdk.start();
      _appsFlyerId ??= await _sdk.getAppsFlyerUID();
    } catch (error) {
      debugPrint('AppsFlyer sem sessão: $error');
    }
  }

  Future<void> _switchUser(String userId) async {
    await _starting;
    if (_userId == userId) return;
    _userId = userId;
    try {
      await _sdk.setCustomerUserId(userId);
    } catch (error) {
      debugPrint('AppsFlyer não trocou a conta: $error');
    }
  }

  /// Sinal de conversão para otimizar campanhas (o anúncio aprende quem
  /// assina). Não leva `af_revenue` de propósito: a receita real e o LTV
  /// (líquido da taxa da loja, renovações, estornos) vêm só do servidor via
  /// S2S (`functions/mmp_s2s.js`), para não contar a mesma venda duas vezes.
  Future<void> logFrontendPurchase(double price, String currency) async {
    if (!started) return;
    try {
      await _sdk.logEvent(
        'pago_premium_checkout',
        eventValues: {
          'af_price': price,
          'af_currency': currency,
          'af_content_id': 'premium_mensal',
        },
      );
    } catch (error) {
      debugPrint('AppsFlyer não registrou a compra: $error');
    }
  }
}
