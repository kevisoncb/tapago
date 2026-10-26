import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/first_use_guide.dart';
import '../state/app_controller.dart';
import '../theme/app_colors.dart';
import 'add_debt_page.dart';
import 'bills_page.dart';
import 'caderneta_page.dart';
import 'dashboard_page.dart';
import 'first_use_page.dart';
import 'settings_page.dart';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  var _index = 0;
  var _guideHandled = false;
  final _guideStore = const FirstUseGuideStore();

  static const _pages = <Widget>[
    DashboardPage(),
    CadernetaPage(showBillsTab: false),
    BillsPage(embedded: true),
    SettingsPage(embedded: true),
  ];

  Future<void> _completeGuide(String userId) async {
    try {
      await _guideStore.complete(userId);
    } catch (error) {
      debugPrint('Primeiro uso não persistido: $error');
    }
  }

  Future<void> _handleFirstUse(AppController state) async {
    final userId = state.user.id;
    if (state.debts.isNotEmpty) {
      await _completeGuide(userId);
      return;
    }
    if (!await _guideStore.shouldShow(userId) || !mounted) return;
    final create = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const FirstUsePage()));
    await _completeGuide(userId);
    if (create == true && mounted) {
      await Navigator.of(context)
          .push<void>(MaterialPageRoute(builder: (_) => const AddDebtPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppController>();
    if (!_guideHandled &&
        !state.loading &&
        state.errorMessage == null &&
        state.user.id.isNotEmpty) {
      _guideHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_handleFirstUse(state));
      });
    }
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primarySoft,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today_rounded),
            label: 'Hoje',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'Clientes',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Boletos',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz_rounded),
            selectedIcon: Icon(Icons.more_rounded),
            label: 'Mais',
          ),
        ],
      ),
    );
  }
}
