import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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

  static Future<dynamic> request(
    String resource, {
    String method = 'GET',
    int? id,
    String? action,
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/$resource${id == null ? '' : '/$id'}${action == null ? '' : '/$action'}',
    );
    final client = http.Client();
    late final http.Response response;
    try {
      response = await _send(
        client,
        uri,
        method,
        body,
      ).timeout(const Duration(seconds: 10));
    } finally {
      client.close();
    }
    if (response.statusCode >= 400) {
      throw Exception('API $resource: ${response.body}');
    }
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }

  static Future<http.Response> _send(
    http.Client client,
    Uri uri,
    String method,
    Map<String, dynamic>? body,
  ) {
    final headers = {'Content-Type': 'application/json'};
    switch (method) {
      case 'POST':
        return client.post(uri, headers: headers, body: jsonEncode(body));
      case 'PUT':
        return client.put(uri, headers: headers, body: jsonEncode(body));
      case 'DELETE':
        return client.delete(uri, headers: headers);
      default:
        return client.get(uri);
    }
  }
}
