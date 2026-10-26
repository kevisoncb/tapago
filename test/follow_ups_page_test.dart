import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pago_app/models/models.dart';
import 'package:pago_app/screens/follow_ups_page.dart';
import 'package:pago_app/services/collection_follow_up.dart';
import 'package:pago_app/services/local_repository.dart';
import 'package:pago_app/state/app_controller.dart';
import 'package:pago_app/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Debt _debt(String id, String phone, DateTime due) => Debt(
  id: id,
  userId: 'follow-list',
  nome: id,
  telefone: phone,
  valorPrincipal: 100,
  taxaJuros: 0,
  dataVencimento: due,
  statusPago: false,
  clientScore: 80,
);

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('pt_BR');
  });

  testWidgets('lista acompanhamentos com busca e filtros de rotina', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repository = LocalRepository(userId: 'follow-list');
    await repository.init();
    final now = DateTime.now();
    await repository.upsertDebts([
      _debt(
        'Cliente Atrasado',
        '11999999999',
        now.subtract(const Duration(days: 3)),
      ),
      _debt('Cliente Futuro', '11888888888', now.add(const Duration(days: 12))),
    ]);
    final store = CollectionFollowUpStore(
      usesFirestore: false,
      userId: 'follow-list',
    );
    await store.save(
      CollectionFollowUp(
        userId: 'follow-list',
        contactKey: 'p:11999999999',
        clientName: 'Cliente Atrasado',
        nextContactAt: now.subtract(const Duration(days: 1)),
        promisedAmount: 40,
      ),
    );
    await store.save(
      CollectionFollowUp(
        userId: 'follow-list',
        contactKey: 'p:11888888888',
        clientName: 'Cliente Futuro',
        lastContactedAt: now,
        nextContactAt: now.add(const Duration(days: 4)),
      ),
    );
    final controller = AppController(repository);
    await controller.load();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppController>.value(
        value: controller,
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('pt', 'BR'),
          supportedLocales: const [Locale('pt', 'BR')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const FollowUpsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cliente Atrasado'), findsOneWidget);
    expect(find.text('Cliente Futuro'), findsOneWidget);
    expect(find.text('Promessa vencida'), findsOneWidget);
    await tester.tap(find.textContaining('Atrasados '));
    await tester.pumpAndSettle();
    expect(find.text('Cliente Atrasado'), findsOneWidget);
    expect(find.text('Cliente Futuro'), findsNothing);

    await tester.enterText(find.byType(TextField), 'inexistente');
    await tester.pumpAndSettle();
    expect(find.text('Nenhum acompanhamento encontrado'), findsOneWidget);
    expect(controller.payments, isEmpty);
  });
}
