import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pago_app/models/models.dart';
import 'package:pago_app/services/app_repository.dart';
import 'package:pago_app/services/cached_repository.dart';
import 'package:pago_app/services/local_repository.dart';
import 'package:pago_app/state/app_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servidor que só responde quando o teste manda.
class SlowRemote extends Fake implements AppRepository {
  final user = Completer<AppUser>();
  final debts = Completer<List<Debt>>();
  final payments = Completer<List<Payment>>();
  final bills = Completer<List<Bill>>();
  final asked = <String>[];
  bool never = false;

  @override
  bool get usesFirestore => true;

  Future<T> _wait<T>(String name, Completer<T> answer) {
    asked.add(name);
    return never ? Completer<T>().future : answer.future;
  }

  @override
  Future<AppUser> getCurrentUser() => _wait('user', user);

  @override
  Stream<AppUser>? watchCurrentUser() => null;

  @override
  Future<List<Debt>> getDebts() => _wait('debts', debts);

  @override
  Future<List<Payment>> getPayments({String? debtId}) =>
      _wait('payments', payments);

  @override
  Future<List<Bill>> getBills() => _wait('bills', bills);
}

Debt _debt(String id, String nome) => Debt(
  id: id,
  userId: 'u',
  nome: nome,
  telefone: '',
  valorPrincipal: 100,
  taxaJuros: 0,
  dataVencimento: DateTime(2026, 11, 20),
  statusPago: false,
  clientScore: 80,
);

AppUser _user(String nome) => AppUser(
  id: 'u',
  nome: nome,
  email: 'loja@example.com',
  isPremium: false,
  chavePix: '',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocalRepository cache;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    cache = LocalRepository(userId: 'u');
    await cache.init();
  });

  test('abre com o que está salvo e troca pelo servidor quando chega', () async {
    await cache.saveUser(_user('Loja salva'));
    await cache.upsertDebt(_debt('d1', 'Cliente salvo'));
    final remote = SlowRemote();
    final controller = AppController(
      CachedRepository(remote: remote, cache: cache),
    );

    final load = controller.load();
    await pumpEventQueue();
    // Antes de a internet responder, a tela já tem os dados do aparelho.
    expect(controller.user.nome, 'Loja salva');
    expect(controller.debts.single.nome, 'Cliente salvo');
    expect(controller.loading, isTrue);
    // As quatro buscas saíram juntas, sem esperar uma pela outra.
    expect(remote.asked, containsAll(['user', 'debts', 'payments', 'bills']));

    remote.user.complete(_user('Loja nova'));
    remote.debts.complete([_debt('d1', 'Cliente salvo'), _debt('d2', 'Novo')]);
    remote.payments.complete([]);
    remote.bills.complete([]);
    await load;
    expect(controller.loading, isFalse);
    expect(controller.user.nome, 'Loja nova');
    expect(controller.debts, hasLength(2));
    expect(controller.syncWarning, isNull);
    expect(controller.needsRefresh, isFalse);
    controller.dispose();
  });

  test('aparelho sem nada salvo espera o servidor sem mostrar dados falsos', () async {
    final remote = SlowRemote();
    final controller = AppController(
      CachedRepository(remote: remote, cache: cache),
    );
    final load = controller.load();
    await pumpEventQueue();
    expect(controller.debts, isEmpty);
    expect(controller.user.email, isEmpty);
    remote.user.complete(_user('Loja'));
    remote.debts.complete([]);
    remote.payments.complete([]);
    remote.bills.complete([]);
    await load;
    expect(controller.user.nome, 'Loja');
    controller.dispose();
  });

  test('sinal que não responde cai no salvo depois do tempo limite', () async {
    await cache.saveUser(_user('Loja salva'));
    await cache.upsertDebt(_debt('d1', 'Cliente salvo'));
    final remote = SlowRemote()..never = true;
    final controller = AppController(
      CachedRepository(
        remote: remote,
        cache: cache,
        readTimeout: const Duration(milliseconds: 50),
      ),
    );
    await controller.load();
    expect(controller.loading, isFalse);
    expect(controller.debts.single.nome, 'Cliente salvo');
    expect(controller.syncWarning, contains('salvos neste aparelho'));
    controller.dispose();
  });
}
