import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:pago_app/services/billing_service.dart';
import 'package:pago_app/services/store_ids.dart';
import 'package:pago_app/utils/constants.dart';

/// Loja de teste. [availability] é consumida uma entrada por chamada de
/// `isAvailable` (a última se repete); um `Object` que não é bool é lançado.
class _Store extends Fake implements InAppPurchase {
  _Store({List<Object> availability = const [true]}) : _script = availability;

  final List<Object> _script;
  final updates = StreamController<List<PurchaseDetails>>.broadcast();
  final completed = <PurchaseDetails>[];
  final queried = <Set<String>>[];
  final bought = <PurchaseParam>[];
  var availabilityCalls = 0;
  var restoreCalls = 0;
  var restoreThrows = false;
  var buyResult = true;
  Object? buyThrows;
  Object? queryThrows;
  ProductDetailsResponse response = ProductDetailsResponse(
    productDetails: [_product()],
    notFoundIDs: const [],
  );

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => updates.stream;

  @override
  Future<bool> isAvailable() async {
    final index = availabilityCalls < _script.length
        ? availabilityCalls
        : _script.length - 1;
    availabilityCalls++;
    final step = _script[index];
    if (step is bool) return step;
    throw step;
  }

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async {
    queried.add(identifiers);
    if (queryThrows != null) throw queryThrows!;
    return response;
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    bought.add(purchaseParam);
    if (buyThrows != null) throw buyThrows!;
    return buyResult;
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    restoreCalls++;
    if (restoreThrows) throw StateError('falha de restauração');
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completed.add(purchase);
  }
}

ProductDetails _product({
  String id = AppConstants.premiumProductId,
  String price = 'R\$ 19,90',
  double raw = 19.9,
}) => ProductDetails(
  id: id,
  title: 'Pagô Premium',
  description: 'Mensal',
  price: price,
  rawPrice: raw,
  currencyCode: 'BRL',
);

ProductDetailsResponse _responseWith(
  List<ProductDetails> items, {
  IAPError? error,
}) => ProductDetailsResponse(
  productDetails: items,
  notFoundIDs: const [],
  error: error,
);

PurchaseDetails _purchase({
  String? id = 'order-1',
  String? product,
  PurchaseStatus status = PurchaseStatus.purchased,
  String token = 'token-1',
  bool pending = true,
}) {
  return PurchaseDetails(
    purchaseID: id,
    productID: product ?? AppConstants.premiumProductId,
    verificationData: PurchaseVerificationData(
      localVerificationData: 'local',
      serverVerificationData: token,
      source: 'test',
    ),
    transactionDate: '1',
    status: status,
  )..pendingCompletePurchase = pending;
}

BillingService _billing(
  _Store store, {
  int attempts = 3,
  Duration restoreWait = const Duration(milliseconds: 40),
}) => BillingService(
  store: store,
  prepareAttempts: attempts,
  prepareDelay: Duration.zero,
  restoreWait: restoreWait,
);

