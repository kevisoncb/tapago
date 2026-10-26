import 'package:flutter_test/flutter_test.dart';
import 'package:pago_app/services/plan_catalog.dart';

void main() {
  test(
    'oferta preserva caderneta essencial e descreve limites financeiros',
    () {
      expect(
        PlanCatalog.free.any((item) => item.title == 'Caderneta essencial'),
        isTrue,
      );
      expect(
        PlanCatalog.premium.any(
          (item) => item.description.contains('você confere'),
        ),
        isTrue,
      );
      expect(PlanCatalog.financialDisclaimer, contains('Não consulta banco'));
      expect(
        PlanCatalog.financialDisclaimer,
        contains('não movimenta dinheiro'),
      );
    },
  );
}
