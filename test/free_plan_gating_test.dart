import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pago_app/models/models.dart';
import 'package:pago_app/screens/add_debt_page.dart';
import 'package:pago_app/screens/premium_page.dart';
import 'package:pago_app/services/local_repository.dart';
import 'package:pago_app/state/app_controller.dart';
import 'package:pago_app/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppController> _freeUser() async {
  SharedPreferences.setMockInitialValues({});
  final repository = LocalRepository(userId: 'free-test');
  await repository.init();
  await repository.saveUser(
    const AppUser(
      id: 'free-test',
      nome: 'Loja Teste',
      email: 'teste@example.com',
      isPremium: false,
      chavePix: '',
    ),
  );
  final controller = AppController(repository);
  await controller.load();
  return controller;
}

Widget _app(AppController controller, Widget home) =>
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
        home: home,
      ),
    );

void main() {
  testWidgets('tela Premium mostra R\$ 19,90, as áreas e o botão de assinar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _freeUser();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, const PremiumPage()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('19,90'), findsWidgets);
    expect(find.textContaining('39,90'), findsNothing);
    expect(find.text('Assinar Premium'), findsOneWidget);
    expect(find.text('COBRANÇA'), findsOneWidget);
    expect(find.text('CONTROLE DO CAIXA'), findsOneWidget);
    expect(find.text('AGILIDADE'), findsOneWidget);
  });

  testWidgets('plano grátis: "Foi produto?" leva à tela Premium', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _freeUser();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, const AddDebtPage()));
    await tester.pumpAndSettle();
    final toggle = find.byType(Switch).first;
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(find.byType(PremiumPage), findsOneWidget);
  });
}
