import 'dart:convert';

import 'package:aluminios_app/core/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Backend en memoria para las pruebas: imita a Aluminios.Api (cuentas,
/// sesiones por token, permisos por rol y recursos genéricos).
class FakeServer {
  static const adminEmail = 'admin@aluminieros.com';
  static const adminPassword = 'admin-pass';

  final accounts = <Map<String, dynamic>>[];
  final sessions = <String, Map<String, dynamic>>{}; // token -> cuenta
  final tables = <String, List<Map<String, dynamic>>>{};
  int _nextId = 5000;

  FakeServer() {
    accounts.add({
      'id': 1,
      'email': adminEmail,
      'name': 'Administrador',
      'phone': '',
      'role': 'admin',
      'clientId': 0,
      'password': adminPassword,
    });
  }

  /// Hace que ApiClient hable con este servidor.
  void install() {
    ApiClient.token = null;
    ApiClient.clientFactory = () => MockClient(_handle);
  }

  List<Map<String, dynamic>> table(String name) =>
      tables.putIfAbsent(name, () => []);

  http.Response _json(int status, Object? body) => http.Response(
    body == null ? '' : jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  http.Response _error(int status, String message) =>
      _json(status, {'error': message});

  Map<String, dynamic> _profile(Map<String, dynamic> a) => {
    'role': a['role'],
    'clientId': a['clientId'],
    'email': a['email'],
    'name': a['name'],
    'phone': a['phone'],
  };

  http.Response _session(Map<String, dynamic> account) {
    final token = 'tok-${_nextId++}';
    sessions[token] = account;
    return _json(200, {'token': token, 'profile': _profile(account)});
  }

  Future<http.Response> _handle(http.Request request) async {
    final parts = request.url.pathSegments.skip(1).toList(); // sin "api"
    final body = request.body.isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(request.body));
    final method = request.method;

    if (parts.first == 'auth' && parts.length == 2) {
      if (parts[1] == 'register' && method == 'POST') {
        final email = (body['email'] as String).toLowerCase();
        if (accounts.any((a) => a['email'] == email)) {
          return _error(409, 'Este correo ya está registrado');
        }
        final clientId = _nextId++;
        table(
          'clientes',
        ).add({'id': clientId, 'name': body['name'], 'phone': body['phone']});
        final account = {
          'id': _nextId++,
          'email': email,
          'name': body['name'],
          'phone': body['phone'],
          'role': 'client',
          'clientId': clientId,
          'password': body['password'],
        };
        accounts.add(account);
        return _session(account);
      }
      if (parts[1] == 'login' && method == 'POST') {
        final account = accounts
            .where(
              (a) =>
                  a['email'] == (body['email'] as String).toLowerCase() &&
                  a['password'] == body['password'],
            )
            .firstOrNull;
        if (account == null) {
          return _error(401, 'Correo o contraseña incorrectos');
        }
        return _session(account);
      }
    }

    final token = request.headers['Authorization']?.replaceFirst('Bearer ', '');
    final me = token == null ? null : sessions[token];
    if (me == null) {
      return _error(401, 'Tu sesión expiró. Vuelve a iniciar sesión.');
    }
    final isAdmin = me['role'] == 'admin';
    final clientId = me['clientId'];

    if (parts.first == 'auth') {
      switch ('$method ${parts[1]}') {
        case 'PUT me':
          me['name'] = body['name'];
          me['phone'] = body['phone'];
          me['email'] = body['email'];
          for (final c in table('clientes').where((c) => c['id'] == clientId)) {
            c['name'] = body['name'];
            c['phone'] = body['phone'];
          }
          return _json(200, _profile(me));
        case 'POST password':
          if (me['password'] != body['current']) {
            return _error(400, 'La contraseña actual no es correcta');
          }
          me['password'] = body['new'];
          return _json(204, null);
        case 'POST logout':
          sessions.remove(token);
          return _json(204, null);
      }
    }

    final resource = parts.first;
    final id = parts.length > 1 ? int.tryParse(parts[1]) : null;
    final rows = table(resource);
    final ownQuotes = table('cotizaciones')
        .where((q) => q['clientId'] == clientId)
        .map((q) => q['id'])
        .toSet();
    bool canRead(Map<String, dynamic> row) {
      if (isAdmin) return true;
      return switch (resource) {
        'productos' || 'trabajos' || 'perfil' => true,
        'clientes' => row['id'] == clientId,
        'cotizaciones' || 'visitas' => row['clientId'] == clientId,
        'pagos' || 'pedidos' => ownQuotes.contains(row['quoteId']),
        _ => false,
      };
    }

    if (method == 'GET') {
      if (id == null) return _json(200, rows.where(canRead).toList());
      final row = rows.where((r) => r['id'] == id && canRead(r)).firstOrNull;
      return row == null ? _error(404, 'No encontrado') : _json(200, row);
    }
    if (method == 'POST' && parts.length == 3 && parts[2] == 'cancelar') {
      if (!isAdmin) return _error(403, 'No tienes permiso para esta acción.');
      rows.removeWhere((r) => r['id'] == id);
      return _json(200, {});
    }
    if (method == 'POST') {
      final data = Map<String, dynamic>.from(body);
      if (!isAdmin) {
        if (resource != 'cotizaciones' && resource != 'visitas') {
          return _error(403, 'No tienes permiso para esta acción.');
        }
        data['clientId'] = clientId;
        if (resource == 'visitas') data['status'] = 'Solicitada';
      }
      if (rows.any((r) => r['id'] == data['id'])) {
        return _error(409, 'Ya existe');
      }
      data['id'] ??= _nextId++;
      rows.add(data);
      return _json(201, data);
    }
    if (method == 'PUT') {
      final row = rows.where((r) => r['id'] == id).firstOrNull;
      // El cliente solo edita su ficha o responde su cotización pendiente.
      final quoteResponse =
          resource == 'cotizaciones' &&
          row != null &&
          row['clientId'] == clientId &&
          row['status'] == 'Pendiente' &&
          body.length == 1 &&
          (body['status'] == 'Aprobada' || body['status'] == 'Cancelada');
      if (!isAdmin &&
          !(resource == 'clientes' && id == clientId) &&
          !quoteResponse) {
        return _error(403, 'No tienes permiso para esta acción.');
      }
      if (row == null) return _error(404, 'No encontrado');
      row.addAll(body);
      return _json(200, row);
    }
    if (method == 'DELETE') {
      if (!isAdmin) return _error(403, 'No tienes permiso para esta acción.');
      rows.removeWhere((r) => r['id'] == id);
      return _json(204, null);
    }
    return _error(404, 'No encontrado');
  }
}
