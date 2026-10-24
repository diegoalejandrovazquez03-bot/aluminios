import 'package:flutter/material.dart';

import 'core/constants.dart';
import 'core/theme.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'state/app_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final appState = AppState();
  runApp(AluminiosApp(appState: appState));
}

class AluminiosApp extends StatelessWidget {
  final AppState appState;

  const AluminiosApp({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final isDark = appState.settings.dark;
        AppColors.dark = isDark;

        return MaterialApp(
          title: 'ALUMINIOS',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          home: appState.isLoggedIn
              ? MainShell(state: appState)
              : LoginScreen(state: appState),
        );
      },
    );
  }
}
