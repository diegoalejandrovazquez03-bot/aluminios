class AppNavigation {
  /// Hay una pantalla anterior a la cual regresar (la flecha se oculta si no).
  static bool canGoBack = false;
  static void Function()? onBack;

  /// Abre el menú lateral del MainShell. Cada pantalla tiene su propio
  /// Scaffold sin drawer, así que Scaffold.of(context) no sirve para esto.
  static void Function()? openMenu;
}

/// Quién tiene la sesión, para el avatar de la barra superior (lo actualiza
/// MainShell en cada dibujo).
class CurrentUser {
  static String name = 'Usuario';
  static String photoUrl = '';
}
