import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'bills_page.dart';
import 'caderneta_page.dart';
import 'dashboard_page.dart';
import 'settings_page.dart';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  var _index = 0;

  static const _pages = <Widget>[
    DashboardPage(),
    CadernetaPage(showBillsTab: false),
    BillsPage(embedded: true),
    SettingsPage(embedded: true),
  ];

  @override
  Widget build(BuildContext context) {
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
