import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants.dart';
import '../core/app_navigation.dart';
import '../core/app_routes.dart';
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
import 'client/client_profile_screen.dart';

class MainShell extends StatefulWidget {
  final AppState state;

  const MainShell({super.key, required this.state});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // Historial de pantallas; la última es la que se muestra. Inicio siempre
  // es la base, así que "regresar" nunca sale de la app por accidente.
  final List<int> _history = [AdminScreen.inicio];
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int get _currentScreenIndex => _history.last;

  void _navigateTo(int index) {
    if (index == _currentScreenIndex) return;
    setState(() {
      final existing = _history.lastIndexOf(index);
      if (existing >= 0) {
        // Ya estaba abierta: se regresa a ella en lugar de apilarla otra vez.
        _history.removeRange(existing + 1, _history.length);
        return;
      }
      // Al salir de un formulario o un detalle hacia la lista de cotizaciones
      // (guardar, cancelar), ese formulario/detalle no queda en el historial.
      if (widget.state.isAdmin &&
          index == AdminScreen.cotizaciones &&
          (_currentScreenIndex == AdminScreen.nuevaCotizacion ||
              _currentScreenIndex == AdminScreen.detalleCotizacion)) {
        _history.removeLast();
        if (_history.last == index) return;
      }
      _history.add(index);
    });
  }

  bool _goBack() {
    if (_history.length <= 1) {
      SystemNavigator.pop();
      return false;
    }
    setState(() => _history.removeLast());
    return true;
  }

  /// Pestaña inferior que corresponde a cada pantalla. Las pantallas que no
  /// son pestaña se marcan en la sección desde la que se abren.
  int _adminTabFor(int screen) {
    switch (screen) {
      case AdminScreen.productos:
        return 1;
      case AdminScreen.cotizaciones:
      case AdminScreen.nuevaCotizacion:
      case AdminScreen.detalleCotizacion:
        return 2;
      case AdminScreen.clientes:
        return 3;
      case AdminScreen.perfil:
        return 4;
      default: // inicio, pagos, agenda y catálogo se abren desde Inicio
        return 0;
    }
  }

  static const _adminTabs = [
    AdminScreen.inicio,
    AdminScreen.productos,
    AdminScreen.cotizaciones,
    AdminScreen.clientes,
    AdminScreen.perfil,
  ];
  static const _clientTabs = [
    ClientScreen.inicio,
    ClientScreen.catalogo,
    ClientScreen.pedidos,
    ClientScreen.perfil,
  ];

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final isAdmin = state.isAdmin;
    AppNavigation.canGoBack = _history.length > 1;
    AppNavigation.onBack = _goBack;
    AppNavigation.openMenu = () => _scaffoldKey.currentState?.openDrawer();
    // Avatar de la barra superior: foto o iniciales de quien tiene la sesión.
    CurrentUser.name = isAdmin
        ? state.settings.bizName
        : (state.currentClient?.name ?? 'Cliente');
    CurrentUser.photoUrl = isAdmin
        ? state.settings.avatarUrl
        : (state.currentAccount?.avatarUrl ?? '');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget currentScreen;

    if (isAdmin) {
      switch (_currentScreenIndex) {
        case AdminScreen.inicio:
          currentScreen = DashboardScreen(
            state: state,
            onNavigate: _navigateTo,
          );
          break;
        case AdminScreen.productos:
          currentScreen = ProductsScreen(state: state, onNavigate: _navigateTo);
          break;
        case AdminScreen.nuevaCotizacion:
          currentScreen = NewQuoteScreen(state: state, onNavigate: _navigateTo);
          break;
        case AdminScreen.cotizaciones:
          currentScreen = QuotesScreen(state: state, onNavigate: _navigateTo);
          break;
        case AdminScreen.clientes:
          currentScreen = ClientsScreen(state: state, onNavigate: _navigateTo);
          break;
        case AdminScreen.pagos:
          currentScreen = PaymentsScreen(state: state, onNavigate: _navigateTo);
          break;
        case AdminScreen.agenda:
          currentScreen = AgendaScreen(state: state, onNavigate: _navigateTo);
          break;
        case AdminScreen.catalogo:
          currentScreen = CatalogScreen(state: state, onNavigate: _navigateTo);
          break;
        case AdminScreen.perfil:
          currentScreen = ProfileScreen(state: state, onNavigate: _navigateTo);
          break;
        case AdminScreen.detalleCotizacion:
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
        case ClientScreen.inicio:
          currentScreen = ClientHomeScreen(
            state: state,
            onNavigate: _navigateTo,
          );
          break;
        case ClientScreen.catalogo:
          currentScreen = ClientCatalogScreen(
            state: state,
            onNavigate: _navigateTo,
          );
          break;
        case ClientScreen.pedidos:
          currentScreen = ClientOrdersScreen(
            state: state,
            onNavigate: _navigateTo,
          );
          break;
        case ClientScreen.perfil:
          currentScreen = ClientProfileScreen(
            state: state,
            onNavigate: _navigateTo,
          );
          break;
        default:
          currentScreen = ClientHomeScreen(
            state: state,
            onNavigate: _navigateTo,
          );
      }
    }

    final bottomNavIndex = isAdmin
        ? _adminTabFor(_currentScreenIndex)
        : _clientTabs.indexOf(_currentScreenIndex).clamp(0, 3);

    // Cada pantalla tiene su propia identidad: al cambiar de apartado nunca
    // se reutiliza el estado (filtros, formularios) de otra pantalla.
    currentScreen = KeyedSubtree(
      key: ValueKey('${isAdmin ? 'admin' : 'cliente'}-$_currentScreenIndex'),
      child: currentScreen,
    );

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
            onDestinationSelected: (dest) =>
                _navigateTo(isAdmin ? _adminTabs[dest] : _clientTabs[dest]),
          ),
        ),
      ),
    );
  }
}
