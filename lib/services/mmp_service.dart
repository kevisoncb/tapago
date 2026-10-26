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
///
/// Fluxo: [init] roda na primeira abertura do app (`main.dart`), depois do ATT,
/// mesmo sem login, para a instalação ser contada. Depois do login,
/// [setUserId] liga as ações seguintes à conta.
abstract interface class ProductMetrics {
  Future<void> logDebtCreated({
    required bool firstDebt,
    required bool installment,
    required String source,
    required int recordCount,
  });

  Future<void> logManualWriteOffRecorded({required bool settledReceivable});

  Future<void> logManualWriteOffCorrected();
}

class MmpService implements ProductMetrics {
  MmpService._();

  static final instance = MmpService._();

  static const devKeyFromEnv = String.fromEnvironment('PAGO_AF_DEV_KEY');
  static const appleAppIdFromEnv = String.fromEnvironment(
    'PAGO_AF_APPLE_APP_ID',
  );

  // Eventos de funil (nomes padrão da AppsFlyer que Google e Meta entendem).
  static const eventRegistration = 'af_complete_registration';
  static const eventPaywallView = 'af_premium_paywall_view';
  static const eventBillCreated = 'af_bill_created';
  static const eventDebtCreated = 'pago_debt_created';
  static const eventManualWriteOffRecorded = 'pago_manual_write_off_recorded';
  static const eventManualWriteOffCorrected = 'pago_manual_write_off_corrected';

  final _sdk = AppsFlyerSdk.instance;
  Future<void>? _starting;
  String? _userId;
  String? _appliedUserId;
  String? _appsFlyerId;
  Future<void> _identityWork = Future.value();

  /// Id do aparelho na AppsFlyer. Vai junto na confirmação da compra para o
  /// servidor mandar a receita (S2S) ligada a esta instalação.
  String? get appsFlyerId => _appsFlyerId;

  bool get started => _starting != null;

  static bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  static bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  /// Primeira abertura do app, com o ATT já respondido ([trackingAuthorized]):
  /// no iPhone o SDK só pode ler o IDFA com o consentimento, e a sessão de
  /// instalação já sai com o status certo. Não depende de login. Chamar de
  /// novo não faz nada.
  Future<void> init({
    required bool trackingAuthorized,
    String devKey = devKeyFromEnv,
    String appleAppId = appleAppIdFromEnv,
  }) {
    if (kIsWeb || !(_isAndroid || _isIOS) || devKey.isEmpty) {
      return Future.value();
    }
    if (_isIOS && appleAppId.isEmpty) return Future.value();
    return _starting ??= _start(devKey, appleAppId, trackingAuthorized);
  }

  Future<void> _start(
    String devKey,
    String appleAppId,
    bool trackingAuthorized,
  ) async {
    try {
      await _sdk.init(devKey: devKey, appId: _isIOS ? appleAppId : null);
      if (_isIOS) {
        await _sdk.setDisableAdvertisingIdentifiers(!trackingAuthorized);
      }
      await _sdk.setCurrencyCode('BRL');
      await _applyUserId();
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

  /// Depois do login: liga as ações seguintes à conta (`customer_user_id`).
  /// Se o login chegar antes do [init] terminar, o id fica guardado e é
  /// aplicado assim que o SDK iniciar.
  Future<void> setUserId(String uid) async {
    if (uid.isEmpty) return;
    _userId = uid;
    final starting = _starting;
    if (starting == null) return;
    await starting;
    await _applyUserId();
  }

  /// O aparelho continua atribuído à instalação, mas eventos após sair não
  /// devem carregar o identificador da conta anterior.
  Future<void> clearUserId() async {
    _userId = null;
    final starting = _starting;
    if (starting == null) {
      _appliedUserId = null;
      return;
    }
    await starting;
    await _applyUserId();
  }

  Future<void> _applyUserId() {
    _identityWork = _identityWork.then((_) async {
      final uid = _userId;
      if (uid == _appliedUserId) return;
      try {
        await _sdk.setCustomerUserId(uid ?? '');
        _appliedUserId = uid;
      } catch (error) {
        debugPrint('AppsFlyer não atualizou a conta: $error');
      }
    });
    return _identityWork;
  }

  Future<void> _log(String name, [Map<String, dynamic>? values]) async {
    final starting = _starting;
    if (starting == null) return;
    try {
      await starting;
      await _sdk.logEvent(name, eventValues: values);
    } catch (error) {
      debugPrint('AppsFlyer não registrou $name: $error');
    }
  }

  /// Conta criada no Firebase Auth.
  Future<void> logRegistrationComplete() =>
      _log(eventRegistration, {'af_registration_method': 'email'});

  /// Tela Premium aberta (quem viu o preço).
  Future<void> logPremiumPaywallView() => _log(eventPaywallView);

  /// Boleto a pagar cadastrado (uso forte da ferramenta). Um evento por
  /// cadastro, mesmo que gere várias parcelas.
  Future<void> logBillCreated() => _log(eventBillCreated);

  /// Atributos operacionais, sem nome, telefone, valor, vencimento ou id da
  /// caderneta. [source] é controlado pelo app (`manual` ou `csv`).
  @override
  Future<void> logDebtCreated({
    required bool firstDebt,
    required bool installment,
    required String source,
    required int recordCount,
  }) => _log(eventDebtCreated, {
    'pago_first_debt': firstDebt,
    'pago_installment': installment,
    'pago_source': source == 'csv' ? 'csv' : 'manual',
    'pago_record_count': recordCount.clamp(1, 12),
  });

  @override
  Future<void> logManualWriteOffRecorded({required bool settledReceivable}) =>
      _log(eventManualWriteOffRecorded, {
        'pago_settled_receivable': settledReceivable,
      });

  @override
  Future<void> logManualWriteOffCorrected() =>
      _log(eventManualWriteOffCorrected);

  /// Sinal de conversão para otimizar campanhas (o anúncio aprende quem
  /// assina). Não leva `af_revenue` de propósito: a receita real e o LTV
  /// (líquido da taxa da loja, renovações, estornos) vêm só do servidor via
  /// S2S (`functions/mmp_s2s.js`), para não contar a mesma venda duas vezes.
  Future<void> logFrontendPurchase(double price, String currency) =>
      _log('pago_premium_checkout', {
        'af_price': price,
        'af_currency': currency,
        'af_content_id': 'premium_mensal',
      });
}
