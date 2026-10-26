import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pago_app/models/models.dart';
import 'package:pago_app/services/app_repository.dart';
import 'package:pago_app/services/cached_repository.dart';
import 'package:pago_app/services/local_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RemoteRepository extends Fake implements AppRepository {
  String? readError;
  int paymentsWritten = 0;

  @override
  Future<List<Debt>> getDebts() async {
    if (readError != null) {
      throw FirebaseException(plugin: 'cloud_firestore', code: readError!);
    }
    return [];
  }

  @override
  Future<List<Payment>> getPayments({String? debtId}) async => [];

  @override
  Future<void> recordPayment(Payment payment) async {
    paymentsWritten++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RemoteRepository remote;
  late CachedRepository repository;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final cache = LocalRepository(userId: 'u');
    await cache.init();
    await cache.upsertDebt(
      Debt(
        id: 'd',
        userId: 'u',
        nome: 'Cliente',
        telefone: '',
        valorPrincipal: 100,
        taxaJuros: 0,
        dataVencimento: DateTime(2026, 11),
        statusPago: false,
        clientScore: 80,
      ),
    );
    remote = RemoteRepository();
    repository = CachedRepository(remote: remote, cache: cache);
  });

  test(
    'falha de rede exibe cache identificado e recuperação troca pelo servidor',
    () async {
      remote.readError = 'unavailable';
      expect(await repository.getDebts(), hasLength(1));
      expect(repository.usingCachedData, isTrue);
      remote.readError = null;
      expect(await repository.getDebts(), isEmpty);
      expect(repository.usingCachedData, isFalse);
      expect(repository.lastSyncedAt, isNotNull);
    },
  );

  test(
    'permissão negada não exibe cache como se a leitura fosse autorizada',
    () async {
      remote.readError = 'permission-denied';
      await expectLater(
        repository.getDebts(),
        throwsA(isA<FirebaseException>()),
      );
      expect(repository.usingCachedData, isFalse);
    },
  );

  test(
    'pagamento confirmado não vira falha quando atualização do cache falha',
    () async {
      remote.readError = 'unavailable';
      await repository.recordPayment(
        Payment(
          id: 'p',
          debtId: 'd',
          userId: 'u',
          valor: 25,
          data: DateTime(2026, 10, 24),
        ),
      );
      expect(remote.paymentsWritten, 1);
      expect(repository.usingCachedData, isTrue);
    },
  );
}
