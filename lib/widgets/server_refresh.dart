import 'package:flutter/material.dart';

import '../state/app_state.dart';

/// Recarga los datos del servidor (deslizar hacia abajo). Si no hay conexión
/// lo avisa; la app sigue mostrando lo guardado en el teléfono.
Future<void> refreshFromServer(BuildContext context, AppState state) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await state.refreshFromServer();
  if (!ok && state.isLoggedIn) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'No se pudo conectar con el servidor. Se muestran los datos guardados.',
        ),
      ),
    );
  }
}
