import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'screens/auth_page.dart';
import 'screens/dashboard_page.dart';
import 'services/app_repository.dart';
import 'services/billing_service.dart';
import 'services/biometric_service.dart';
import 'services/reminder_service.dart';
import 'services/session_gate.dart';
import 'state/app_controller.dart';
import 'theme/app_theme.dart';
import 'widgets/biometric_lock.dart';
import 'widgets/common.dart';

class TapagoApp extends StatelessWidget {
  const TapagoApp({super.key, required this.gate});

  final SessionGate gate;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SessionGate>.value(
      value: gate,
      child: ListenableBuilder(
        listenable: gate,
        builder: (context, _) {
          if (gate.booting) {
            return _materialApp(home: const _BootScreen());
          }
          final repository = gate.repository;
          final userId = gate.userId;
          if (repository == null || userId == null) {
            return _materialApp(home: const AuthPage());
          }
          return SignedInApp(
            key: ValueKey(userId),
            repository: repository,
            onSignOut: gate.signOut,
          );
        },
      ),
    );
  }
}

class SignedInApp extends StatefulWidget {
  const SignedInApp({
    super.key,
    required this.repository,
    required this.onSignOut,
  });

  final AppRepository repository;
  final Future<void> Function() onSignOut;

  @override
  State<SignedInApp> createState() => _SignedInAppState();
}

class _SignedInAppState extends State<SignedInApp> {
  late final BillingService _billing;
  late final AppController _controller;

  @override
  void initState() {
    super.initState();
    _billing = BillingService();
    _controller = AppController(
      widget.repository,
      onSignOut: widget.onSignOut,
      billing: _billing,
      reminders: ReminderService(),
      biometrics: BiometricService(),
    )..load();
  }

  @override
  void dispose() {
    _billing.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppController>.value(
      value: _controller,
      child: _materialApp(
        lock: true,
        home: const DashboardPage(),
      ),
    );
  }
}

Widget _materialApp({required Widget home, bool lock = false}) {
  return MaterialApp(
    title: 'TáPago',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    locale: const Locale('pt', 'BR'),
    supportedLocales: const [Locale('pt', 'BR')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) {
      final page = child ?? const SizedBox.shrink();
      return PhoneShell(
        child: lock ? BiometricLock(child: page) : page,
      );
    },
    home: home,
  );
}

class _BootScreen extends StatelessWidget {
  const _BootScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
