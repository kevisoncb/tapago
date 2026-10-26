import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pago_app/models/models.dart';
import 'package:pago_app/screens/add_debt_page.dart';
import 'package:pago_app/services/app_repository.dart';
import 'package:pago_app/state/app_controller.dart';
import 'package:provider/provider.dart';

class _SaveRepository implements AppRepository {
  final saves = <Debt>[];
  Completer<void>? pending;
  bool failNext = false;

  @override
  bool get usesFirestore => false;

  @override
  Future<void> upsertDebt(Debt debt) async {
    saves.add(debt);
    await pending?.future;
    if (failNext) {
      failNext = false;
      throw StateError('Conexão interrompida');
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Debt _debt() => Debt(
  id: 'existing',
  userId: 'owner',
  nome: 'Cliente Exemplo',
  telefone: '',
  valorPrincipal: 100,
  taxaJuros: 0,
  dataVencimento: DateTime(2026, 12, 20),
  statusPago: false,
  clientScore: 80,
  grupoId: 'group-one',
  parcela: 2,
  totalParcelas: 3,
);

Future<AppController> _open(
  WidgetTester tester,
  _SaveRepository repository,
) async {
  final controller = AppController(repository);
  controller.user = const AppUser(
    id: 'owner',
    nome: 'Comerciante',
    email: 'exemplo@example.com',
    isPremium: false,
    chavePix: '',
  );
  controller.debts = [_debt()];
  await tester.pumpWidget(
    ChangeNotifierProvider<AppController>.value(
      value: controller,
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => AddDebtPage(debt: _debt())),
              ),
              child: const Text('Abrir edição'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir edição'));
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('pt_BR');
  });
  tearDownAll(() => GoogleFonts.config.allowRuntimeFetching = true);

  testWidgets('não duplica um salvamento enquanto o primeiro está pendente', (
    tester,
  ) async {
    final repository = _SaveRepository()..pending = Completer<void>();
    final controller = await _open(tester, repository);
    await tester.tap(find.text('Salvar na caderneta'));
    await tester.pump();
    expect(find.text('Salvando…'), findsOneWidget);
    await tester.tap(find.text('Salvando…'));
    await tester.pump();
    expect(repository.saves, hasLength(1));
    repository.pending!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Abrir edição'), findsOneWidget);
    expect(repository.saves.single.grupoId, 'group-one');
    expect(repository.saves.single.parcela, 2);
    expect(repository.saves.single.totalParcelas, 3);
    controller.dispose();
  });

  testWidgets('falha conserva o payload e repete o mesmo lançamento', (
    tester,
  ) async {
    final repository = _SaveRepository()..failNext = true;
    final controller = await _open(tester, repository);
    await tester.tap(find.text('Salvar na caderneta'));
    await tester.pumpAndSettle();
    expect(find.text('Tentar salvar novamente'), findsOneWidget);
    expect(repository.saves, hasLength(1));
    await tester.tap(find.text('Tentar salvar novamente'));
    await tester.pumpAndSettle();
    expect(repository.saves, hasLength(2));
    expect(identical(repository.saves[0], repository.saves[1]), isTrue);
    expect(find.text('Abrir edição'), findsOneWidget);
    controller.dispose();
  });
}
