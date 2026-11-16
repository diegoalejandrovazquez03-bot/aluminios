import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// Notificaciones en el teléfono (Firebase Cloud Messaging).
///
/// El teléfono se registra en Firebase y manda su identificador (FID) al
/// servidor junto con la sesión; el servidor envía el aviso cuando algo
/// cambia (solicitud nueva, cotización lista, abono…), aunque la app esté
/// cerrada. Si Firebase no está configurado (falta google-services.json) o
/// en las pruebas, todo esto no hace nada y quedan los avisos internos.
class PushService {
  static bool _enabled = false;
  static String? _fid;
  static ({bool orders, bool payments, bool visits})? _prefs;

  /// Con la app abierta llega un aviso: se actualizan los datos para que la
  /// campana lo muestre (Android no enseña la notificación en ese caso).
  static VoidCallback? onForegroundMessage;

  static final _opened = StreamController<Map<String, dynamic>>.broadcast();
  static Map<String, dynamic>? _pendingOpen;

  /// Datos de una notificación que el usuario tocó ({quoteId} o
  /// {requestId}).
  static Stream<Map<String, dynamic>> get opened => _opened.stream;

  /// La notificación que abrió la app estando cerrada, una sola vez.
  static Map<String, dynamic>? takeLaunchMessage() {
    final data = _pendingOpen;
    _pendingOpen = null;
    return data;
  }

  /// Se llama al arrancar, antes de mostrar la app.
  static Future<void> init() async {
    try {
      await Firebase.initializeApp();
    } catch (error) {
      debugPrint(
        'Notificaciones desactivadas (Firebase sin configurar): $error',
      );
      return;
    }
    _enabled = true;
    final messaging = FirebaseMessaging.instance;
    messaging.onRegistered.listen((fid) {
      _fid = fid;
      _send();
    });
    FirebaseMessaging.onMessage.listen((_) => onForegroundMessage?.call());
    FirebaseMessaging.onMessageOpenedApp.listen((m) => _opened.add(m.data));
    try {
      _pendingOpen = (await messaging.getInitialMessage())?.data;
    } catch (error) {
      debugPrint('No se pudo leer la notificación de arranque: $error');
    }
  }

  /// Registra este teléfono para la sesión actual con los avisos que el
  /// cliente quiere recibir (el taller los recibe todos). La primera vez
  /// Android pide el permiso de notificaciones.
  static Future<void> register({
    bool orders = true,
    bool payments = true,
    bool visits = true,
  }) async {
    if (!_enabled) return;
    _prefs = (orders: orders, payments: payments, visits: visits);
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      if (_fid != null) {
        _send();
      } else {
        await messaging.register(); // El FID llega por onRegistered.
      }
    } catch (error) {
      debugPrint(
        'No se pudo registrar el teléfono para notificaciones: $error',
      );
    }
  }

  static void _send() {
    final fid = _fid, prefs = _prefs;
    if (fid == null || prefs == null || ApiClient.token == null) return;
    ApiClient.request(
      'auth',
      method: 'PUT',
      action: 'push',
      body: {
        'token': fid,
        'orders': prefs.orders,
        'payments': prefs.payments,
        'visits': prefs.visits,
      },
    ).catchError((Object error) {
      debugPrint('No se pudo registrar el teléfono en el servidor: $error');
      return null;
    });
  }

  /// Al cerrar sesión: el servidor ya deja de enviar a esa sesión; aquí solo
  /// se olvidan las preferencias de quien salió.
  static void forget() => _prefs = null;
}
