import 'package:flutter_test/flutter_test.dart';
import 'package:pago_app/services/debt_installments.dart';

void main() {
  group('parcelamento a receber', () {
    test('preserva total em centavos e sobra na última parcela', () {
      final installments = splitReceivable(
        total: 1000,
        firstDue: DateTime(2026, 10, 31),
        installments: 3,
      );

      expect(installments.map((item) => item.valor), [333.33, 333.33, 333.34]);
      expect(
        installments.fold<int>(
          0,
          (sum, item) => sum + (item.valor * 100).round(),
        ),
        100000,
      );
      expect(installments.map((item) => item.parcela), [1, 2, 3]);
      expect(installments.every((item) => item.totalParcelas == 3), isTrue);
    });

    test('primeiro vencimento e intervalo são dias corridos de calendário', () {
      final installments = splitReceivable(
        total: 600,
        firstDue: DateTime(2028, 2, 28, 15, 20),
        installments: 3,
        intervalDays: 15,
      );

      expect(installments.map((item) => item.vencimento), [
        DateTime(2028, 2, 28),
        DateTime(2028, 3, 14),
        DateTime(2028, 3, 29),
      ]);
    });

    test('não cria parcelas de zero centavo', () {
      expect(
        () => splitReceivable(
          total: 0.02,
          firstDue: DateTime(2026),
          installments: 3,
        ),
        throwsArgumentError,
      );
      final minimum = splitReceivable(
        total: 0.12,
        firstDue: DateTime(2026),
        installments: 12,
      );
      expect(minimum.every((item) => item.valor == 0.01), isTrue);
    });

    test('rejeita valores e limites inválidos', () {
      for (final total in [
        0.0,
        -1.0,
        double.nan,
        double.infinity,
        100000001.0,
      ]) {
        expect(
          () => splitReceivable(
            total: total,
            firstDue: DateTime(2026),
            installments: 3,
          ),
          throwsArgumentError,
        );
      }
      for (final count in [0, 1, 13]) {
        expect(
          () => splitReceivable(
            total: 100,
            firstDue: DateTime(2026),
            installments: count,
          ),
          throwsArgumentError,
        );
      }
      for (final interval in [0, 366]) {
        expect(
          () => splitReceivable(
            total: 100,
            firstDue: DateTime(2026),
            installments: 3,
            intervalDays: interval,
          ),
          throwsArgumentError,
        );
      }
    });
  });
}
