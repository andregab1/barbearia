// ==========================================
// SERVICE: Comunicação com a API REST
// Com refresh automático de token JWT
// ==========================================
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class ApiService {
  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (auth) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.keyAccessToken);
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // ==========================================
  // Refresh automático quando token expira
  // ==========================================
  static Future<bool> _refreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString(AppConstants.keyRefreshToken);
      if (refreshToken == null) return false;

      final response = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh_token': refreshToken}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['access_token'] != null) {
          await prefs.setString(
              AppConstants.keyAccessToken, data['access_token']);
          if (data['refresh_token'] != null) {
            await prefs.setString(
              AppConstants.keyRefreshToken,
              data['refresh_token'],
            );
          }
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // Processa resposta — se 401, tenta refresh e reenvia
  static Future<Map<String, dynamic>> _processarComRefresh(
    Future<http.Response> Function() requisicao,
    Future<http.Response> Function() requisicaoRetry,
    {required bool permiteRefresh,}
  ) async {
    try {
      final response = await requisicao();
      if (response.statusCode == 401) {
        if (!permiteRefresh) return _processar(response);
        final refreshOk = await _refreshToken();
        if (refreshOk) {
          final retry = await requisicaoRetry();
          return _processar(retry);
        }
        // Refresh falhou — força logout
        return {
          'erro': 'Sessão expirada. Faça login novamente.',
          '_logout': true
        };
      }
      return _processar(response);
    } catch (e) {
      return {'erro': 'Sem conexão com o servidor.'};
    }
  }

  static Future<Map<String, dynamic>> get(String endpoint,
      {bool auth = true}) async {
    return _processarComRefresh(
      () async => http
          .get(
            Uri.parse('${AppConstants.baseUrl}$endpoint'),
            headers: await _headers(auth: auth),
          )
          .timeout(const Duration(seconds: 15)),
      () async => http
          .get(
            Uri.parse('${AppConstants.baseUrl}$endpoint'),
            headers: await _headers(auth: auth),
          )
          .timeout(const Duration(seconds: 15)),
      permiteRefresh: auth,
    );
  }

  static Future<Map<String, dynamic>> post(
      String endpoint, Map<String, dynamic> body,
      {bool auth = true}) async {
    return _processarComRefresh(
      () async => http
          .post(
            Uri.parse('${AppConstants.baseUrl}$endpoint'),
            headers: await _headers(auth: auth),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15)),
      () async => http
          .post(
            Uri.parse('${AppConstants.baseUrl}$endpoint'),
            headers: await _headers(auth: auth),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15)),
      permiteRefresh: auth,
    );
  }

  static Future<Map<String, dynamic>> put(
      String endpoint, Map<String, dynamic> body) async {
    return _processarComRefresh(
      () async => http
          .put(
            Uri.parse('${AppConstants.baseUrl}$endpoint'),
            headers: await _headers(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15)),
      () async => http
          .put(
            Uri.parse('${AppConstants.baseUrl}$endpoint'),
            headers: await _headers(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15)),
      permiteRefresh: true,
    );
  }

  static Future<Map<String, dynamic>> patch(
      String endpoint, Map<String, dynamic> body) async {
    return _processarComRefresh(
      () async => http
          .patch(
            Uri.parse('${AppConstants.baseUrl}$endpoint'),
            headers: await _headers(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15)),
      () async => http
          .patch(
            Uri.parse('${AppConstants.baseUrl}$endpoint'),
            headers: await _headers(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15)),
      permiteRefresh: true,
    );
  }

  static Future<Map<String, dynamic>> delete(String endpoint) async {
    return _processarComRefresh(
      () async => http
          .delete(
            Uri.parse('${AppConstants.baseUrl}$endpoint'),
            headers: await _headers(),
          )
          .timeout(const Duration(seconds: 15)),
      () async => http
          .delete(
            Uri.parse('${AppConstants.baseUrl}$endpoint'),
            headers: await _headers(),
          )
          .timeout(const Duration(seconds: 15)),
      permiteRefresh: true,
    );
  }

  static Map<String, dynamic> _processar(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return data is Map<String, dynamic> ? data : {'data': data};
      }
      return {
        'erro': data['message'] ?? data['erro'] ?? 'Erro desconhecido.',
        if (data['code'] != null) 'code': data['code'],
        if (data['fields'] != null) 'fields': data['fields'],
        if (data['requestId'] != null) 'requestId': data['requestId'],
      };
    } catch (_) {
      return {'erro': 'Erro ao processar resposta do servidor.'};
    }
  }
}
