import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

/// Client HTTP de l'API Tontine BF : JSON, jeton Sanctum et erreurs traduites en [ApiException].
class ApiClient {
  ApiClient({required this.baseUrl, http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  String? token;

  /// Appelé quand le serveur refuse le jeton (expiré ou révoqué).
  void Function()? onUnauthorized;

  Future<dynamic> get(String path) => _send('GET', path);

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) => _send('POST', path, body);

  Future<dynamic> put(String path, Map<String, dynamic> body) => _send('PUT', path, body);

  Future<dynamic> patch(String path, Map<String, dynamic> body) => _send('PATCH', path, body);

  Future<dynamic> _send(String method, String path, [Map<String, dynamic>? body]) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'))..headers['Accept'] = 'application/json';

    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final response = await _perform(request);
    final decoded = _decode(response);

    if (response.statusCode >= 200 && response.statusCode < 300) return decoded;
    if (response.statusCode == 401 && token != null) onUnauthorized?.call();

    throw ApiException.fromResponse(response.statusCode, decoded);
  }

  Future<http.Response> _perform(http.Request request) async {
    try {
      final streamed = await _http.send(request).timeout(const Duration(seconds: 20));
      return await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw const ApiException('Le serveur ne répond pas. Vérifiez votre connexion et réessayez.');
    } on Exception {
      throw const ApiException('Connexion impossible. Vérifiez que vous avez accès à Internet.');
    }
  }

  static Object? _decode(http.Response response) {
    if (response.bodyBytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      return null;
    }
  }
}
