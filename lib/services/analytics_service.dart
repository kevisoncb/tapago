import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'mmp_service.dart';

/// Firebase Analytics (GA4). Alimenta o Google Ads (campanhas de app) e a análise
/// de funil. Nunca leva nome, telefone, valor da caderneta ou chave PIX: só
/// contagens e indicadores. Sem Firebase iniciado (testes, web) não faz nada.
class AnalyticsService implements ProductMetrics {
  AnalyticsService._();

  static final instance = AnalyticsService._();

  // Nomes dos eventos. `primeiro_lancamento` é o evento de valor das campanhas.
  static const eventFirstDebt = 'primeiro_lancamento';
  static const eventDebtCreated = 'lancamento_criado';
  static const eventPaymentRecorded = 'baixa_registrada';
  static const eventPaymentCorrected = 'baixa_corrigida';
  static const eventRemindersEnabled = 'avisos_ligados';

  bool get _on {
    if (kIsWeb) return false;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return false;
    }
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _event(String name, [Map<String, Object>? parameters]) async {
    if (!_on) return;
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: name,
        parameters: parameters,
      );
    } catch (error) {
      debugPrint('Analytics: $error');
    }
  }

  Future<void> logSignUp() async {
    if (!_on) return;
    try {
      await FirebaseAnalytics.instance.logSignUp(signUpMethod: 'email');
    } catch (error) {
      debugPrint('Analytics: $error');
    }
  }

  Future<void> setUser(String? uid, {bool? premium}) async {
    if (!_on) return;
    try {
      await FirebaseAnalytics.instance.setUserId(id: uid);
      if (premium != null) {
        await FirebaseAnalytics.instance.setUserProperty(
          name: 'plano',
          value: premium ? 'premium' : 'gratis',
        );
      }
    } catch (error) {
      debugPrint('Analytics: $error');
    }
  }

  Future<void> logPaywallView() => _event('visualizou_premium');

  Future<void> logRemindersEnabled() => _event(eventRemindersEnabled);

  Future<void> logPurchase(double value, String currency) async {
    if (!_on) return;
    try {
      await FirebaseAnalytics.instance.logPurchase(
        value: value,
        currency: currency,
        items: [
          AnalyticsEventItem(itemId: 'premium_mensal', itemName: 'Pagô Premium'),
        ],
      );
    } catch (error) {
      debugPrint('Analytics: $error');
    }
  }

  @override
  Future<void> logDebtCreated({
    required bool firstDebt,
    required bool installment,
    required String source,
    required int recordCount,
  }) async {
    await _event(eventDebtCreated, {
      'parcelado': installment ? 1 : 0,
      'origem': source,
      'quantidade': recordCount,
    });
    if (firstDebt) await _event(eventFirstDebt);
  }

  @override
  Future<void> logManualWriteOffRecorded({required bool settledReceivable}) =>
      _event(eventPaymentRecorded, {'quitou': settledReceivable ? 1 : 0});

  @override
  Future<void> logManualWriteOffCorrected() => _event(eventPaymentCorrected);
}

/// Envia cada métrica de produto a todos os destinos (AppsFlyer e Analytics).
class MetricsFanOut implements ProductMetrics {
  const MetricsFanOut(this._targets);

  final List<ProductMetrics> _targets;

  Future<void> _all(Future<void> Function(ProductMetrics) call) async {
    for (final target in _targets) {
      try {
        await call(target);
      } catch (error) {
        debugPrint('Métrica: $error');
      }
    }
  }

  @override
  Future<void> logDebtCreated({
    required bool firstDebt,
    required bool installment,
    required String source,
    required int recordCount,
  }) => _all(
    (target) => target.logDebtCreated(
      firstDebt: firstDebt,
      installment: installment,
      source: source,
      recordCount: recordCount,
    ),
  );

  @override
  Future<void> logManualWriteOffRecorded({required bool settledReceivable}) =>
      _all(
        (target) => target.logManualWriteOffRecorded(
          settledReceivable: settledReceivable,
        ),
      );

  @override
  Future<void> logManualWriteOffCorrected() =>
      _all((target) => target.logManualWriteOffCorrected());
}
