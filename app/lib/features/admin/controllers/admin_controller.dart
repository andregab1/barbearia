// ==========================================
// CONTROLLER: Admin
// RF12 - Serviços | RF13 - Relatórios | RF14 - Colaboradores
// ==========================================
import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';

class AdminController extends ChangeNotifier {
  List<Map<String, dynamic>> _servicos      = [];
  List<Map<String, dynamic>> _colaboradores = [];
  Map<String, dynamic>       _relatorio        = {};
  Map<String, dynamic>       _relatorioMensal  = {};
  Map<String, dynamic>       _relatorioPeriodo = {};

  bool   _carregandoServicos      = false;
  bool   _carregandoColaboradores = false;
  bool   _carregandoRelatorio     = false;
  bool   _salvando                = false;
  String _erro                    = '';
  String _sucesso                 = '';

  List<Map<String, dynamic>> get servicos            => _servicos;
  List<Map<String, dynamic>> get colaboradores       => _colaboradores;
  Map<String, dynamic>       get relatorio           => _relatorio;
  Map<String, dynamic>       get relatorioMensal     => _relatorioMensal;
  Map<String, dynamic>       get relatorioPeriodo    => _relatorioPeriodo;
  bool   get carregandoServicos      => _carregandoServicos;
  bool   get carregandoColaboradores => _carregandoColaboradores;
  bool   get carregandoRelatorio     => _carregandoRelatorio;
  bool   get salvando                => _salvando;
  String get erro                    => _erro;
  String get sucesso                 => _sucesso;

  // ==========================================
  // RF12: Listar serviços
  // ==========================================
  Future<void> carregarServicos({int barbeariaId = 1}) async {
    _carregandoServicos = true;
    notifyListeners();
    final result = await ApiService.get('/servicos/$barbeariaId', auth: false);
    _carregandoServicos = false;
    if (result['data'] != null) {
      _servicos = (result['data'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
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
    required int    duracaoMin,
    String?         descricao,
    int             barbeariaId = 1,
  }) async {
    _salvando = true;
    _erro     = '';
    notifyListeners();
    final result = await ApiService.post('/servicos/$barbeariaId', {
      'nome': nome, 'preco': preco, 'duracao_min': duracaoMin, 'descricao': descricao,
    });
    _salvando = false;
    if (result.containsKey('erro')) {
      _erro = result['erro'];
      notifyListeners();
      return false;
    }
    _sucesso = 'Serviço criado!';
    await carregarServicos(barbeariaId: barbeariaId);
    return true;
  }

  // ==========================================
  // RF12: Atualizar serviço
  // ==========================================
  Future<bool> atualizarServico({
    required int    id,
    required String nome,
    required double preco,
    required int    duracaoMin,
    String?         descricao,
  }) async {
    _salvando = true;
    _erro     = '';
    notifyListeners();
    final result = await ApiService.put('/servicos/$id', {
      'nome': nome, 'preco': preco, 'duracao_min': duracaoMin, 'descricao': descricao,
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
  Future<void> carregarColaboradores({int barbeariaId = 1}) async {
    _carregandoColaboradores = true;
    notifyListeners();
    final result = await ApiService.get('/colaboradores/$barbeariaId', auth: false);
    _carregandoColaboradores = false;
    if (result['data'] != null) {
      _colaboradores = (result['data'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
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
    int barbeariaId = 1,
  }) async {
    _salvando = true;
    _erro     = '';
    notifyListeners();
    final result = await ApiService.post('/colaboradores/$barbeariaId', {
      'nome': nome, 'telefone': telefone, 'senha': senha,
    });
    _salvando = false;
    if (result.containsKey('erro')) {
      _erro = result['erro'];
      notifyListeners();
      return false;
    }
    _sucesso = 'Colaborador cadastrado!';
    await carregarColaboradores(barbeariaId: barbeariaId);
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
  Future<void> carregarRelatorio({int barbeariaId = 1, String? data}) async {
    _carregandoRelatorio = true;
    notifyListeners();
    final query  = data != null ? '?data=$data' : '';
    final result = await ApiService.get('/relatorios/$barbeariaId/diario$query');
    _carregandoRelatorio = false;
    if (!result.containsKey('erro')) _relatorio = result;
    notifyListeners();
  }

  // ==========================================
  // RF13: Relatório mensal
  // ==========================================
  Future<void> carregarRelatorioMensal({int barbeariaId = 1, int? ano, int? mes}) async {
    _carregandoRelatorio = true;
    notifyListeners();
    String query = '';
    if (ano != null) query  = '?ano=$ano';
    if (mes != null) query += '${query.isEmpty ? '?' : '&'}mes=$mes';
    final result = await ApiService.get('/relatorios/$barbeariaId/mensal$query');
    _carregandoRelatorio = false;
    if (!result.containsKey('erro')) _relatorioMensal = result;
    notifyListeners();
  }

  // ==========================================
  // RF13: Relatório por período
  // ==========================================
  Future<void> carregarRelatorioPeriodo({
    int    barbeariaId = 1,
    required String dataIni,
    required String dataFim,
  }) async {
    _carregandoRelatorio = true;
    notifyListeners();
    final result = await ApiService.get(
      '/relatorios/$barbeariaId/periodo?data_ini=$dataIni&data_fim=$dataFim',
    );
    _carregandoRelatorio = false;
    if (!result.containsKey('erro')) _relatorioPeriodo = result;
    notifyListeners();
  }

  void limpar() {
    _erro    = '';
    _sucesso = '';
    notifyListeners();
  }
}