Future<void> _flush() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('mensagens de PurchaseUpdate', () {
    test('Google Play sem código não traz linha de código', () {
      final update = PurchaseUpdate.unavailable(StoreKind.googlePlay);
      expect(update.outcome, PurchaseOutcome.unavailable);
      expect(update.message, contains('Google Play'));
      expect(update.message, isNot(contains('Código')));
    });

    test('Google Play com código mostra o motivo no fim', () {
      final update = PurchaseUpdate.unavailable(
        StoreKind.googlePlay,
        code: 'loja-indisponivel',
      );
      expect(update.message, endsWith('Código para o suporte: loja-indisponivel'));
    });

    test('App Store cita a conta Apple e aceita código', () {
      final update = PurchaseUpdate.unavailable(
        StoreKind.appStore,
        code: 'erro-loja: x',
      );
      expect(update.message, contains('App Store'));
      expect(update.message, contains('conta Apple'));
      expect(update.message, contains('erro-loja: x'));
      expect(update.store, StoreKind.appStore);
    });

    test('produto ausente cita a loja certa', () {
      expect(
        PurchaseUpdate.missing(StoreKind.googlePlay).message,
        contains('Google Play'),
      );
      expect(
        PurchaseUpdate.missing(StoreKind.appStore).message,
        contains('App Store'),
      );
      expect(
        PurchaseUpdate.missing(StoreKind.googlePlay).outcome,
        PurchaseOutcome.missing,
      );
    });

    test('nada a restaurar cita a loja e tem o desfecho certo', () {
      final play = PurchaseUpdate.nothingToRestore(StoreKind.googlePlay);
      final apple = PurchaseUpdate.nothingToRestore(StoreKind.appStore);
      expect(play.outcome, PurchaseOutcome.nothingToRestore);
      expect(play.message, contains('Google Play'));
      expect(apple.message, contains('App Store'));
    });

    test('constantes pending e canceled', () {
      expect(PurchaseUpdate.pending.outcome, PurchaseOutcome.pending);
      expect(PurchaseUpdate.canceled.outcome, PurchaseOutcome.canceled);
      expect(PurchaseUpdate.pending.store, StoreKind.googlePlay);
    });
  });

  group('identificadores da loja', () {
    test('produto de cada loja', () {
      expect(
        StoreKind.googlePlay.premiumProductId,
        AppConstants.premiumProductId,
      );
      expect(
        StoreKind.appStore.premiumProductId,
        AppConstants.premiumProductIdIos,
      );
    });

    test('rótulos e dicas de cancelamento', () {
      expect(StoreKind.googlePlay.label, 'Google Play');
      expect(StoreKind.appStore.label, 'App Store');
      expect(StoreKind.googlePlay.cancelHint, contains('Google Play'));
      expect(StoreKind.appStore.cancelHint, contains('iPhone'));
      expect(StoreKind.googlePlay.manageHint, contains('Play Store'));
      expect(StoreKind.appStore.manageHint, contains('Assinaturas'));
    });

    for (final id in [
      AppConstants.premiumProductId,
      AppConstants.premiumProductIdIos,
    ]) {
      test('$id é reconhecido como produto premium', () {
        expect(isPremiumProductId(id), isTrue);
      });
    }

    for (final id in ['', 'outro_produto', 'PAGO_PREMIUM_MONTHLY', 'pago']) {
      test('"$id" não é produto premium', () {
        expect(isPremiumProductId(id), isFalse);
      });
    }

    test('token da App Store é UUID estável por usuário', () {
      final a = appAccountTokenFor('user-1');
      expect(a, appAccountTokenFor('user-1'));
      expect(a, isNot(appAccountTokenFor('user-2')));
      expect(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(a),
        isTrue,
      );
    });

    test('aviso de renovação traz preço, conta e onde cancelar', () {
      final play = premiumRenewalNotice(StoreKind.googlePlay, 'R\$ 19,90');
      final apple = premiumRenewalNotice(StoreKind.appStore, 'R\$ 19,90');
      expect(play, contains('R\$ 19,90'));
      expect(play, contains('conta Google'));
      expect(play, contains('24 horas'));
      expect(apple, contains('conta Apple'));
      expect(apple, contains('Ajustes'));
    });
  });

  group('preparação da loja (nova tentativa e diagnóstico)', () {
    test('disponível de primeira: compra segue e não há espera', () async {
      final store = _Store();
      final billing = _billing(store);
      expect(await billing.buy(userId: 'u1'), same(PurchaseUpdate.pending));
      expect(store.availabilityCalls, 1);
      expect(billing.lastIssue, isNull);
      await billing.dispose();
    });

    test('falha na primeira e ok na segunda: tenta de novo e compra', () async {
      final store = _Store(availability: [false, true]);
      final billing = _billing(store);
      final result = await billing.buy();
      expect(result.outcome, PurchaseOutcome.pending);
      expect(store.availabilityCalls, 2);
      expect(billing.lastIssue, isNull);
      await billing.dispose();
    });

    test('falha duas vezes e ok na terceira', () async {
      final store = _Store(availability: [false, false, true]);
      final billing = _billing(store);
      expect((await billing.buy()).outcome, PurchaseOutcome.pending);
      expect(store.availabilityCalls, 3);
      await billing.dispose();
    });

    test('indisponível sempre: usa todas as tentativas e informa o código', () async {
      final store = _Store(availability: [false]);
      final billing = _billing(store);
      final result = await billing.buy();
      expect(result.outcome, PurchaseOutcome.unavailable);
      expect(store.availabilityCalls, 3);
      expect(result.message, contains('loja-indisponivel'));
      expect(billing.lastIssue, 'loja-indisponivel');
      expect(store.bought, isEmpty);
      await billing.dispose();
    });

    for (final attempts in [1, 2, 4, 5]) {
      test('prepareAttempts=$attempts limita as chamadas', () async {
        final store = _Store(availability: [false]);
        final billing = _billing(store, attempts: attempts);
        await billing.buy();
        expect(store.availabilityCalls, attempts);
        await billing.dispose();
      });
    }

    test('prepareAttempts zero ou negativo vale uma tentativa', () async {
      for (final attempts in [0, -3]) {
        final store = _Store(availability: [false]);
        final billing = _billing(store, attempts: attempts);
        await billing.buy();
        expect(store.availabilityCalls, 1);
        await billing.dispose();
      }
    });

    test('exceção da loja vira código erro-loja e também é repetida', () async {
      final store = _Store(availability: [StateError('serviço desconectado')]);
      final billing = _billing(store);
      final result = await billing.buy();
      expect(result.outcome, PurchaseOutcome.unavailable);
      expect(store.availabilityCalls, 3);
      expect(result.message, contains('erro-loja'));
      expect(result.message, contains('serviço desconectado'));
      await billing.dispose();
    });

    test('exceção seguida de sucesso recupera', () async {
      final store = _Store(availability: [StateError('x'), true]);
      final billing = _billing(store);
      expect((await billing.buy()).outcome, PurchaseOutcome.pending);
      await billing.dispose();
    });

    test('texto longo do erro é cortado em 80 caracteres', () async {
      final store = _Store(availability: [StateError('a' * 300)]);
      final billing = _billing(store, attempts: 1);
      await billing.buy();
      final issue = billing.lastIssue!;
      expect(issue.startsWith('erro-loja: '), isTrue);
      expect(issue.length, lessThanOrEqualTo('erro-loja: '.length + 80));
      await billing.dispose();
    });

    test('quebras de linha do erro viram espaço', () async {
      final store = _Store(availability: [StateError('linha1\n\n   linha2')]);
      final billing = _billing(store, attempts: 1);
      await billing.buy();
      expect(billing.lastIssue, contains('linha1 linha2'));
      await billing.dispose();
    });

    test('lastIssue limpa depois de uma preparação bem-sucedida', () async {
      final store = _Store(availability: [false, false, false, true]);
      final billing = _billing(store);
      await billing.buy();
      expect(billing.lastIssue, 'loja-indisponivel');
      await billing.buy();
      expect(billing.lastIssue, isNull);
      await billing.dispose();
    });
  });

  group('compra', () {
    test('consulta exatamente o produto da loja', () async {
      final store = _Store();
      final billing = _billing(store);
      await billing.buy();
      expect(store.queried.single, {AppConstants.premiumProductId});
      expect(billing.productId, AppConstants.premiumProductId);
      await billing.dispose();
    });

    test('envia o usuário como applicationUserName', () async {
      final store = _Store();
      final billing = _billing(store);
      await billing.buy(userId: 'uid-123');
      expect(store.bought.single.applicationUserName, 'uid-123');
      expect(store.bought.single.productDetails.id, AppConstants.premiumProductId);
      await billing.dispose();
    });

    test('sem usuário não manda applicationUserName', () async {
      final store = _Store();
      final billing = _billing(store);
      await billing.buy();
      expect(store.bought.single.applicationUserName, isNull);
      await billing.dispose();
    });

    test('guarda preço e moeda do produto da loja', () async {
      final store = _Store();
      final billing = _billing(store);
      expect(billing.price, isNull);
      expect(billing.currency, isNull);
      await billing.buy();
      expect(billing.price, 19.9);
      expect(billing.currency, 'BRL');
      await billing.dispose();
    });

    test('produto ausente na loja → missing, sem abrir compra', () async {
      final store = _Store()..response = _responseWith(const []);
      final billing = _billing(store);
      final result = await billing.buy();
      expect(result.outcome, PurchaseOutcome.missing);
      expect(store.bought, isEmpty);
      await billing.dispose();
    });

    test('erro na consulta → unavailable com código da loja', () async {
      final store = _Store()
        ..response = _responseWith(
          const [],
          error: IAPError(
            source: 'google_play',
            code: 'BillingResponse.billingUnavailable',
            message: 'Billing unavailable',
          ),
        );
      final billing = _billing(store);
      final result = await billing.buy();
      expect(result.outcome, PurchaseOutcome.unavailable);
      expect(result.message, contains('consulta'));
      expect(result.message, contains('billingUnavailable'));
      expect(store.bought, isEmpty);
      await billing.dispose();
    });

    test('erro na consulta é registrado em lastIssue', () async {
      final store = _Store()
        ..response = _responseWith(
          [_product()],
          error: IAPError(source: 's', code: 'c', message: 'm'),
        );
      final billing = _billing(store);
      await billing.buy();
      expect(billing.lastIssue, startsWith('consulta c: m'));
      await billing.dispose();
    });

    test('loja recusa iniciar a compra → error', () async {
      final store = _Store()..buyResult = false;
      final billing = _billing(store);
      final result = await billing.buy();
      expect(result.outcome, PurchaseOutcome.error);
      expect(result.message, contains('não iniciou'));
      await billing.dispose();
    });

    test('exceção ao comprar vira mensagem de erro', () async {
      final store = _Store()..buyThrows = StateError('boom');
      final billing = _billing(store);
      final result = await billing.buy();
      expect(result.outcome, PurchaseOutcome.error);
      expect(result.message, contains('boom'));
      await billing.dispose();
    });

    test('exceção ao consultar vira mensagem de erro', () async {
      final store = _Store()..queryThrows = StateError('sem rede');
      final billing = _billing(store);
      final result = await billing.buy();
      expect(result.outcome, PurchaseOutcome.error);
      expect(result.message, contains('sem rede'));
      await billing.dispose();
    });

    test('a loja do teste é a Google Play', () {
      final billing = _billing(_Store());
      expect(billing.store, StoreKind.googlePlay);
    });
  });

  group('preço da loja', () {
    test('devolve o preço como a loja mostra', () async {
      final store = _Store()
        ..response = _responseWith([_product(price: 'R\$ 21,90', raw: 21.9)]);
      final billing = _billing(store);
      expect(await billing.priceLabel(), 'R\$ 21,90');
      await billing.dispose();
    });

    test('segunda chamada usa o cache', () async {
      final store = _Store();
      final billing = _billing(store);
      await billing.priceLabel();
      await billing.priceLabel();
      expect(store.queried, hasLength(1));
      await billing.dispose();
    });

    test('loja indisponível → null', () async {
      final store = _Store(availability: [false]);
      final billing = _billing(store, attempts: 1);
      expect(await billing.priceLabel(), isNull);
      await billing.dispose();
    });

    test('sem produto → null', () async {
      final store = _Store()..response = _responseWith(const []);
      final billing = _billing(store);
      expect(await billing.priceLabel(), isNull);
      await billing.dispose();
    });

    test('exceção na consulta → null', () async {
      final store = _Store()..queryThrows = StateError('x');
      final billing = _billing(store);
      expect(await billing.priceLabel(), isNull);
      await billing.dispose();
    });
  });

  group('restauração', () {
    test('loja indisponível não chama restorePurchases', () async {
      final store = _Store(availability: [false]);
      final billing = _billing(store, attempts: 2);
      final result = await billing.restorePurchases();
      expect(result.outcome, PurchaseOutcome.unavailable);
      expect(store.restoreCalls, 0);
      expect(store.availabilityCalls, 2);
      await billing.dispose();
    });

    test('indisponível na primeira e ok depois: restaura', () async {
      final store = _Store(availability: [false, true]);
      final billing = _billing(store);
      final future = billing.restorePurchases();
      await _flush();
      store.updates.add([_purchase(status: PurchaseStatus.restored)]);
      billing.onUpdate = (_) async {};
      final result = await future;
      expect(store.restoreCalls, 1);
      expect(result.outcome, anyOf(PurchaseOutcome.pending, PurchaseOutcome.restored));
      await billing.dispose();
    });

    test('falha da loja ao restaurar → error', () async {
      final store = _Store()..restoreThrows = true;
      final billing = _billing(store);
      final result = await billing.restorePurchases();
      expect(result.outcome, PurchaseOutcome.error);
      expect(result.message, contains('restaurar'));
      await billing.dispose();
    });

    test('sem resposta da loja → pending, não "sem assinatura"', () async {
      final store = _Store();
      final billing = _billing(store, restoreWait: const Duration(milliseconds: 15));
      final result = await billing.restorePurchases();
      expect(result.outcome, PurchaseOutcome.pending);
      expect(result.message, contains('não significa'));
      await billing.dispose();
    });

    test('duas chamadas juntas dividem a mesma tentativa', () async {
      final store = _Store();
      final billing = _billing(store, restoreWait: const Duration(milliseconds: 15));
      await Future.wait([billing.restorePurchases(), billing.restorePurchases()]);
      expect(store.restoreCalls, 1);
      await billing.dispose();
    });

    test('depois de terminar, nova restauração é nova tentativa', () async {
      final store = _Store();
      final billing = _billing(store, restoreWait: const Duration(milliseconds: 10));
      await billing.restorePurchases();
      await billing.restorePurchases();
      expect(store.restoreCalls, 2);
      await billing.dispose();
    });
  });

  group('fluxo de compras recebidas', () {
    test('compra vira desfecho purchased com id e token', () async {
      final store = _Store();
      final billing = _billing(store);
      final seen = <PurchaseUpdate>[];
      billing.onUpdate = (u) async => seen.add(u);
      await billing.start();
      store.updates.add([_purchase()]);
      await _flush();
      expect(seen.single.outcome, PurchaseOutcome.purchased);
      expect(seen.single.transactionId, 'order-1');
      expect(seen.single.purchaseToken, 'token-1');
      expect(store.completed, hasLength(1));
      await billing.dispose();
    });

    test('compra restaurada vira desfecho restored', () async {
      final store = _Store();
      final billing = _billing(store);
      final seen = <PurchaseUpdate>[];
      billing.onUpdate = (u) async => seen.add(u);
      await billing.start();
      store.updates.add([_purchase(status: PurchaseStatus.restored)]);
      await _flush();
      expect(seen.single.outcome, PurchaseOutcome.restored);
      await billing.dispose();
    });

    test('compra pendente não conclui na loja', () async {
      final store = _Store();
      final billing = _billing(store);
      final seen = <PurchaseUpdate>[];
      billing.onUpdate = (u) async => seen.add(u);
      await billing.start();
      store.updates.add([_purchase(status: PurchaseStatus.pending)]);
      await _flush();
      expect(seen.single.outcome, PurchaseOutcome.pending);
      expect(store.completed, isEmpty);
      await billing.dispose();
    });

    test('compra cancelada avisa a interface', () async {
      final store = _Store();
      final billing = _billing(store);
      final seen = <PurchaseUpdate>[];
      billing.onUpdate = (u) async => seen.add(u);
      await billing.start();
      store.updates.add([_purchase(status: PurchaseStatus.canceled)]);
      await _flush();
      expect(seen.single.outcome, PurchaseOutcome.canceled);
      await billing.dispose();
    });

    test('erro da loja usa a mensagem dela', () async {
      final store = _Store();
      final billing = _billing(store);
      final seen = <PurchaseUpdate>[];
      billing.onUpdate = (u) async => seen.add(u);
      await billing.start();
      store.updates.add([
        _purchase(status: PurchaseStatus.error)
          ..error = IAPError(source: 's', code: 'c', message: 'Pagamento recusado'),
      ]);
      await _flush();
      expect(seen.single.outcome, PurchaseOutcome.error);
      expect(seen.single.message, 'Pagamento recusado');
      await billing.dispose();
    });

    test('erro sem mensagem usa o texto padrão', () async {
      final store = _Store();
      final billing = _billing(store);
      final seen = <PurchaseUpdate>[];
      billing.onUpdate = (u) async => seen.add(u);
      await billing.start();
      store.updates.add([_purchase(status: PurchaseStatus.error)]);
      await _flush();
      expect(seen.single.message, 'A compra não foi concluída.');
      await billing.dispose();
    });

    test('sem callback a compra não é concluída', () async {
      final store = _Store();
      final billing = _billing(store);
      await billing.start();
      store.updates.add([_purchase()]);
      await _flush();
      expect(store.completed, isEmpty);
      await billing.dispose();
    });

    test('compra sem pendingCompletePurchase não chama completePurchase', () async {
      final store = _Store();
      final billing = _billing(store);
      billing.onUpdate = (_) async {};
      await billing.start();
      store.updates.add([_purchase(pending: false)]);
      await _flush();
      expect(store.completed, isEmpty);
      await billing.dispose();
    });

    test('id vazio cai no token do servidor', () async {
      final store = _Store();
      final billing = _billing(store);
      final seen = <PurchaseUpdate>[];
      billing.onUpdate = (u) async => seen.add(u);
      await billing.start();
      store.updates.add([_purchase(id: '', token: 'tok-xyz')]);
      await _flush();
      expect(seen.single.transactionId, 'tok-xyz');
      await billing.dispose();
    });

    test('id ausente e token enorme é cortado em 80', () async {
      final store = _Store();
      final billing = _billing(store);
      final seen = <PurchaseUpdate>[];
      billing.onUpdate = (u) async => seen.add(u);
      await billing.start();
      store.updates.add([_purchase(id: null, token: 't' * 200)]);
      await _flush();
      expect(seen.single.transactionId, hasLength(80));
      expect(seen.single.purchaseToken, hasLength(200));
      await billing.dispose();
    });

    test('sem id nem token os dois ficam nulos', () async {
      final store = _Store();
      final billing = _billing(store);
      final seen = <PurchaseUpdate>[];
      billing.onUpdate = (u) async => seen.add(u);
      await billing.start();
      store.updates.add([_purchase(id: null, token: '')]);
      await _flush();
      expect(seen.single.transactionId, isNull);
      expect(seen.single.purchaseToken, isNull);
      await billing.dispose();
    });

    test('produto de outra loja é ignorado por completo', () async {
      final store = _Store();
      final billing = _billing(store);
      final seen = <PurchaseUpdate>[];
      billing.onUpdate = (u) async => seen.add(u);
      await billing.start();
      store.updates.add([_purchase(product: 'outro')]);
      await _flush();
      expect(seen, isEmpty);
      expect(store.completed, isEmpty);
      await billing.dispose();
    });

    test('lista com várias compras é processada em ordem', () async {
      final store = _Store();
      final billing = _billing(store);
      final seen = <String?>[];
      billing.onUpdate = (u) async => seen.add(u.transactionId);
      await billing.start();
      store.updates.add([_purchase(id: 'a'), _purchase(id: 'b'), _purchase(id: 'c')]);
      await _flush();
      expect(seen, ['a', 'b', 'c']);
      expect(store.completed, hasLength(3));
      await billing.dispose();
    });

    test('callback que falha na pendente não derruba o fluxo', () async {
      final store = _Store();
      final billing = _billing(store);
      final seen = <PurchaseOutcome>[];
      billing.onUpdate = (u) async {
        seen.add(u.outcome);
        if (u.outcome == PurchaseOutcome.pending) throw StateError('ui caiu');
      };
      await billing.start();
      store.updates.add([_purchase(status: PurchaseStatus.pending)]);
      await _flush();
      store.updates.add([_purchase()]);
      await _flush();
      expect(seen, contains(PurchaseOutcome.purchased));
      expect(store.completed, hasLength(1));
      await billing.dispose();
    });

    test('erro no fluxo da loja avisa e permite restaurar depois', () async {
      final store = _Store();
      final billing = _billing(store);
      final seen = <PurchaseUpdate>[];
      billing.onUpdate = (u) async => seen.add(u);
      await billing.start();
      store.updates.addError(StateError('stream quebrou'));
      await _flush();
      expect(seen.single.outcome, PurchaseOutcome.error);
      expect(seen.single.message, contains('restaurar'));
      await billing.dispose();
    });
  });

  group('ciclo de vida', () {
    test('start é idempotente: escuta o fluxo uma vez só', () async {
      var listeners = 0;
      final controller = StreamController<List<PurchaseDetails>>.broadcast(
        onListen: () => listeners++,
      );
      final store = _CountingStore(controller);
      final billing = _billing(store);
      await billing.start();
      await billing.start();
      await billing.start();
      expect(listeners, 1);
      await billing.dispose();
      await controller.close();
    });

    test('dispose para de ouvir as compras', () async {
      final store = _Store();
      final billing = _billing(store);
      final seen = <PurchaseUpdate>[];
      billing.onUpdate = (u) async => seen.add(u);
      await billing.start();
      await billing.dispose();
      store.updates.add([_purchase()]);
      await _flush();
      expect(seen, isEmpty);
    });

    test('dispose durante restauração a encerra como pendente', () async {
      final store = _Store();
      final billing = _billing(store, restoreWait: const Duration(seconds: 5));
      final future = billing.restorePurchases();
      await _flush();
      await billing.dispose();
      final result = await future;
      expect(result.outcome, PurchaseOutcome.pending);
      expect(result.message, contains('interrompida'));
    });

    test('pode reiniciar depois de dispose', () async {
      final store = _Store();
      final billing = _billing(store);
      final seen = <PurchaseUpdate>[];
      billing.onUpdate = (u) async => seen.add(u);
      await billing.start();
      await billing.dispose();
      await billing.start();
      store.updates.add([_purchase()]);
      await _flush();
      expect(seen, hasLength(1));
      await billing.dispose();
    });
  });
}

class _CountingStore extends _Store {
  _CountingStore(this._controller);

  final StreamController<List<PurchaseDetails>> _controller;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _controller.stream;
}
