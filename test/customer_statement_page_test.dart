import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pago_app/models/models.dart';
import 'package:pago_app/screens/customer_statement_page.dart';
import 'package:pago_app/services/app_repository.dart';
import 'package:pago_app/services/client_match.dart';
import 'package:pago_app/state/app_controller.dart';
import 'package:provider/provider.dart';

class _UnusedRepository implements AppRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StatementController extends AppController {
  _StatementController() : super(_UnusedRepository());
  int reverseCalls = 0;
  final completeReversal = Completer<String?>();

  @override
  Future<String?> reversePayment(
    Payment payment, {
    required String reason,
  }) async {
    reverseCalls++;
    final result = await completeReversal.future;
    if (result == null) {
      payments = [
        payment.copyWith(
          estornadoEm: DateTime(2026, 10, 23),
          estornoMotivo: reason,
        ),
      ];
      notifyListeners();
    }
    return result;
  }
}

void main() {
  setUpAll(() async => initializeDateFormatting('pt_BR'));

  testWidgets('reversal requires a reason and prevents duplicate submission', (
    tester,
  ) async {
    final controller = _StatementController();
    final debt = Debt(
      id: 'd1',
      userId: 'u1',
      nome: 'Maria Exemplo',
      telefone: '11987654321',
      valorPrincipal: 100,
      taxaJuros: 0,
      dataVencimento: DateTime(2026, 10, 30),
      statusPago: false,
      clientScore: 80,
      createdAt: DateTime(2026, 10, 1),
    );
    controller.debts = [debt];
    controller.payments = [
      Payment(
        id: 'p1',
        debtId: debt.id,
        userId: 'u1',
        valor: 30,
        data: DateTime(2026, 10, 20),
      ),
    ];
    await tester.pumpWidget(
      ChangeNotifierProvider<AppController>.value(
        value: controller,
        child: MaterialApp(
          home: CustomerStatementPage(contactKey: contactKeyOf(debt)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Estornar registro'), 250);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Estornar registro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Estornar registro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar estorno'));
    await tester.pump();
    expect(find.text('Informe o motivo do estorno.'), findsOneWidget);
    expect(controller.reverseCalls, 0);
    await tester.enterText(find.byType(TextField), 'Valor duplicado');
    await tester.tap(find.text('Confirmar estorno'));
    await tester.pump();
    expect(find.text('Estornando…'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Estornando…'),
          )
          .onPressed,
      isNull,
    );
    expect(controller.reverseCalls, 1);
    controller.completeReversal.complete(null);
    await tester.pumpAndSettle();
    expect(find.text('Estornar pagamento?'), findsNothing);
    expect(controller.payments.single.estornado, isTrue);
    expect(
      find.text('Registro estornado. O histórico foi preservado.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('statement stays usable on a small screen with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _StatementController();
    final debt = Debt(
      id: 'd1',
      userId: 'u1',
      nome: 'Maria Exemplo de Nome Longo',
      telefone: '',
      valorPrincipal: 1000000,
      taxaJuros: 0,
      dataVencimento: DateTime(2026, 10, 30),
      statusPago: false,
      clientScore: 80,
    );
    controller.debts = [debt];
    await tester.pumpWidget(
      ChangeNotifierProvider<AppController>.value(
        value: controller,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: CustomerStatementPage(contactKey: contactKeyOf(debt)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Exportar CSV'), 200);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
