// ==========================================
// CONTROLLER: Admin
// RF12 - Serviços | RF13 - Relatórios | RF14 - Colaboradores
// ==========================================
import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/auth_service.dart';

class AdminController extends ChangeNotifier {
  Future<int> _tenantId([int? informado]) async =>
      informado ?? await AuthService.getBarbeariaId() ?? 1;
  List<Map<String, dynamic>> _servicos = [];
  List<Map<String, dynamic>> _colaboradores = [];
  Map<String, dynamic> _relatorio = {};
  Map<String, dynamic> _relatorioMensal = {};

  bool _carregandoServicos = false;
  bool _carregandoColaboradores = false;
  bool _carregandoRelatorio = false;
  bool _salvando = false;
  String _erro = '';

  List<Map<String, dynamic>> get servicos => _servicos;
  List<Map<String, dynamic>> get colaboradores => _colaboradores;
  Map<String, dynamic> get relatorio => _relatorio;
  Map<String, dynamic> get relatorioMensal => _relatorioMensal;
  bool get carregandoServicos => _carregandoServicos;
  bool get carregandoColaboradores => _carregandoColaboradores;
  bool get carregandoRelatorio => _carregandoRelatorio;
  bool get salvando => _salvando;
  String get erro => _erro;

  // ==========================================
  // RF12: Listar serviços
  // ==========================================
  Future<void> carregarServicos({int? barbeariaId}) async {
    final tenantId = await _tenantId(barbeariaId);
    _carregandoServicos = true;
    notifyListeners();
    final result = await ApiService.get('/servicos/$tenantId', auth: false);
    _carregandoServicos = false;
    if (result['data'] != null) {
      _servicos = (result['data'] as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } else {
      _servicos = [];
    }
    notifyListeners();
  }

  // ==========================================
  // RF12: Criar serviço
  // ==========================================
  Future<bool> criarServico({
    required String nome,
    required double preco,
    required int duracaoMin,
    String? descricao,
    int? barbeariaId,
  }) async {
    final tenantId = await _tenantId(barbeariaId);
    _salvando = true;
    _erro = '';
    notifyListeners();
    final result = await ApiService.post('/servicos/$tenantId', {
      'nome': nome,
      'preco': preco,
      'duracao_min': duracaoMin,
      'descricao': descricao,
    });
    _salvando = false;
    if (result.containsKey('erro')) {
      _erro = result['erro'];
      notifyListeners();
      return false;
    }
    await carregarServicos(barbeariaId: tenantId);
    return true;
  }

  // ==========================================
  // RF12: Atualizar serviço
  // ==========================================
  Future<bool> atualizarServico({
    required int id,
    required String nome,
    required double preco,
    required int duracaoMin,
    String? descricao,
  }) async {
    _salvando = true;
    _erro = '';
    notifyListeners();
    final result = await ApiService.put('/servicos/$id', {
      'nome': nome,
      'preco': preco,
      'duracao_min': duracaoMin,
      'descricao': descricao,
    });
    _salvando = false;
    if (result.containsKey('erro')) {
      _erro = result['erro'];
      notifyListeners();
      return false;
    }
    await carregarServicos();
    return true;
  }

  // ==========================================
  // RF12: Desativar serviço
  // ==========================================
  Future<void> desativarServico(int id) async {
    final result = await ApiService.delete('/servicos/$id');
    if (!result.containsKey('erro')) await carregarServicos();
  }

  // ==========================================
  // RF14: Listar colaboradores
  // ==========================================
  Future<void> carregarColaboradores({int? barbeariaId}) async {
    final tenantId = await _tenantId(barbeariaId);
    _carregandoColaboradores = true;
    notifyListeners();
    final result = await ApiService.get('/colaboradores/gerenciar/$tenantId');
    _carregandoColaboradores = false;
    if (result['data'] != null) {
      _colaboradores = (result['data'] as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } else {
      _colaboradores = [];
    }
    notifyListeners();
  }

  // ==========================================
  // RF14: Cadastrar colaborador
  // ==========================================
  Future<bool> cadastrarColaborador({
    required String nome,
    required String telefone,
    required String senha,
    int? barbeariaId,
  }) async {
    final tenantId = await _tenantId(barbeariaId);
    _salvando = true;
    _erro = '';
    notifyListeners();
    final result = await ApiService.post('/colaboradores/$tenantId', {
      'nome': nome,
      'telefone': telefone,
      'senha': senha,
    });
    _salvando = false;
    if (result.containsKey('erro')) {
      _erro = result['erro'];
      notifyListeners();
      return false;
    }
    await carregarColaboradores(barbeariaId: tenantId);
    return true;
  }

  Future<bool> atualizarColaborador({
    required int id,
    required String nome,
    required String telefone,
    String? email,
  }) async {
    _salvando = true;
    _erro = '';
    notifyListeners();
    final result = await ApiService.put('/colaboradores/$id', {
      'nome': nome,
      'telefone': telefone,
      'email': email,
    });
    _salvando = false;
    if (result.containsKey('erro')) {
      _erro = result['erro'];
      notifyListeners();
      return false;
    }
    await carregarColaboradores();
    return true;
  }

  Future<bool> alterarStatusColaborador(int id, bool ativo) async {
    _erro = '';
    final result = await ApiService.patch(
      '/colaboradores/$id/status',
      {'ativo': ativo},
    );
    if (result.containsKey('erro')) {
      _erro = result['erro'];
      notifyListeners();
      return false;
    }
    await carregarColaboradores();
    return true;
  }

  // ==========================================
  // RF14: Remover colaborador
  // ==========================================
  Future<bool> removerColaborador(int id) async {
    _erro = '';
    notifyListeners();
    final result = await ApiService.delete('/colaboradores/$id');
    if (result.containsKey('erro')) {
      _erro = result['erro'];
      notifyListeners();
      return false;
    }
    await carregarColaboradores();
    return true;
  }

  // ==========================================
  // RF13: Relatório diário
  // ==========================================
  Future<void> carregarRelatorio({int? barbeariaId, String? data}) async {
    final tenantId = await _tenantId(barbeariaId);
    _carregandoRelatorio = true;
    notifyListeners();
    final query = data != null ? '?data=$data' : '';
    final result = await ApiService.get('/relatorios/$tenantId/diario$query');
    _carregandoRelatorio = false;
    if (!result.containsKey('erro')) _relatorio = result;
    notifyListeners();
  }

  // ==========================================
  // RF13: Relatório mensal
  // ==========================================
  Future<void> carregarRelatorioMensal(
      {int? barbeariaId, int? ano, int? mes}) async {
    final tenantId = await _tenantId(barbeariaId);
    _carregandoRelatorio = true;
    notifyListeners();
    String query = '';
    if (ano != null) query = '?ano=$ano';
    if (mes != null) query += '${query.isEmpty ? '?' : '&'}mes=$mes';
    final result = await ApiService.get('/relatorios/$tenantId/mensal$query');
    _carregandoRelatorio = false;
    if (!result.containsKey('erro')) _relatorioMensal = result;
    notifyListeners();
  }

  void limpar() {
    _erro = '';
    notifyListeners();
  }
}
