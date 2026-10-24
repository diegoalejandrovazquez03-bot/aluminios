import 'package:flutter/material.dart';

/// Paleta de la app. Los colores de texto, superficie y borde se resuelven
/// según el modo activo ([dark]), que main.dart actualiza al cambiar el tema.
/// Los valores `const` (sufijo Light/Dark o colores fijos de marca) son para
/// contextos constantes como theme.dart.
class AppColors {
  static bool dark = false;

  // Marca (tomada del logo: carbón + aluminio)
  static const Color carbon = Color(0xFF1E2124);
  static const Color graphiteLight = Color(0xFF3A3F45);
  static const Color aluminum = Color(0xFFB8BEC5);
  static const Color accent = Color(0xFF2F5D8A); // Azul acero: solo acciones
  static const Color accentDark = Color(0xFF7FA6CC);

  // Claro
  static const Color backgroundLight = Color(0xFFF3F3F1);
  static const Color textMutedLight = Color(0xFF5B6067);
  static const Color borderLight = Color(0xFFDEDDD8);
  static const Color borderStrongLight = Color(0xFFC9CBC6);
  static const Color dividerLight = Color(0xFFECEBE7);

  // Oscuro (la misma marca en carbón)
  static const Color bgDark = Color(0xFF16181B);
  static const Color surfaceDark = Color(0xFF1E2124);
  static const Color subtleDark = Color(0xFF2A2E33);
  static const Color borderDark = Color(0xFF353A40);
  static const Color textOnDark = Color(0xFFE6E8EA);
  static const Color mutedOnDark = Color(0xFF9AA0A7);
  static const Color softOnDark = Color(0xFFC9CED4);

  // Borde neutro semitransparente que funciona en ambos modos
  static const Color hairline = Color(0x338A8F96);

  // ---- Colores que dependen del modo ----

  /// Texto e íconos principales (y fondo de botones primarios).
  static Color get navy => dark ? textOnDark : carbon;
  static Color get textPrimary => navy;

  /// Texto sobre [navy] (p. ej. botón primario).
  static Color get onInk => dark ? bgDark : Colors.white;

  static Color get blue => dark ? accentDark : accent;
  static Color get textMuted => dark ? mutedOnDark : textMutedLight;
  static Color get textDark => dark ? softOnDark : graphiteLight;
  static Color get graphite => textDark;

  static Color get background => dark ? bgDark : backgroundLight;
  static Color get card => dark ? surfaceDark : Colors.white;
  static Color get lightBlue => dark ? subtleDark : dividerLight;
  static Color get border => dark ? borderDark : borderLight;
  static Color get borderStrong => dark ? borderDark : borderStrongLight;
  static Color get divider => dark ? borderDark : dividerLight;

  // Estados: 4 colores con significado
  static Color get pending => const Color(0xFFD18A00);
  static Color get pendingText =>
      dark ? const Color(0xFFE5B45C) : const Color(0xFF7A4F00);
  static Color get progress => blue;
  static Color get done =>
      dark ? const Color(0xFF6FB383) : const Color(0xFF2E6B3F);
  static Color get cancelled =>
      dark ? const Color(0xFFE08A7E) : const Color(0xFFA33A2E);

  // Fondos suaves de estado (para avisos puntuales)
  static Color get pendingBg =>
      dark ? const Color(0xFF3A3020) : const Color(0xFFF7EEDC);
  static Color get approvedBg =>
      dark ? const Color(0xFF22303D) : const Color(0xFFE6ECF2);
  static Color get approvedText => blue;
  static Color get inProcessBg => approvedBg;
  static Color get inProcessText => blue;
  static Color get completedBg =>
      dark ? const Color(0xFF213328) : const Color(0xFFE4EEE6);
  static Color get completedText => done;
  static Color get deliveredBg => completedBg;
  static Color get deliveredText => done;
  static Color get cancelledBg =>
      dark ? const Color(0xFF3A2522) : const Color(0xFFF5E4E1);
  static Color get cancelledText => cancelled;

  static const List<Color> avatarColors = [
    Color(0xFF3A3F45),
    Color(0xFF4A5056),
    Color(0xFF5B6067),
  ];
}
