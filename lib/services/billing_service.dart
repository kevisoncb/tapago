import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'billing_purchase_stub.dart'
    if (dart.library.io) 'billing_purchase_io.dart'
    as purchase;
import 'crash_reporter.dart';
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

  /// [code] é o motivo técnico da falha; vai no fim da mensagem para o
  /// suporte saber o que a loja respondeu.
  static PurchaseUpdate unavailable(StoreKind store, {String? code}) =>
      PurchaseUpdate(
        outcome: PurchaseOutcome.unavailable,
        store: store,
        message:
            (store == StoreKind.googlePlay
                ? 'Não foi possível conectar à Google Play para assinar. Confira se o Pagô foi instalado pela Google Play, se a Play Store está atualizada e se há uma conta Google ativa no aparelho.'
                : 'Não foi possível conectar à App Store para assinar. Confira a conexão e a sua conta Apple e tente de novo.') +
            (code == null ? '' : '\n\nCódigo para o suporte: $code'),
      );

  static PurchaseUpdate missing(StoreKind store) => PurchaseUpdate(
    outcome: PurchaseOutcome.missing,
    store: store,
    message:
        'A assinatura não está disponível nesta conta da ${store.label} agora. Tente novamente mais tarde.',
  );

  static PurchaseUpdate nothingToRestore(StoreKind store) => PurchaseUpdate(
    outcome: PurchaseOutcome.nothingToRestore,
    store: store,
    message:
        'Nenhuma assinatura ativa encontrada nesta conta da ${store.label}.',
  );
}

class BillingService {
  BillingService({
    InAppPurchase? store,
    this.restoreWait = restoreTimeout,
    this.prepareAttempts = 3,
    this.prepareDelay = const Duration(milliseconds: 900),
  }) : _store = store ?? InAppPurchase.instance,
      _supported =
          store != null ||
          (!kIsWeb &&
              (defaultTargetPlatform == TargetPlatform.android ||
                  defaultTargetPlatform == TargetPlatform.iOS));

  static const restoreTimeout = Duration(seconds: 12);

  final InAppPurchase _store;
  final bool _supported;
  final Duration restoreWait;

