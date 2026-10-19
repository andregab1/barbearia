// ==========================================
// CONTROLLER: Admin
// RF12 - Serviços | RF13 - Relatórios | RF14 - Colaboradores
// ==========================================
import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/auth_service.dart';

class AdminController extends ChangeNotifier {
  Future<int> _tenantId([int? informado]) async =>
      informado ?? await AuthService.getBarbeariaId() ?? 0;
  List<Map<String, dynamic>> _servicos = [];
  List<Map<String, dynamic>> _categorias = [];
  List<Map<String, dynamic>> _colaboradores = [];
  Map<String, dynamic> _relatorio = {};
  Map<String, dynamic> _relatorioMensal = {};

  bool _carregandoServicos = false;
  bool _carregandoColaboradores = false;
  bool _carregandoRelatorio = false;
  bool _salvando = false;
  String _erro = '';
  String _erroColaboradores = '';

  List<Map<String, dynamic>> get servicos => _servicos;
  List<Map<String, dynamic>> get categorias => _categorias;
  List<Map<String, dynamic>> get colaboradores => _colaboradores;
  Map<String, dynamic> get relatorio => _relatorio;
  Map<String, dynamic> get relatorioMensal => _relatorioMensal;
  bool get carregandoServicos => _carregandoServicos;
  bool get carregandoColaboradores => _carregandoColaboradores;
  bool get carregandoRelatorio => _carregandoRelatorio;
  bool get salvando => _salvando;
  String get erro => _erro;
  String get erroColaboradores => _erroColaboradores;

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

  Future<void> carregarCategorias({int? barbeariaId}) async {
    final tenantId = await _tenantId(barbeariaId);
    final result = await ApiService.get('/servicos/categorias/$tenantId');
    if (result['data'] != null) {
      _categorias = (result['data'] as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } else {
      _categorias = [];
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>?> criarCategoria(
      {required String nome, int? barbeariaId}) async {
    final tenantId = await _tenantId(barbeariaId);
    _salvando = true;
    _erro = '';
    notifyListeners();
    final result =
        await ApiService.post('/servicos/categorias/$tenantId', {'nome': nome});
    _salvando = false;
    if (result.containsKey('erro')) {
      _erro = result['erro'];
      notifyListeners();
      return null;
    }
    await carregarCategorias(barbeariaId: tenantId);
    return Map<String, dynamic>.from(result);
  }

  // ==========================================
  // RF12: Criar serviço
  // ==========================================
  Future<bool> criarServico({
    required String nome,
    required double preco,
    required int duracaoMin,
    String? descricao,
    int? categoriaId,
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
      'categoria_id': categoriaId,
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
    int? categoriaId,
  }) async {
    _salvando = true;
    _erro = '';
    notifyListeners();
    final result = await ApiService.put('/servicos/$id', {
      'nome': nome,
      'preco': preco,
      'duracao_min': duracaoMin,
      'descricao': descricao,
      'categoria_id': categoriaId,
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
    _erroColaboradores = '';
    notifyListeners();
    if (tenantId <= 0) {
      _carregandoColaboradores = false;
      _erroColaboradores =
          'Barbearia da sessão não identificada. Saia e entre novamente.';
      _colaboradores = [];
      notifyListeners();
      return;
    }
    final result = await ApiService.get('/colaboradores/gerenciar/$tenantId');
    _carregandoColaboradores = false;
    if (result['erro'] != null) {
      _erroColaboradores = result['erro'].toString();
      _colaboradores = [];
    } else if (result['data'] is List) {
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
    String? cpf,
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
      'cpf': cpf,
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
    String? cpf,
    bool? ativo,
  }) async {
    _salvando = true;
    _erro = '';
    notifyListeners();
    final result = await ApiService.put('/colaboradores/$id', {
      'nome': nome,
      'telefone': telefone,
      'email': email,
      'cpf': cpf,
      'ativo': ativo,
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

  Future<Map<String, dynamic>> carregarRelatorioPeriodo(
      {required String dataIni,
      required String dataFim,
      int? barbeariaId,
      int? profissionalId,
      int? servicoId,
      String? status}) async {
    final tenantId = await _tenantId(barbeariaId);
    _carregandoRelatorio = true;
    _erro = '';
    notifyListeners();
    final params = <String, String>{'data_ini': dataIni, 'data_fim': dataFim};
    if (profissionalId != null)
      params['profissional_id'] = profissionalId.toString();
    if (servicoId != null) params['servico_id'] = servicoId.toString();
    if (status != null && status.isNotEmpty) params['status'] = status;
    final query = params.entries
        .map((entry) => '${entry.key}=${Uri.encodeQueryComponent(entry.value)}')
        .join('&');
    final result = await ApiService.get('/relatorios/$tenantId/periodo?$query');
    _carregandoRelatorio = false;
    if (result.containsKey('erro')) {
      _erro = result['erro'].toString();
      notifyListeners();
      return result;
    }
    if (result['atendimentos'] is! List) {
      _erro =
          'A API de relatórios não retornou os agendamentos do período. Reinicie o servidor para aplicar a versão atual.';
      notifyListeners();
      return {'erro': _erro};
    }
    _relatorio = result;
    notifyListeners();
    return result;
  }

  void limpar() {
    _erro = '';
    notifyListeners();
  }
}
