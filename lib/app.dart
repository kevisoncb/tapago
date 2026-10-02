import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'screens/dashboard_page.dart';
import 'services/app_repository.dart';
import 'state/app_controller.dart';
import 'theme/app_theme.dart';
import 'widgets/common.dart';

class TapagoApp extends StatelessWidget {
  const TapagoApp({super.key, required this.repository});

  final AppRepository repository;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppController(repository)..load(),
      child: MaterialApp(
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
        builder: (context, child) => PhoneShell(child: child ?? const SizedBox()),
        home: const DashboardPage(),
      ),
    );
  }
}
