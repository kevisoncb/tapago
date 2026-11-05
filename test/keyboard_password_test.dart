import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pago_app/app.dart';
import 'package:pago_app/screens/auth_page.dart';
import 'package:pago_app/web/web_widgets.dart';
import 'package:pago_app/widgets/fields.dart';

Widget _app(Widget home) => MaterialApp(
  builder: (context, child) => EscapeBack(child: child!),
  home: home,
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDownAll(() => GoogleFonts.config.allowRuntimeFetching = true);

  testWidgets('lista da senha marca cada item conforme a senha', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PasswordChecklist(password: 'abc')),
      ),
    );
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.text('Uma letra maiúscula'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PasswordChecklist(password: 'Senha@123')),
      ),
    );
    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(5));
  });

  testWidgets('Enter no campo confirma', (tester) async {
    String? sent;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppTextField(
            label: 'Senha',
            hint: '',
            icon: Icons.lock,
            onSubmitted: (value) => sent = value,
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(sent, 'abc');
  });

  testWidgets('Esc volta a tela, mesmo com o foco num campo', (tester) async {
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const Scaffold(body: TextField(autofocus: true)),
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('abrir'), findsOneWidget);

    // Na tela inicial, Esc não faz nada.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('abrir'), findsOneWidget);
  });

  testWidgets('Esc fecha o painel do sistema web', (tester) async {
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => openWebPanel(
                context,
                const Scaffold(body: Text('dentro do painel')),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('dentro do painel'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('dentro do painel'), findsNothing);
    expect(find.text('abrir'), findsOneWidget);
  });
}
