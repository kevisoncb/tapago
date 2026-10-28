import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pago_app/models/models.dart';
import 'package:pago_app/screens/caderneta_page.dart';
import 'package:pago_app/services/local_repository.dart';
import 'package:pago_app/state/app_controller.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('carteira filtra clientes por atraso e situação', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    final repository = LocalRepository(userId: 'filters');
    await repository.init();
    final now = DateTime.now();
    await repository.upsertDebts([
      Debt(
        id: 'Cliente atrasado',
        userId: 'filters',
        nome: 'Cliente atrasado',
        telefone: '',
        valorPrincipal: 100,
        taxaJuros: 0,
        dataVencimento: now.subtract(const Duration(days: 2)),
        statusPago: false,
        clientScore: 80,
      ),
      Debt(
        id: 'Cliente futuro',
        userId: 'filters',
        nome: 'Cliente futuro',
        telefone: '',
        valorPrincipal: 100,
        taxaJuros: 0,
        dataVencimento: now.add(const Duration(days: 3)),
        statusPago: false,
        clientScore: 80,
      ),
    ]);
    final controller = AppController(repository);
    await controller.load();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppController>.value(
        value: controller,
        child: const MaterialApp(home: CadernetaPage(showBillsTab: false)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cliente atrasado'), findsOneWidget);
    expect(find.text('Cliente futuro'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(ChoiceChip),
        matching: find.text('Em atraso'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cliente atrasado'), findsOneWidget);
    expect(find.text('Cliente futuro'), findsNothing);
    await tester.drag(find.byType(ListView).first, const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(ChoiceChip),
        matching: find.text('Sem contato'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cliente atrasado'), findsOneWidget);
  });
}
