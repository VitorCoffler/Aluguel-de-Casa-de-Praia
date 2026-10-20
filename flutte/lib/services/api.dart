import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../models/reserva.dart';

class ApiException implements Exception {
  final String message;
  final int status;
  const ApiException(this.message, [this.status = 0]);
  @override
  String toString() => message;
}

class Api extends ChangeNotifier {
  static const baseUrl = String.fromEnvironment(
    'API_URL', defaultValue: 'http://localhost:4000',
  );
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  String? _token;
  Usuario? usuario;

  String foto(String url) => '$baseUrl$url';

  Future<Map<String, dynamic>> request(
    String method, String path, [Map<String, dynamic>? body]
  ) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final headers = {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      // Client closed in finally, including timeout paths.
      final client = http.Client();
      late http.Response response;
      try {
        response = await client.send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 20));
      } finally { client.close(); }
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (response.statusCode >= 400) {
        if (response.statusCode == 401 && _token != null) {
          _token = null;
          usuario = null;
          await _storage.delete(key: 'session');
          notifyListeners();
        }
        throw ApiException(data['error'] as String? ?? 'Não foi possível concluir.', response.statusCode);
      }
      return data;
    } on ApiException { rethrow; }
    on TimeoutException { throw const ApiException('O servidor demorou para responder. Tente novamente.'); }
    on http.ClientException { throw const ApiException('Não foi possível conectar à API. Confira se o servidor está ligado.'); }
    on FormatException { throw const ApiException('O servidor retornou uma resposta inválida.'); }
  }

  Future<void> restaurar() async {
    _token = await _storage.read(key: 'session');
    if (_token == null) return;
    try {
      final response = await request('GET', '/auth/me');
      usuario = Usuario.fromJson(response['user'] as Map<String, dynamic>);
      notifyListeners();
    } on ApiException catch (error) {
      if (error.status != 401) rethrow;
    }
  }

  Future<void> autenticar(String route, Map<String, dynamic> body) async {
    final result = await request('POST', route, body);
    final token = result['token'] as String;
    try { await _storage.write(key: 'session', value: token); }
    catch (_) { throw const ApiException('Não foi possível guardar a sessão. No navegador, use localhost ou HTTPS.'); }
    _token = token;
    usuario = Usuario.fromJson(result['user'] as Map<String, dynamic>);
    notifyListeners();
  }

  Future<void> sair() async {
    // Revoga no servidor antes de remover a cópia local.
    await request('POST', '/auth/logout', {});
    await _storage.delete(key: 'session');
    _token = null;
    usuario = null;
    notifyListeners();
  }

  Future<List<Casa>> casas({String query = '', int? preco, int hospedes = 1, bool minhas = false}) async {
    final params = Uri(queryParameters: {
      'q': query, 'guests': '$hospedes', if (preco != null) 'max_price': '$preco',
    }).query;
    final response = await request('GET', minhas ? '/host/houses' : '/houses?$params');
    return (response['houses'] as List)
      .map((item) => Casa.fromJson(item as Map<String, dynamic>)).toList();
  }
}

final api = Api();
