import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app.dart';
import 'services/mmp_service.dart';
import 'services/session_gate.dart';
import 'services/tracking_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  final gate = SessionGate();
  await gate.bootstrap();
  runApp(PagoApp(gate: gate));
  unawaited(_startAttribution());
}

/// Primeira abertura, com ou sem login: o ATT vem primeiro (o MMP precisa do
/// status do consentimento para mandar a instalação) e só então o MMP inicia.
/// O usuário entra depois, por `MmpService.setUserId` no `SessionGate`.
Future<void> _startAttribution() async {
  final trackingAuthorized = await TrackingService.instance.requestIfNeeded();
  await MmpService.instance.init(trackingAuthorized: trackingAuthorized);
}
