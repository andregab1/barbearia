// ==========================================
// SERVICE: Autenticação e sessão
// RF01 - Cadastro | RF02 - Login | RNF01 - Segurança
// ==========================================
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import 'api_service.dart';

class AuthService {
  // ==========================================
  // RF02: Login do usuário
  // ==========================================
  static Future<Map<String, dynamic>> login(String login, String senha) async {
    final result = await ApiService.post(
      '/auth/login',
      {'login': login, 'senha': senha},
      auth: false,
    );

    if (result.containsKey('access_token')) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          AppConstants.keyAccessToken, result['access_token']);
      await prefs.setString(
          AppConstants.keyRefreshToken, result['refresh_token']);
      await prefs.setInt(AppConstants.keyUsuarioId, result['usuario']['id']);
      await prefs.setString(
          AppConstants.keyUsuarioNome, result['usuario']['nome']);
      await prefs.setString(
          AppConstants.keyUsuarioRole, result['usuario']['role']);
      if (result['barbearia_id'] != null) {
        await prefs.setInt(AppConstants.keyBarbeariaId, result['barbearia_id']);
      }
    }

    return result;
  }

  // ==========================================
  // RF01: Cadastro de novo cliente
  // ==========================================
  static Future<Map<String, dynamic>> cadastrar(
      String nome, String telefone, String senha,
      {String? email, String? username}) async {
    return ApiService.post(
      '/auth/cadastrar',
      {
        'nome': nome,
        'telefone': telefone,
        'senha': senha,
        'email': email,
        'username': username,
      },
      auth: false,
    );
  }

  static Future<Map<String, dynamic>> cadastrarProprietario({
    required String nomeProprietario,
    required String nomeBarbearia,
    required String telefone,
    required String email,
    required String senha,
  }) {
    return ApiService.post(
      '/auth/register-owner',
      {
        'owner_name': nomeProprietario,
        'shop_name': nomeBarbearia,
        'phone': telefone,
        'email': email,
        'password': senha,
      },
      auth: false,
    );
  }

  // ==========================================
  // RNF01: Logout - limpa sessão local
  // ==========================================
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString(AppConstants.keyRefreshToken);

    await ApiService.post('/auth/logout', {'refresh_token': refreshToken});

    // Preserva logo e cores para manter tema mesmo após logout
    final logoUrl = prefs.getString('logo_url');
    final corPrimaria = prefs.getString('cor_primaria');

    await prefs.clear();

    if (logoUrl != null) await prefs.setString('logo_url', logoUrl);
    if (corPrimaria != null) await prefs.setString('cor_primaria', corPrimaria);
  }

  // ==========================================
  // RNF01: Verifica se há sessão ativa
  // ==========================================
  static Future<String?> getRoleAtual() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.keyUsuarioRole);
  }

  static Future<bool> estaLogado() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.keyAccessToken) != null;
  }

  static Future<int?> getUsuarioId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(AppConstants.keyUsuarioId);
  }

  static Future<String?> getUsuarioNome() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.keyUsuarioNome);
  }

  static Future<int?> getBarbeariaId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(AppConstants.keyBarbeariaId);
  }
}
