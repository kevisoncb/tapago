import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pago_app/services/billing_service.dart';
import 'package:pago_app/services/reminder_service.dart';
import 'package:pago_app/services/session_gate.dart';
import 'package:pago_app/utils/constants.dart';

class _Store extends Fake implements InAppPurchase {
  final updates = StreamController<List<PurchaseDetails>>.broadcast();
  final completed = <PurchaseDetails>[];
  int restoreCalls = 0;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => updates.stream;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    restoreCalls++;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completed.add(purchase);
  }
}

PurchaseDetails _purchase({
  String? product,
  PurchaseStatus status = PurchaseStatus.purchased,
}) {
  return PurchaseDetails(
    purchaseID: 'order-test',
    productID: product ?? AppConstants.premiumProductId,
    verificationData: PurchaseVerificationData(
      localVerificationData: 'local-test',
      serverVerificationData: 'server-test',
      source: 'test',
    ),
    transactionDate: '1',
    status: status,
  )..pendingCompletePurchase = true;
}

Future<void> _flush() => Future<void>.delayed(const Duration(milliseconds: 15));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('produção não cria conta local quando Firebase não inicia', () async {
    SharedPreferences.setMockInitialValues({});
    final gate = SessionGate(
      initializeFirebase: () async => false,
      allowLocalAccounts: false,
    );
    await gate.bootstrap();
    expect(gate.booting, isFalse);
    expect(gate.bootError, SessionGate.unavailableMessage);
    expect(gate.repository, isNull);
    expect(
      await gate.signIn(email: 'loja@example.com', password: '123456'),
      SessionGate.unavailableMessage,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), isEmpty);
    gate.dispose();
  });

  test(
    'recuperação valida formato e não promete e-mail em conta local',
    () async {
      SharedPreferences.setMockInitialValues({});
      final gate = SessionGate(initializeFirebase: () async => false);
      await gate.bootstrap();
      expect(
        await gate.sendPasswordReset('sem-email'),
        'Informe um e-mail válido.',
      );
      expect(
        await gate.sendPasswordReset('teste@example.com'),
        contains('contas sincronizadas'),
      );
      gate.dispose();
    },
  );

  test(
    'notificação aceita payload legado e confere proprietário quando presente',
    () {
      final old = ReminderTarget.parse('hoje|debt-1');
      expect(old?.id, 'debt-1');
      expect(old?.isBill, isFalse);
      expect(old?.userId, isNull);
      final bill = ReminderTarget.parse('boleto|bill-1|owner-1');
      expect(bill?.isBill, isTrue);
      expect(bill?.userId, 'owner-1');
      expect(ReminderTarget.parse('unknown|debt-1'), isNull);
      expect(ReminderTarget.parse('hoje|'), isNull);
      expect(ReminderTarget.parse('hoje|a/b'), isNull);
    },
  );

  test('compra só é concluída depois da validação', () async {
    final store = _Store();
    final billing = BillingService(store: store);
    final validating = Completer<void>();
    final entered = Completer<void>();
    billing.onUpdate = (update) async {
      if (update.outcome == PurchaseOutcome.purchased) {
        entered.complete();
        await validating.future;
      }
    };
    await billing.start();
    store.updates.add([_purchase()]);
    await entered.future;
    expect(store.completed, isEmpty);
    validating.complete();
    await _flush();
    expect(store.completed, hasLength(1));
    await billing.dispose();
    await store.updates.close();
  });

  test(
    'falha de validação mantém compra pendente e permite nova tentativa',
    () async {
      final store = _Store();
      final billing = BillingService(store: store);
      var failures = true;
      final outcomes = <PurchaseOutcome>[];
      billing.onUpdate = (update) async {
        outcomes.add(update.outcome);
        if (update.outcome == PurchaseOutcome.purchased && failures) {
          throw StateError('backend temporariamente indisponível');
        }
      };
      await billing.start();
      store.updates.add([_purchase()]);
      await _flush();
      expect(store.completed, isEmpty);
      expect(outcomes, contains(PurchaseOutcome.error));
      failures = false;
      store.updates.add([_purchase()]);
      await _flush();
      expect(store.completed, hasLength(1));
      await billing.dispose();
      await store.updates.close();
    },
  );

  test('restauração só termina após validação e conclusão', () async {
    final store = _Store();
    final billing = BillingService(store: store);
    final validating = Completer<void>();
    billing.onUpdate = (update) async {
      if (update.outcome == PurchaseOutcome.restored) await validating.future;
    };
    final result = billing.restorePurchases();
    await _flush();
    store.updates.add([_purchase(status: PurchaseStatus.restored)]);
    await _flush();
    expect(store.completed, isEmpty);
    validating.complete();
    expect((await result).outcome, PurchaseOutcome.restored);
    expect(store.completed, hasLength(1));
    await billing.dispose();
    await store.updates.close();
  });

  test(
    'timeout de restauração é indeterminado e chamadas compartilham tentativa',
    () async {
      final store = _Store();
      final billing = BillingService(
        store: store,
        restoreWait: const Duration(milliseconds: 20),
      );
      final one = billing.restorePurchases();
      final two = billing.restorePurchases();
      final results = await Future.wait([one, two]);
      expect(store.restoreCalls, 1);
      expect(
        results.every((r) => r.outcome == PurchaseOutcome.pending),
        isTrue,
      );
      expect(results.first.message, contains('não significa'));
      await billing.dispose();
      await store.updates.close();
    },
  );

  test('produto não administrado não é concluído por este serviço', () async {
    final store = _Store();
    final billing = BillingService(store: store);
    billing.onUpdate = (_) async {};
    await billing.start();
    store.updates.add([_purchase(product: 'outro_produto')]);
    await _flush();
    expect(store.completed, isEmpty);
    await billing.dispose();
    await store.updates.close();
  });
}
