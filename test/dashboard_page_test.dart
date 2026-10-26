import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pago_app/models/models.dart';
import 'package:pago_app/screens/dashboard_page.dart';
import 'package:pago_app/services/local_repository.dart';
import 'package:pago_app/state/app_controller.dart';
import 'package:pago_app/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Debt _debt(String id, DateTime due) => Debt(
  id: id,
  userId: 'dashboard-test',
  nome: id,
  telefone: '',
  valorPrincipal: 150,
  taxaJuros: 0,
  dataVencimento: due,
  statusPago: false,
  clientScore: 80,
);

Future<AppController> _controller() async {
  SharedPreferences.setMockInitialValues({});
  final repo = LocalRepository(userId: 'dashboard-test');
  await repo.init();
  await repo.saveUser(
    const AppUser(
      id: 'dashboard-test',
      nome: 'Comércio Exemplo',
      email: 'exemplo@example.com',
      isPremium: false,
      chavePix: '',
    ),
  );
  final now = DateTime.now();
  await repo.upsertDebts([
    _debt('Cliente de hoje', now),
    _debt('Cliente em atraso', now.subtract(const Duration(days: 2))),
    _debt('Cliente futuro', now.add(const Duration(days: 3))),
  ]);
  final controller = AppController(repo);
  await controller.load();
  return controller;
}

Widget _app(AppController controller, {double textScale = 1}) {
  return ChangeNotifierProvider<AppController>.value(
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
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: const DashboardPage(),
    ),
  );
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('pt_BR');
  });

  testWidgets(
    'focus selects the right receivables and exposes primary actions',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = await _controller();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_app(controller));
      await tester.pumpAndSettle();

      expect(find.text('Meu dia'), findsOneWidget);
      expect(find.byTooltip('Buscar cliente'), findsOneWidget);
      expect(find.text('Novo lançamento'), findsOneWidget);
      await tester.ensureVisible(find.text('A receber'));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label?.startsWith('A receber') == true &&
              widget.properties.label?.contains('Não é saldo bancário') == true,
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Cliente de hoje'));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.button == true &&
              widget.properties.label?.contains('Cliente de hoje') == true &&
              widget.properties.label?.contains('150,00') == true,
        ),
        findsOneWidget,
      );
      expect(
        find.byTooltip('Preparar cobrança de Cliente de hoje pelo WhatsApp'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Em atraso'));
      await tester.tap(find.text('Em atraso'));
      await tester.pumpAndSettle();
      expect(find.text('Cliente em atraso'), findsOneWidget);
      expect(find.text('Cliente de hoje'), findsNothing);
      expect(find.textContaining('Score'), findsNothing);
      await tester.tap(find.text('Próximos 7 dias'));
      await tester.pumpAndSettle();
      expect(find.text('Cliente de hoje'), findsOneWidget);
      expect(find.text('Cliente futuro'), findsOneWidget);
      expect(find.text('Cliente em atraso'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'small screen and enlarged text retain error recovery without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = await _controller();
      controller.errorMessage = 'Não foi possível atualizar seus dados.';
      addTearDown(controller.dispose);
      await tester.pumpWidget(_app(controller, textScale: 1.8));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Tentar novamente'));
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(find.text('Não foi possível atualizar seus dados.'), findsNothing);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
