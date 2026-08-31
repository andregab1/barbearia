// ==========================================
// CONSTANTS: App
// ==========================================
class AppConstants {
  // ==========================================
  // URL do backend
  // Local: http://10.0.2.2:3000/api (emulador Android) ou http://localhost:3000/api (web/desktop)
  // Produção: https://barbearia-n6jj.onrender.com/api
  // ==========================================
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api',
  );

  // ==========================================
  // Rotas do app
  // ==========================================
  static const String routeSplash = '/splash';
  static const String routeLogin = '/login';
  static const String routeCadastro = '/cadastro';

  // Rotas Home adicionadas para corrigir o erro de compilação
  static const String routeHomeCliente = '/home-cliente';
  static const String routeHomeBarbeiro = '/home-barbeiro';
  static const String routeHomeAdmin = '/home-admin';

  // ==========================================
  // Chaves do SharedPreferences
  // ==========================================
  static const String keyAccessToken = 'access_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyUsuarioId = 'usuario_id';
  static const String keyUsuarioNome = 'usuario_nome';
  static const String keyUsuarioRole = 'usuario_role';
  static const String keyColaboradorId = 'colaborador_id';
  static const String keyBarbeariaId = 'barbearia_id';

  // ==========================================
  // Roles
  // ==========================================
  static const String roleCliente = 'cliente';
  static const String roleBarbeiro = 'barbeiro';
  static const String roleAdmin = 'admin';
}
