import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pago_app/data/seed_data.dart';
import 'package:pago_app/models/models.dart';
import 'package:pago_app/services/local_repository.dart';
import 'package:pago_app/state/app_controller.dart';
import 'package:pago_app/theme/app_theme.dart';
import 'package:pago_app/web/web_help.dart';
import 'package:pago_app/web/web_shell.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _userId = 'web-shell-test';

Future<AppController> _controller({required bool premium}) async {
  SharedPreferences.setMockInitialValues({});
  final repository = LocalRepository(userId: _userId);
  await repository.init();
  await repository.saveUser(
    AppUser(
      id: _userId,
      nome: 'Loja Teste',
      email: 'teste@example.com',
      isPremium: premium,
      premiumVenceEm: premium ? DateTime.now().add(const Duration(days: 30)) : null,
      chavePix: '',
    ),
  );
  await repository.replaceDebts(SeedData.debts());
  await repository.replacePayments(SeedData.payments());
  await repository.replaceBills(SeedData.bills(DateTime.now()));
  final controller = AppController(repository);
  await controller.load();
  return controller;
}

Future<void> _pump(WidgetTester tester, AppController controller, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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
        home: const WebShell(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Abre a área pelo menu: pelo texto no menu cheio e pelo ícone no menu compacto.
Future<void> _open(WidgetTester tester, WebSection section, {required bool compact}) async {
  await tester.tap(
    compact
        ? find.byIcon(section.icon).first
        : find.text(section.label).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDownAll(() => GoogleFonts.config.allowRuntimeFetching = true);

  // Estouro de layout faz o teste falhar, então cada largura cobre todas as áreas.
  for (final width in [720.0, 900.0, 1100.0, 1600.0]) {
    for (final premium in [false, true]) {
      testWidgets('largura $width (premium: $premium): todas as áreas abrem sem estourar', (
        tester,
      ) async {
        final controller = await _controller(premium: premium);
        addTearDown(controller.dispose);
        await _pump(tester, controller, Size(width, 800));
        final compact = width < 1100;
        for (final section in WebSection.values) {
          if (section == WebSection.inicio) continue;
          if (section == WebSection.premium && premium) continue;
          await _open(tester, section, compact: compact);
          expect(tester.takeException(), isNull, reason: section.label);
        }
      });
    }
  }

  testWidgets('menu compacto só mostra ícones e o completo mostra os nomes', (tester) async {
    final controller = await _controller(premium: false);
    addTearDown(controller.dispose);
    await _pump(tester, controller, const Size(900, 800));
    expect(find.text('Sair da conta'), findsNothing);
    expect(find.byIcon(Icons.help_outline_rounded), findsOneWidget);
    await _pump(tester, controller, const Size(1280, 800));
    expect(find.text('Sair da conta'), findsOneWidget);
    expect(find.text('Ajuda'), findsOneWidget);
  });

  testWidgets('Ajuda mostra os primeiros passos, os atalhos levam à área e o tópico abre', (
    tester,
  ) async {
    final controller = await _controller(premium: false);
    addTearDown(controller.dispose);
    await _pump(tester, controller, const Size(1280, 900));
    await _open(tester, WebSection.ajuda, compact: false);

    for (final step in webHelpStart) {
      expect(find.text(step.title), findsOneWidget);
    }
    final topic = webHelpTopics.first;
    await tester.ensureVisible(find.text(topic.title));
    await tester.pumpAndSettle();
    await tester.tap(find.text(topic.title));
    await tester.pumpAndSettle();
    expect(find.text(topic.steps.first), findsOneWidget);

    final shortcut = find.text('Abrir Venda');
    await tester.ensureVisible(shortcut);
    await tester.pumpAndSettle();
    await tester.tap(shortcut);
    await tester.pumpAndSettle();
    expect(find.text('Lançar venda'), findsOneWidget);
  });

  testWidgets('sem Premium, boleto não pode ser criado nem alterado, como no app', (tester) async {
    final controller = await _controller(premium: false);
    addTearDown(controller.dispose);
    await _pump(tester, controller, const Size(1280, 900));
    await _open(tester, WebSection.boletos, compact: false);

    expect(find.text('Marcar pago'), findsNothing);
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    await tester.tap(find.text('Novo boleto'));
    await tester.pumpAndSettle();
    expect(find.text('Você está no plano grátis.'), findsOneWidget);
  });

  testWidgets('com Premium, boleto pode ser marcado como pago', (tester) async {
    final controller = await _controller(premium: true);
    addTearDown(controller.dispose);
    await _pump(tester, controller, const Size(1280, 900));
    await _open(tester, WebSection.boletos, compact: false);
    expect(find.text('Marcar pago'), findsWidgets);
  });
}
