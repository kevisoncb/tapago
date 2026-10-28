import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pago_app/models/models.dart';
import 'package:pago_app/screens/main_navigation_page.dart';
import 'package:pago_app/services/first_use_guide.dart';
import 'package:pago_app/services/local_repository.dart';
import 'package:pago_app/state/app_controller.dart';
import 'package:pago_app/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppController> _emptyController() async {
  final repository = LocalRepository(userId: 'first-use-test');
  await repository.init();
  await repository.saveUser(
    const AppUser(
      id: 'first-use-test',
      nome: 'Loja Nova',
      email: 'nova@example.com',
      isPremium: false,
      chavePix: '',
    ),
  );
  final controller = AppController(repository);
  await controller.load();
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('conclusão do guia fica isolada por conta', () async {
    SharedPreferences.setMockInitialValues({});
    const store = FirstUseGuideStore();
    expect(await store.shouldShow('conta-a'), isTrue);
    await store.complete('conta-a');
    expect(await store.shouldShow('conta-a'), isFalse);
    expect(await store.shouldShow('conta-b'), isTrue);
  });

  testWidgets('conta vazia vê introdução e segue ao primeiro lançamento', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _emptyController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppController>.value(
        value: controller,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const MainNavigationPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Seu dinheiro a receber, no controle'), findsOneWidget);
    expect(find.textContaining('permissão'), findsNothing);
    await tester.tap(find.text('Próximo'));
    await tester.pumpAndSettle();
    expect(find.text('Uma caderneta que mostra o histórico'), findsOneWidget);
    await tester.tap(find.text('Próximo'));
    await tester.pumpAndSettle();
    expect(find.text('Você decide quais atalhos usar'), findsOneWidget);
    expect(find.textContaining('só pede cada permissão'), findsOneWidget);
    await tester.tap(find.text('Criar primeiro lançamento'));
    await tester.pumpAndSettle();
    expect(find.text('Novo lançamento'), findsOneWidget);

    const store = FirstUseGuideStore();
    expect(await store.shouldShow('first-use-test'), isFalse);
    expect(tester.takeException(), isNull);
  });
}
