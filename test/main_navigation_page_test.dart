import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pago_app/models/models.dart';
import 'package:pago_app/screens/main_navigation_page.dart';
import 'package:pago_app/services/local_repository.dart';
import 'package:pago_app/state/app_controller.dart';
import 'package:pago_app/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppController> _controller() async {
  SharedPreferences.setMockInitialValues({
    'pago_navigation-test_first_use_v1': true,
  });
  final repository = LocalRepository(userId: 'navigation-test');
  await repository.init();
  await repository.saveUser(
    const AppUser(
      id: 'navigation-test',
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

void main() {
  testWidgets('barra principal abre as quatro áreas sem empilhar rotas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _controller();
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
          home: const MainNavigationPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Meu dia'), findsOneWidget);
    final navigation = find.byType(NavigationBar);
    await tester.tap(
      find.descendant(of: navigation, matching: find.text('Clientes')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Caderneta'), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);

    await tester.tap(
      find.descendant(of: navigation, matching: find.text('Boletos')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Boletos a pagar'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing);

    await tester.tap(
      find.descendant(of: navigation, matching: find.text('Mais')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Conta, cobrança e preferências'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsNothing);
    await tester.tap(find.text('Acompanhamentos'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Organize conversas e datas combinadas. Nada aqui altera o saldo da caderneta.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Relatórios'));
    await tester.pumpAndSettle();
    expect(find.text('Recebimentos de clientes'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Boletos de fornecedores'), 300);
    await tester.scrollUntilVisible(
      find.textContaining('não são saldo bancário nem lucro'),
      300,
    );
    expect(
      find.textContaining('não são saldo bancário nem lucro'),
      findsOneWidget,
    );
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
