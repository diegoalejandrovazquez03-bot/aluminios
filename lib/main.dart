import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/constants.dart';
import 'core/push_service.dart';
import 'core/theme.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _installErrorReporting();
  await PushService.init();
  final appState = AppState();
  // Un aviso con la app abierta: se traen los cambios y aparece en la campana.
  PushService.onForegroundMessage = appState.refreshFromServer;
  runApp(AluminiosApp(appState: appState));
}

/// Errores inesperados: quedan registrados con su detalle técnico (consola /
/// `flutter logs`) y el usuario ve un mensaje comprensible en lugar de la
/// pantalla roja. No sustituye corregir la causa: el registro sirve para eso.
void _installErrorReporting() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint(
      '[ERROR] ${details.context?.toDescription() ?? 'Flutter'}: '
      '${details.exceptionAsString()}\n${details.stack}',
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[ERROR] Asíncrono: $error\n$stack');
    return true;
  };
  ErrorWidget.builder = (details) => Material(
    color: Colors.transparent,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: AppColors.cancelled),
            const SizedBox(height: 12),
            Text(
              'No se pudo mostrar esta sección.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Regresa e inténtalo de nuevo. Si se repite, avisa al soporte.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 12),
              Text(
                details.exceptionAsString(),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class AluminiosApp extends StatefulWidget {
  final AppState appState;

  const AluminiosApp({super.key, required this.appState});

  @override
  State<AluminiosApp> createState() => _AluminiosAppState();
}

class _AluminiosAppState extends State<AluminiosApp> {
  late bool _dark = widget.appState.settings.dark;

  @override
  void initState() {
    super.initState();
    widget.appState.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    widget.appState.removeListener(_onStateChanged);
    super.dispose();
  }

  // La app completa (tema, idioma, navegación) solo se rehace al cambiar de
  // modo claro/oscuro; los demás cambios redibujan solo la pantalla abierta.
  void _onStateChanged() {
    if (widget.appState.settings.dark != _dark) {
      setState(() => _dark = widget.appState.settings.dark);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = widget.appState;
    final isDark = _dark;
    AppColors.dark = isDark;

    return MaterialApp(
      title: 'ALUMINIOS',
      debugShowCheckedModeBanner: false,
      // Calendarios, selectores de fecha y menús (copiar/pegar) en español.
      locale: const Locale('es', 'MX'),
      supportedLocales: const [Locale('es', 'MX'), Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      // Cambio de modo instantáneo: los colores de AppColors cambian de
      // golpe, así que una transición animada del tema mezclaba colores
      // de ambos modos (y obligaba a interpolar estilos de texto).
      themeAnimationDuration: Duration.zero,
      home: ListenableBuilder(
        listenable: appState,
        builder: (context, _) => appState.isLoggedIn
            ? MainShell(state: appState)
            : LoginScreen(state: appState),
      ),
    );
  }
}