  /// A primeira conexão com a Play costuma falhar quando o serviço da loja
  /// ainda está acordando; por isso a preparação tenta de novo antes de
  /// desistir (espera [prepareDelay], depois o dobro, e assim por diante).
  final int prepareAttempts;
  final Duration prepareDelay;
  String? _issue;
  Future<void> _purchaseWork = Future.value();
  Future<PurchaseUpdate>? _restoreRequest;
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
    if (_started || !_supported) return;
    _started = true;
    _subscription = _store.purchaseStream.listen(
      (items) {
        _purchaseWork = _purchaseWork.then((_) => _onPurchases(items));
      },
      onError: (Object error) {
        unawaited(
          _reportError(
            'Não foi possível acompanhar a compra. Tente restaurar quando a conexão voltar.',
          ),
        );
      },
    );
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _started = false;
    final restoring = _restoring;
    if (restoring != null && !restoring.isCompleted) {
      restoring.complete(
        PurchaseUpdate(
          outcome: PurchaseOutcome.pending,
          store: store,
          message: 'A restauração foi interrompida. Tente novamente ao entrar na conta.',
        ),
      );
    }
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
      final failure = _queryFailure(response);
      if (failure != null) return failure;
      if (response.productDetails.isEmpty) return PurchaseUpdate.missing(store);
      _product = response.productDetails.first;
      final started = await _store.buyNonConsumable(
        purchaseParam: purchase.buildPurchaseParam(_product!, userId: userId),
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

  /// A loja pode não responder quando não há compras. Um timeout significa
  /// resultado ainda desconhecido, não prova ausência de assinatura.
  Future<PurchaseUpdate> restorePurchases() {
    return _restoreRequest ??= _restore().whenComplete(() {
      _restoreRequest = null;
    });
  }

  Future<PurchaseUpdate> _restore() async {
    final ready = await _prepare();
    if (ready != null) return ready;
    final completer = _restoring = Completer<PurchaseUpdate>();
    try {
      await _store.restorePurchases();
      return await completer.future.timeout(
        restoreWait,
        onTimeout: () => PurchaseUpdate(
          outcome: PurchaseOutcome.pending,
          store: store,
          message: 'A loja ainda não confirmou a restauração. Aguarde ou tente novamente; isso não significa que você não tem assinatura.',
        ),
      );
    } catch (_) {
      return PurchaseUpdate(
        outcome: PurchaseOutcome.error,
        store: store,
        message: 'Não foi possível restaurar a compra. Confira a conexão e tente novamente.',
      );
    } finally {
      _restoring = null;
    }
  }

  /// Último motivo técnico de falha ao falar com a loja (null quando ok).
  String? get lastIssue => _issue;

  Future<PurchaseUpdate?> _prepare() async {
    if (!_supported) {
      _issue = 'plataforma-sem-loja';
      return PurchaseUpdate.unavailable(store, code: _issue);
    }
    final attempts = prepareAttempts < 1 ? 1 : prepareAttempts;
    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        await start();
        if (await _store.isAvailable()) {
          _issue = null;
          return null;
        }
        _issue = 'loja-indisponivel';
      } catch (error) {
        debugPrint('Loja indisponível: $error');
        final text = '$error'.replaceAll(RegExp(r'\s+'), ' ').trim();
        _issue =
            'erro-loja: ${text.length > 80 ? text.substring(0, 80) : text}';
      }
      if (attempt < attempts) await Future<void>.delayed(prepareDelay * attempt);
    }
    unawaited(CrashReporter.recordIssue('Cobrança: $_issue'));
    return PurchaseUpdate.unavailable(store, code: _issue);
  }

  /// Falha ao consultar o produto: a loja respondeu com erro (não é produto
  /// ausente) e o código dela ajuda a achar a causa.
  PurchaseUpdate? _queryFailure(ProductDetailsResponse response) {
    final error = response.error;
    if (error == null) return null;
    final text = '${error.code}: ${error.message}'
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    _issue = 'consulta ${text.length > 80 ? text.substring(0, 80) : text}';
    unawaited(CrashReporter.recordIssue('Cobrança: $_issue'));
    return PurchaseUpdate.unavailable(store, code: _issue);
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final item in purchases) {
      // Não concluir compras de produtos que este serviço não administra.
      if (item.productID != productId) continue;
      try {
        switch (item.status) {
          case PurchaseStatus.pending:
            await onUpdate?.call(PurchaseUpdate.pending);
          case PurchaseStatus.purchased:
          case PurchaseStatus.restored:
            final update = PurchaseUpdate(
              outcome: item.status == PurchaseStatus.purchased
                  ? PurchaseOutcome.purchased
                  : PurchaseOutcome.restored,
              store: store,
              transactionId: _transactionId(item),
              purchaseToken: _purchaseToken(item),
            );
            final validate = onUpdate;
            if (validate == null) continue;
            // O callback só retorna com sucesso quando o backend confirmou e
            // o direito está carregado. Falha mantém a compra pendente na loja.
            await validate(update);
            if (item.pendingCompletePurchase) {
              await _store.completePurchase(item);
            }
            _finishRestore(update);
          case PurchaseStatus.canceled:
            _finishRestore(PurchaseUpdate.canceled);
            await onUpdate?.call(PurchaseUpdate.canceled);
          case PurchaseStatus.error:
            await _reportError(
              item.error?.message ?? 'A compra não foi concluída.',
            );
        }
      } catch (_) {
        await _reportError(
          'A compra ainda não foi confirmada no Pagô. Confira a conexão e use Restaurar Compras para tentar novamente.',
        );
      }
    }
  }

  void _finishRestore(PurchaseUpdate update) {
    final restoring = _restoring;
    if (restoring != null && !restoring.isCompleted) restoring.complete(update);
  }

  Future<void> _reportError(String message) async {
    final update = PurchaseUpdate(
      outcome: PurchaseOutcome.error,
      store: store,
      message: message,
    );
    _finishRestore(update);
    try {
      await onUpdate?.call(update);
    } catch (_) {
      // Erro de UI/callback não deve encerrar o processamento do stream.
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
