import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'billing_purchase_stub.dart'
    if (dart.library.io) 'billing_purchase_io.dart' as purchase;
import 'store_ids.dart';

enum PurchaseOutcome {
  pending,
  purchased,
  restored,
  nothingToRestore,
  canceled,
  unavailable,
  missing,
  error,
}

class PurchaseUpdate {
  const PurchaseUpdate({
    required this.outcome,
    this.message,
    this.transactionId,
    this.purchaseToken,
    this.store = StoreKind.googlePlay,
  });

  final PurchaseOutcome outcome;
  final String? message;
  final String? transactionId;

  /// Google Play: token da compra. App Store (StoreKit 2): transação assinada (JWS).
  final String? purchaseToken;
  final StoreKind store;

  static const pending = PurchaseUpdate(outcome: PurchaseOutcome.pending);
  static const canceled = PurchaseUpdate(outcome: PurchaseOutcome.canceled);

  static PurchaseUpdate unavailable(StoreKind store) => PurchaseUpdate(
        outcome: PurchaseOutcome.unavailable,
        store: store,
        message: 'A ${store.label} não está disponível neste aparelho.',
      );

  static PurchaseUpdate missing(StoreKind store) => PurchaseUpdate(
        outcome: PurchaseOutcome.missing,
        store: store,
        message:
            'O plano ${store.premiumProductId} ainda não está publicado na ${store.label}.',
      );

  static PurchaseUpdate nothingToRestore(StoreKind store) => PurchaseUpdate(
        outcome: PurchaseOutcome.nothingToRestore,
        store: store,
        message: 'Nenhuma assinatura ativa encontrada nesta conta da ${store.label}.',
      );
}

class BillingService {
  BillingService({InAppPurchase? store}) : _store = store ?? InAppPurchase.instance;

  static const restoreTimeout = Duration(seconds: 12);

  final InAppPurchase _store;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  Future<void> Function(PurchaseUpdate update)? onUpdate;
  Completer<PurchaseUpdate>? _restoring;
  ProductDetails? _product;
  var _started = false;

  StoreKind get store => purchase.currentStore();

  String get productId => store.premiumProductId;

  double? get price => _product?.rawPrice;

  String? get currency => _product?.currencyCode;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _subscription = _store.purchaseStream.listen(
      _onPurchases,
      onError: (Object error) {
        onUpdate?.call(
          PurchaseUpdate(
            outcome: PurchaseOutcome.error,
            store: store,
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

  /// Preço como a loja mostra (moeda e impostos do país da conta).
  Future<String?> priceLabel() async {
    if (_product != null) return _product!.price;
    if (await _prepare() != null) return null;
    try {
      final response = await _store.queryProductDetails({productId});
      if (response.productDetails.isEmpty) return null;
      return (_product = response.productDetails.first).price;
    } catch (error) {
      debugPrint('Preço da loja indisponível: $error');
      return null;
    }
  }

  Future<PurchaseUpdate> buy({String? userId}) async {
    final ready = await _prepare();
    if (ready != null) return ready;
    try {
      final response = await _store.queryProductDetails({productId});
      if (response.productDetails.isEmpty) return PurchaseUpdate.missing(store);
      _product = response.productDetails.first;
      final started = await _store.buyNonConsumable(
        purchaseParam: purchase.buildPurchaseParam(
          _product!,
          userId: userId,
        ),
      );
      if (!started) {
        return PurchaseUpdate(
          outcome: PurchaseOutcome.error,
          store: store,
          message: 'A loja não iniciou a compra.',
        );
      }
      return PurchaseUpdate.pending;
    } catch (error) {
      return PurchaseUpdate(
        outcome: PurchaseOutcome.error,
        store: store,
        message: 'Não foi possível abrir a compra: $error',
      );
    }
  }

  /// Restaurar Compras (exigido pela Apple): pede à loja as assinaturas da
  /// conta e espera a resposta. A loja não avisa quando não há nada, por isso
  /// o tempo limite vira "nada para restaurar".
  Future<PurchaseUpdate> restorePurchases() async {
    final ready = await _prepare();
    if (ready != null) return ready;
    final pending = _restoring;
    if (pending != null) return pending.future;
    final completer = _restoring = Completer<PurchaseUpdate>();
    try {
      await _store.restorePurchases();
      return await completer.future.timeout(
        restoreTimeout,
        onTimeout: () => PurchaseUpdate.nothingToRestore(store),
      );
    } catch (error) {
      return PurchaseUpdate(
        outcome: PurchaseOutcome.error,
        store: store,
        message: 'Não foi possível restaurar a compra: $error',
      );
    } finally {
      _restoring = null;
    }
  }

  Future<PurchaseUpdate?> _prepare() async {
    await start();
    try {
      final available = await _store.isAvailable();
      if (!available) return PurchaseUpdate.unavailable(store);
    } catch (error) {
      debugPrint('Loja indisponível: $error');
      return PurchaseUpdate.unavailable(store);
    }
    return null;
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final item in purchases) {
      if (!isPremiumProductId(item.productID)) {
        if (item.pendingCompletePurchase) {
          await _store.completePurchase(item);
        }
        continue;
      }
      switch (item.status) {
        case PurchaseStatus.pending:
          await onUpdate?.call(PurchaseUpdate.pending);
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (item.pendingCompletePurchase) {
            await _store.completePurchase(item);
          }
          final update = PurchaseUpdate(
            outcome: item.status == PurchaseStatus.purchased
                ? PurchaseOutcome.purchased
                : PurchaseOutcome.restored,
            store: store,
            transactionId: _transactionId(item),
            purchaseToken: _purchaseToken(item),
          );
          final restoring = _restoring;
          if (restoring != null && !restoring.isCompleted) {
            restoring.complete(update);
          } else {
            await onUpdate?.call(update);
          }
        case PurchaseStatus.canceled:
          await onUpdate?.call(PurchaseUpdate.canceled);
        case PurchaseStatus.error:
          await onUpdate?.call(
            PurchaseUpdate(
              outcome: PurchaseOutcome.error,
              store: store,
              message: item.error?.message ?? 'A compra não foi concluída.',
            ),
          );
      }
    }
  }

  String? _transactionId(PurchaseDetails item) {
    final id = item.purchaseID;
    if (id != null && id.isNotEmpty) return id;
    final token = item.verificationData.serverVerificationData;
    if (token.isEmpty) return null;
    return token.length > 80 ? token.substring(0, 80) : token;
  }

  String? _purchaseToken(PurchaseDetails item) {
    final token = item.verificationData.serverVerificationData;
    return token.isEmpty ? null : token;
  }
}
