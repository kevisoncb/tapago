import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pago_app/widgets/brand_splash.dart';

Widget _host({required bool reduce, required VoidCallback onDone}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: BrandSplash(reduceMotion: reduce, onDone: onDone),
  );
}

void main() {
  testWidgets('abertura mostra a marca e avisa ao terminar', (tester) async {
    var done = 0;
    await tester.pumpWidget(_host(reduce: false, onDone: () => done++));

    expect(find.text('Pagô'), findsOneWidget);
    expect(done, 0);

    await tester.pump(BrandSplash.total);
    expect(find.text('Pagô'), findsOneWidget);
    expect(find.text('E aí, pagô?'), findsOneWidget);
    expect(done, 0);

    await tester.pump(BrandSplash.fade);
    await tester.pump(BrandSplash.fade);
    expect(done, 1);
  });

  testWidgets('reduzir movimento mostra o quadro final e sai rápido', (
    tester,
  ) async {
    var done = 0;
    await tester.pumpWidget(_host(reduce: true, onDone: () => done++));

    expect(find.text('E aí, pagô?'), findsOneWidget);
    expect(done, 0);

    await tester.pump(BrandSplash.reducedHold);
    await tester.pump(BrandSplash.reducedFade);
    await tester.pump(BrandSplash.reducedFade);
    expect(done, 1);
  });
}
