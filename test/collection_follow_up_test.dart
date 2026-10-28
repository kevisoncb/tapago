import 'package:flutter_test/flutter_test.dart';
import 'package:pago_app/services/collection_follow_up.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'acompanhamento local persiste promessa sem criar pagamento e isola contas',
    () async {
      final date = DateTime(2026, 10, 30);
      final store = CollectionFollowUpStore(usesFirestore: false, userId: 'a');
      await store.save(
        CollectionFollowUp(
          userId: 'a',
          contactKey: 'p:11999999999',
          clientName: 'Cliente',
          note: 'Conversar na sexta',
          nextContactAt: date,
          promisedAmount: 50,
        ),
      );
      final restored = await store.get('p:11999999999');
      expect(restored?.note, 'Conversar na sexta');
      expect(restored?.promisedAmount, 50);
      expect(restored?.nextContactAt, date);
      expect(
        restored?.timingAt(DateTime(2026, 10, 29)),
        FollowUpTiming.upcoming,
      );
      expect(restored?.timingAt(DateTime(2026, 10, 30)), FollowUpTiming.today);
      expect(
        restored?.timingAt(DateTime(2026, 10, 31)),
        FollowUpTiming.overdue,
      );
      expect(await store.list(), hasLength(1));
      expect(
        await CollectionFollowUpStore(
          usesFirestore: false,
          userId: 'b',
        ).get('p:11999999999'),
        isNull,
      );
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getKeys(), {'pago_a_follow_ups'});
    },
  );

  test('recusa salvar dado de outra conta', () async {
    final store = CollectionFollowUpStore(usesFirestore: false, userId: 'a');
    await expectLater(
      store.save(
        const CollectionFollowUp(
          userId: 'b',
          contactKey: 'n:cliente',
          clientName: 'Cliente',
        ),
      ),
      throwsArgumentError,
    );
  });
}
