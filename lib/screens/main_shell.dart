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

  /// Pestaña inferior que corresponde a cada pantalla, o null si la pantalla
  /// no es pestaña (pagos, agenda, catálogo): entonces no se marca ninguna.
  int? _adminTabFor(int screen) {
    switch (screen) {
      case AdminScreen.inicio:
        return 0;
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
      default:
        return null;
    }
  }

  static const _adminTabs = [
    AdminScreen.inicio,
    AdminScreen.productos,
    AdminScreen.cotizaciones,
    AdminScreen.clientes,
    AdminScreen.perfil,
  ];
  // Ícono, ícono marcado y texto de cada pestaña.
  static const _adminDestinations = [
    (Icons.home_outlined, Icons.home, 'Inicio'),
    (Icons.inventory_2_outlined, Icons.inventory_2, 'Productos'),
    (Icons.receipt_long_outlined, Icons.receipt_long, 'Cotizaciones'),
    (Icons.people_outline, Icons.people, 'Clientes'),
    (Icons.person_outline, Icons.person, 'Perfil'),
  ];
  static const _clientDestinations = [
    (Icons.home_outlined, Icons.home, 'Inicio'),
    (Icons.inventory_2_outlined, Icons.inventory_2, 'Catálogo'),
    (Icons.receipt_long_outlined, Icons.receipt_long, 'Pedidos'),
    (Icons.person_outline, Icons.person, 'Perfil'),
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

    final tab = isAdmin
        ? _adminTabFor(_currentScreenIndex)
        : _clientTabs.indexOf(_currentScreenIndex).clamp(0, 3);
    // NavigationBar siempre marca una pestaña; en pantallas que no son
    // pestaña se le quita el resaltado para que ninguna parezca activa.
    final navTheme = NavigationBarTheme.of(context);
    final unselected = WidgetStatePropertyAll(
      navTheme.labelTextStyle?.resolve({}),
    );

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
          child: NavigationBarTheme(
            data: tab != null
                ? navTheme
                : navTheme.copyWith(
                    indicatorColor: Colors.transparent,
                    labelTextStyle: unselected,
                    iconTheme: WidgetStatePropertyAll(
                      navTheme.iconTheme?.resolve({}),
                    ),
                  ),
            child: NavigationBar(
              selectedIndex: tab ?? 0,
              destinations: [
                for (final (icon, selectedIcon, label)
                    in isAdmin ? _adminDestinations : _clientDestinations)
                  NavigationDestination(
                    icon: Icon(icon),
                    selectedIcon: Icon(tab != null ? selectedIcon : icon),
                    label: label,
                  ),
              ],
              onDestinationSelected: (dest) =>
                  _navigateTo(isAdmin ? _adminTabs[dest] : _clientTabs[dest]),
            ),
          ),
        ),
      ),
    );
  }
}
