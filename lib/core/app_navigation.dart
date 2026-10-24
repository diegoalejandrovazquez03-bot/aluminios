class AppNavigation {
  static bool canGoBack = false;
  static void Function()? onBack;

  /// Abre el menú lateral del MainShell. Cada pantalla tiene su propio
  /// Scaffold sin drawer, así que Scaffold.of(context) no sirve para esto.
  static void Function()? openMenu;
}
