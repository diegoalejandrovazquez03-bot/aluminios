import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants.dart';
import '../core/app_navigation.dart';
import '../state/app_state.dart';
import '../widgets/app_drawer.dart';
import 'admin/agenda_screen.dart';
import 'admin/catalog_screen.dart';
import 'admin/clients_screen.dart';
import 'admin/dashboard_screen.dart';
import 'admin/new_quote_screen.dart';
import 'admin/payments_screen.dart';
import 'admin/products_screen.dart';
import 'admin/profile_screen.dart';
import 'admin/quote_detail_screen.dart';
import 'admin/quotes_screen.dart';
import 'client/client_catalog_screen.dart';
import 'client/client_home_screen.dart';
import 'client/client_orders_screen.dart';

class MainShell extends StatefulWidget {
  final AppState state;

  const MainShell({super.key, required this.state});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentScreenIndex = 0;
  final List<int> _history = [0];
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _navigateTo(int index) {
    if (index == _currentScreenIndex) return;
    setState(() {
      if ((_currentScreenIndex == 9 && index == 3) ||
          (_currentScreenIndex == 8 && index == 0)) {
        _history.removeLast();
        _history[_history.length - 1] = index;
      } else {
        _history.add(index);
      }
      _currentScreenIndex = index;
    });
  }

  bool _goBack() {
    if (_history.length <= 1) {
      SystemNavigator.pop();
      return false;
    }
    setState(() {
      _history.removeLast();
      _currentScreenIndex = _history.last;
    });
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final isAdmin = state.isAdmin;
    AppNavigation.canGoBack = _history.length > 1;
    AppNavigation.onBack = _goBack;
    AppNavigation.openMenu = () => _scaffoldKey.currentState?.openDrawer();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget currentScreen;

    if (isAdmin) {
      switch (_currentScreenIndex) {
        case 0:
          currentScreen = DashboardScreen(
            state: state,
            onNavigate: _navigateTo,
          );
          break;
        case 1:
          currentScreen = ProductsScreen(state: state, onNavigate: _navigateTo);
          break;
        case 2:
          currentScreen = NewQuoteScreen(state: state, onNavigate: _navigateTo);
          break;
        case 3:
          currentScreen = QuotesScreen(state: state, onNavigate: _navigateTo);
          break;
        case 4:
          currentScreen = ClientsScreen(state: state, onNavigate: _navigateTo);
          break;
        case 5:
          currentScreen = PaymentsScreen(state: state, onNavigate: _navigateTo);
          break;
        case 6:
          currentScreen = AgendaScreen(state: state, onNavigate: _navigateTo);
          break;
        case 7:
          currentScreen = CatalogScreen(state: state, onNavigate: _navigateTo);
          break;
        case 8:
          currentScreen = ProfileScreen(state: state, onNavigate: _navigateTo);
          break;
        case 9:
          currentScreen = QuoteDetailScreen(
            state: state,
            onNavigate: _navigateTo,
          );
          break;
        default:
          currentScreen = DashboardScreen(
            state: state,
            onNavigate: _navigateTo,
          );
      }
    } else {
      switch (_currentScreenIndex) {
        case 0:
          currentScreen = ClientHomeScreen(
            state: state,
            onNavigate: _navigateTo,
          );
          break;
        case 1:
          currentScreen = ClientCatalogScreen(
            state: state,
            onNavigate: _navigateTo,
          );
          break;
        case 2:
          currentScreen = ClientOrdersScreen(
            state: state,
            onNavigate: _navigateTo,
          );
          break;
        case 3:
          currentScreen = ProfileScreen(state: state, onNavigate: _navigateTo);
          break;
        default:
          currentScreen = ClientHomeScreen(
            state: state,
            onNavigate: _navigateTo,
          );
      }
    }

    // Determine bottom nav active item
    int bottomNavIndex = 0;
    if (isAdmin) {
      if (_currentScreenIndex == 0) bottomNavIndex = 0;
      if (_currentScreenIndex == 1) bottomNavIndex = 1;
      if (_currentScreenIndex == 3 || _currentScreenIndex == 9) {
        bottomNavIndex = 2;
      }
      if (_currentScreenIndex == 4) bottomNavIndex = 3;
      if (_currentScreenIndex == 8) bottomNavIndex = 4;
    } else {
      bottomNavIndex = _currentScreenIndex.clamp(0, 3);
    }

    return PopScope(
      canPop: _history.length <= 1,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        key: _scaffoldKey,
        drawer: AppDrawer(
          state: state,
          currentIndex: _currentScreenIndex,
          onSelectScreen: _navigateTo,
        ),
        body: currentScreen,
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: isDark ? AppColors.borderDark : AppColors.border,
              ),
            ),
          ),
          child: NavigationBar(
            selectedIndex: bottomNavIndex,
            destinations: isAdmin
                ? const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: 'Inicio',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.inventory_2_outlined),
                      selectedIcon: Icon(Icons.inventory_2),
                      label: 'Productos',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.receipt_long_outlined),
                      selectedIcon: Icon(Icons.receipt_long),
                      label: 'Cotizaciones',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.people_outline),
                      selectedIcon: Icon(Icons.people),
                      label: 'Clientes',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.person_outline),
                      selectedIcon: Icon(Icons.person),
                      label: 'Perfil',
                    ),
                  ]
                : const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: 'Inicio',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.inventory_2_outlined),
                      selectedIcon: Icon(Icons.inventory_2),
                      label: 'Catálogo',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.receipt_long_outlined),
                      selectedIcon: Icon(Icons.receipt_long),
                      label: 'Pedidos',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.person_outline),
                      selectedIcon: Icon(Icons.person),
                      label: 'Perfil',
                    ),
                  ],
            onDestinationSelected: (dest) {
              if (isAdmin) {
                const adminMapping = [0, 1, 3, 4, 8];
                _navigateTo(adminMapping[dest]);
              } else {
                _navigateTo(dest);
              }
            },
          ),
        ),
      ),
    );
  }
}
