import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'screens/auth_page.dart';
import 'screens/bills_page.dart';
import 'screens/client_profile_page.dart';
import 'screens/follow_ups_page.dart';
import 'screens/main_navigation_page.dart';
import 'services/app_repository.dart';
import 'services/billing_service.dart';
import 'services/biometric_service.dart';
import 'services/reminder_service.dart';
import 'services/session_gate.dart';
import 'state/app_controller.dart';
import 'theme/app_theme.dart';
import 'widgets/biometric_lock.dart';
import 'widgets/common.dart';

class PagoApp extends StatelessWidget {
  const PagoApp({super.key, required this.gate});

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

class _SignedInAppState extends State<SignedInApp> with WidgetsBindingObserver {
  late final BillingService _billing;
  late final AppController _controller;
  final _navigatorKey = GlobalKey<NavigatorState>();
  ReminderTarget? _pendingReminder;
  var _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _billing = BillingService();
    _controller = AppController(
      widget.repository,
      onSignOut: widget.onSignOut,
      billing: _billing,
      reminders: ReminderService(onOpen: _onReminder),
      biometrics: BiometricService(),
    );
    _load();
  }

  Future<void> _load() async {
    await _controller.load();
    if (!mounted) return;
    _loaded = true;
    final target = _pendingReminder;
    if (target != null) {
      _pendingReminder = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _onReminder(target));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _loaded) _load();
  }

  Future<void> _onReminder(ReminderTarget target) async {
    if (!mounted) return;
    if (!_loaded || _navigatorKey.currentState == null) {
      _pendingReminder = target;
      return;
    }
    if (target.userId != null && target.userId != _controller.user.id) return;
    Widget page;
    if (target.isFollowUp) {
      page = const FollowUpsPage();
    } else if (target.isBill) {
      final bill = _controller.bills
          .where((item) => item.id == target.id)
          .firstOrNull;
      if (bill == null) return;
      page = BillsPage(fornecedor: bill.fornecedor);
    } else {
      final debt = _controller.debts
          .where((item) => item.id == target.id)
          .firstOrNull;
      if (debt == null) return;
      page = ClientProfilePage(debt: debt);
    }
    _navigatorKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
        navigatorKey: _navigatorKey,
        home: const MainNavigationPage(),
      ),
    );
  }
}

Widget _materialApp({
  required Widget home,
  bool lock = false,
  GlobalKey<NavigatorState>? navigatorKey,
}) {
  return MaterialApp(
    title: 'Pagô',
    navigatorKey: navigatorKey,
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
      return PhoneShell(child: lock ? BiometricLock(child: page) : page);
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
