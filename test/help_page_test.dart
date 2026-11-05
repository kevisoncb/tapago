import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pago_app/screens/help_page.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDownAll(() => GoogleFonts.config.allowRuntimeFetching = true);

  testWidgets('ajuda do app abre cada assunto em tela de celular', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: HelpPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cadastrar por voz (Premium)'));
    await tester.pumpAndSettle();
    expect(find.text(voiceHelpSteps.first), findsOneWidget);
    expect(find.text('“${voiceHelpExamples.first}”'), findsOneWidget);
    await tester.tap(find.text('Cadastrar por voz (Premium)'));
    await tester.pumpAndSettle();

    for (final topic in helpTopics) {
      final title = find.text(topic.title);
      await tester.scrollUntilVisible(title, 80);
      await tester.pumpAndSettle();
      await tester.tap(title);
      await tester.pumpAndSettle();
      expect(find.text(topic.steps.first), findsOneWidget, reason: topic.title);
      await tester.tap(title);
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });
}
