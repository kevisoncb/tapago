import 'package:flutter_test/flutter_test.dart';
import 'package:pago_app/models/models.dart';
import 'package:pago_app/services/client_match.dart';
import 'package:pago_app/services/collection_follow_up.dart';
import 'package:pago_app/services/collection_routine.dart';

void main() {
  test('indicadores separam contato, promessa e saldo', () {
    final now = DateTime(2026, 10, 26, 12);
    Debt debt(String name) => Debt(
      id: name,
      userId: 'u',
      nome: name,
      telefone: '',
      valorPrincipal: 100,
      taxaJuros: 0,
      dataVencimento: now.subtract(const Duration(days: 2)),
      statusPago: false,
      clientScore: 80,
    );
    final contacted = debt('Com contato');
    final untouched = debt('Sem contato');
    final routine = buildCollectionRoutine(
      debts: [contacted, untouched],
      saldoOf: (_) => 100,
      followUps: [
        CollectionFollowUp(
          userId: 'u',
          contactKey: contactKeyOf(contacted),
          clientName: contacted.nome,
          lastContactedAt: now.subtract(const Duration(days: 1)),
          nextContactAt: now,
          promisedAmount: 50,
        ),
      ],
      now: now,
    );
    expect(routine.contacted, 1);
    expect(routine.contactedLast7Days, 1);
    expect(routine.withoutContact, 1);
    expect(routine.promisesToReview, 1);
  });
}
