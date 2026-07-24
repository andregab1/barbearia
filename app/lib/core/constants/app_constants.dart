// ==========================================
// CONSTANTS: App
// ==========================================
class AppConstants {
  // ==========================================
  // URL do backend (Railway - produção)
  // ==========================================
  static const String baseUrl = 'https://barbearia-production-3a1c.up.railway.app/api';

  // ==========================================
  // Rotas do app
  // ==========================================
  static const String routeSplash       = '/';
  static const String routeLogin        = '/login';
  static const String routeCadastro     = '/cadastro';
  static const String routeCliente      = '/cliente';
  static const String routeBarbeiro     = '/barbeiro';
  static const String routeAdmin        = '/admin';
  
  // Rotas Home adicionadas para corrigir o erro de compilação
  static const String routeHomeCliente  = '/home-cliente';
  static const String routeHomeBarbeiro = '/home-barbeiro';
  static const String routeHomeAdmin    = '/home-admin';

  // ==========================================
  // Chaves do SharedPreferences
  // ==========================================
  static const String keyAccessToken  = 'access_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyUsuarioId    = 'usuario_id';
  static const String keyUsuarioNome  = 'usuario_nome';
  static const String keyUsuarioRole  = 'usuario_role';
  static const String keyColaboradorId = 'colaborador_id';

  // ==========================================
  // Roles
  // ==========================================
  static const String roleCliente  = 'cliente';
  static const String roleBarbeiro = 'barbeiro';
  static const String roleAdmin    = 'admin';
}