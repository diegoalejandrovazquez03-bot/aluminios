import 'package:flutter/widgets.dart';

class AppNavigation {
  /// Hay una pantalla anterior a la cual regresar (la flecha se oculta si no).
  static bool canGoBack = false;
  static void Function()? onBack;

  /// La pantalla actual es una pestaña principal (Inicio, Productos…): ahí
  /// va el menú en lugar de la flecha de regresar.
  static bool isRoot = true;

  /// Abre el menú lateral del MainShell. Cada pantalla tiene su propio
  /// Scaffold sin drawer, así que Scaffold.of(context) no sirve para esto.
  static void Function()? openMenu;

  /// Abre el perfil de quien tiene la sesión (al tocar el avatar).
  static void Function()? openProfile;

  /// Campana de avisos de la sesión actual; la pone MainShell para que la
  /// barra superior sea igual en todas las pantallas.
  static Widget Function()? noticesButton;
}

/// Quién tiene la sesión, para el avatar de la barra superior (lo actualiza
/// MainShell en cada dibujo).
class CurrentUser {
  static String name = 'Usuario';
  static String photoUrl = '';
}
