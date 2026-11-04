import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Error devuelto por el servidor (con su mensaje para el usuario).
class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  static String get baseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) {
      return configured;
    }
    if (kIsWeb) return 'http://localhost:5000';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:5000';
      case TargetPlatform.iOS:
        return 'http://localhost:5000';
      default:
        return 'http://localhost:5000';
    }
  }

  /// Token de la sesión actual; se manda en cada petición.
  static String? token;

  /// Fábrica del cliente HTTP (las pruebas la sustituyen por un servidor falso).
  static http.Client Function() clientFactory = http.Client.new;

  static Future<dynamic> request(
    String resource, {
    String method = 'GET',
    int? id,
    String? action,
    Map<String, dynamic>? body,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/$resource${id == null ? '' : '/$id'}${action == null ? '' : '/$action'}',
    );
    final client = clientFactory();
    late final http.Response response;
    try {
      response = await _send(client, uri, method, body).timeout(timeout);
    } finally {
      client.close();
    }
    if (response.statusCode >= 400) {
      throw ApiException(response.statusCode, _errorMessage(response));
    }
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }

  static String _errorMessage(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map && data['error'] is String) return data['error'];
    } catch (_) {}
    return 'Error del servidor (${response.statusCode})';
  }

  static Future<http.Response> _send(
    http.Client client,
    Uri uri,
    String method,
    Map<String, dynamic>? body,
  ) {
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    switch (method) {
      case 'POST':
        return client.post(uri, headers: headers, body: jsonEncode(body));
      case 'PUT':
        return client.put(uri, headers: headers, body: jsonEncode(body));
      case 'DELETE':
        return client.delete(uri, headers: headers);
      default:
        return client.get(uri, headers: headers);
    }
  }
}
