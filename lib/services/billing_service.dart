import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../utils/constants.dart';
import 'billing_purchase_stub.dart'
    if (dart.library.io) 'billing_purchase_io.dart' as purchase;

enum PurchaseOutcome { pending, purchased, restored, canceled, unavailable, missing, error }

class PurchaseUpdate {
  const PurchaseUpdate({
    required this.outcome,
    this.message,
    this.transactionId,
  });

  final PurchaseOutcome outcome;
  final String? message;
  final String? transactionId;

  static const pending = PurchaseUpdate(outcome: PurchaseOutcome.pending);
  static const unavailable = PurchaseUpdate(
    outcome: PurchaseOutcome.unavailable,
    message: 'A Play Store não está disponível neste aparelho.',
  );
  static const missing = PurchaseUpdate(
    outcome: PurchaseOutcome.missing,
    message:
        'O plano pago_premium_monthly ainda não está publicado na Play Store.',
  );
  static const canceled = PurchaseUpdate(outcome: PurchaseOutcome.canceled);
}

class BillingService {
  BillingService({InAppPurchase? store}) : _store = store ?? InAppPurchase.instance;

  final InAppPurchase _store;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  Future<void> Function(PurchaseUpdate update)? onUpdate;
  var _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _subscription = _store.purchaseStream.listen(
      _onPurchases,
      onError: (Object error) {
        onUpdate?.call(
          PurchaseUpdate(
            outcome: PurchaseOutcome.error,
            message: 'Falha na compra: $error',
          ),
        );
      },
    );
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _started = false;
  }

  Future<PurchaseUpdate> buy() => _startStoreFlow(_store.buyNonConsumable);

  Future<PurchaseUpdate> restore() async {
    final ready = await _prepare();
    if (ready != null) return ready;
    try {
      await _store.restorePurchases();
      return PurchaseUpdate.pending;
    } catch (error) {
      return PurchaseUpdate(
        outcome: PurchaseOutcome.error,
        message: 'Não foi possível restaurar a compra: $error',
      );
    }
  }

  Future<PurchaseUpdate> _startStoreFlow(
    Future<bool> Function({required PurchaseParam purchaseParam}) buy,
  ) async {
    final ready = await _prepare();
    if (ready != null) return ready;
    try {
      final response = await _store.queryProductDetails({
        AppConstants.premiumProductId,
      });
      if (response.productDetails.isEmpty) return PurchaseUpdate.missing;
      final started = await buy(
        purchaseParam: purchase.buildPurchaseParam(response.productDetails.first),
      );
      if (!started) {
        return const PurchaseUpdate(
          outcome: PurchaseOutcome.error,
          message: 'A loja não iniciou a compra.',
        );
      }
      return PurchaseUpdate.pending;
    } catch (error) {
      return PurchaseUpdate(
        outcome: PurchaseOutcome.error,
        message: 'Não foi possível abrir a compra: $error',
      );
    }
  }

  Future<PurchaseUpdate?> _prepare() async {
    await start();
    try {
      final available = await _store.isAvailable();
      if (!available) return PurchaseUpdate.unavailable;
    } catch (error) {
      debugPrint('Loja indisponível: $error');
      return PurchaseUpdate.unavailable;
    }
    return null;
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != AppConstants.premiumProductId) {
        if (purchase.pendingCompletePurchase) {
          await _store.completePurchase(purchase);
        }
        continue;
      }
      switch (purchase.status) {
        case PurchaseStatus.pending:
          await onUpdate?.call(PurchaseUpdate.pending);
        case PurchaseStatus.purchased:
          if (purchase.pendingCompletePurchase) {
            await _store.completePurchase(purchase);
          }
          await onUpdate?.call(
            PurchaseUpdate(
              outcome: PurchaseOutcome.purchased,
              transactionId: _transactionId(purchase),
            ),
          );
        case PurchaseStatus.restored:
          if (purchase.pendingCompletePurchase) {
            await _store.completePurchase(purchase);
          }
          await onUpdate?.call(
            PurchaseUpdate(
              outcome: PurchaseOutcome.restored,
              transactionId: _transactionId(purchase),
            ),
          );
        case PurchaseStatus.canceled:
          await onUpdate?.call(PurchaseUpdate.canceled);
        case PurchaseStatus.error:
          await onUpdate?.call(
            PurchaseUpdate(
              outcome: PurchaseOutcome.error,
              message: purchase.error?.message ?? 'A compra não foi concluída.',
            ),
          );
      }
    }
  }

  String? _transactionId(PurchaseDetails purchase) {
    final id = purchase.purchaseID;
    if (id != null && id.isNotEmpty) return id;
    final token = purchase.verificationData.serverVerificationData;
    if (token.isEmpty) return null;
    return token.length > 80 ? token.substring(0, 80) : token;
  }
}
