import 'package:flutter/material.dart';

import 'core/localization/app_localizations.dart';
import 'features/home/presentation/home_page.dart';
import 'features/menu/presentation/menu_page.dart';
import 'features/orders/presentation/orders_page.dart';
import 'features/settings/presentation/settings_page.dart';

/// Bottom navigation scaffold managing the 4 top-level tabs.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  final ValueNotifier<int> _ordersRefreshSignal = ValueNotifier<int>(0);

  // Preserve tab state across navigation using IndexedStack.
  late final List<Widget> _pages = [
    const HomePage(),
    const MenuPage(),
    OrdersPage(refreshSignal: _ordersRefreshSignal),
    const SettingsPage(),
  ];

  @override
  void dispose() {
    _ordersRefreshSignal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 2) {
            _ordersRefreshSignal.value++;
          }
          setState(() => _currentIndex = index);
        },
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home_rounded),
            label: context.l10n.home,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.restaurant_menu_outlined),
            activeIcon: const Icon(Icons.restaurant_menu_rounded),
            label: context.l10n.menu,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.assignment_outlined),
            activeIcon: const Icon(Icons.assignment_rounded),
            label: context.l10n.orders,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings_outlined),
            activeIcon: const Icon(Icons.settings_rounded),
            label: context.l10n.settings,
          ),
        ],
      ),
    );
  }
}
