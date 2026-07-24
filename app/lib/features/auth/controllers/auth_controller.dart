// ==========================================
// CONTROLLER: Autenticação
// RF01 - Cadastro | RF02 - Login
// ==========================================
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/constants/app_constants.dart';

class AuthController extends ChangeNotifier {
  bool    _estaLogado   = false;
  String  _role         = '';
  bool    _carregando   = false;
  String  _erro         = '';
  String? _nomeUsuario;

  bool    get estaLogado   => _estaLogado;
  String  get role         => _role;
  bool    get carregando   => _carregando;
  String  get erro         => _erro;
  String? get nomeUsuario  => _nomeUsuario;

  void atualizarNome(String novoNome) {
    _nomeUsuario = novoNome;
    notifyListeners();
  }

  AuthController() {
    _verificarSessao();
  }

  // ==========================================
  // RNF01: Verifica sessão salva ao iniciar
  // ==========================================
  Future<void> _verificarSessao() async {
    final logado = await AuthService.estaLogado();
    final role   = await AuthService.getRoleAtual();
    final nome   = await AuthService.getUsuarioNome();
    _estaLogado  = logado;
    _role        = role ?? '';
    _nomeUsuario = nome;
    notifyListeners();
  }

  // ==========================================
  // RF02: Login
  // ==========================================
  Future<bool> login(String loginInput, String senha) async {
    _carregando = true;
    _erro       = '';
    notifyListeners();

    final result = await AuthService.login(loginInput, senha);

    _carregando = false;
    if (result.containsKey('erro')) {
      _erro = result['erro'];
      notifyListeners();
      return false;
    }

    _estaLogado  = true;
    _role        = result['usuario']['role'];
    _nomeUsuario = result['usuario']['nome'];

    // Salva colaborador_id se for barbeiro ou admin
    if (result['colaborador_id'] != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(AppConstants.keyColaboradorId, result['colaborador_id']);
    }

    notifyListeners();
    return true;
  }

  // ==========================================
  // RF01: Cadastro de cliente
  // ==========================================
  Future<bool> cadastrar(String nome, String telefone, String senha, {String? email}) async {
    _carregando = true;
    _erro       = '';
    notifyListeners();

    final result = await AuthService.cadastrar(nome, telefone, senha, email: email);

    _carregando = false;
    if (result.containsKey('erro')) {
      _erro = result['erro'];
      notifyListeners();
      return false;
    }

    notifyListeners();
    return true;
  }

  // ==========================================
  // RNF01: Logout
  // ==========================================
  Future<void> logout() async {
    await AuthService.logout();
    _estaLogado  = false;
    _role        = '';
    _nomeUsuario = null;
    notifyListeners();
  }

  void limparErro() {
    _erro = '';
    notifyListeners();
  }
}