// ==========================================
// CONTROLLER: Agendamentos do Cliente
// RF06 - Agendar | RF07 - Cancelar
// ==========================================
import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';

class AgendamentoController extends ChangeNotifier {
  List<Map<String, dynamic>> _barbearias = [];
  Map<String, dynamic>? _barbeariaSelecionada;
  List<Map<String, dynamic>> _servicos = [];
  List<Map<String, dynamic>> _colaboradores = [];
  List<Map<String, dynamic>> _horariosDisp = [];
  List<Map<String, dynamic>> _meusAgendamentos = [];
  List<Map<String, dynamic>> _historico = [];

  bool _carregandoServicos = false;
  bool _carregandoBarbearias = false;
  bool _carregandoColaboradores = false;
  bool _carregandoHorarios = false;
  bool _carregandoAgendamentos = false;
  bool _salvando = false;
  String _erro = '';

  List<Map<String, dynamic>> get barbearias => _barbearias;
  Map<String, dynamic>? get barbeariaSelecionada => _barbeariaSelecionada;

  List<Map<String, dynamic>> get servicos => _servicos;
  List<Map<String, dynamic>> get colaboradores => _colaboradores;
  List<Map<String, dynamic>> get horariosDisp => _horariosDisp;
  List<Map<String, dynamic>> get meusAgendamentos => _meusAgendamentos;
  List<Map<String, dynamic>> get historico => _historico;
  bool get carregandoServicos => _carregandoServicos;
  bool get carregandoBarbearias => _carregandoBarbearias;
  bool get carregandoColaboradores => _carregandoColaboradores;
  bool get carregandoHorarios => _carregandoHorarios;
  bool get carregandoAgendamentos => _carregandoAgendamentos;
  bool get salvando => _salvando;
  String get erro => _erro;

  Future<void> carregarBarbearias({String busca = ''}) async {
    _carregandoBarbearias = true;
    notifyListeners();
    final query = busca.trim().isEmpty
        ? ''
        : '?busca=${Uri.encodeQueryComponent(busca.trim())}';
    final result = await ApiService.get('/barbearias$query', auth: false);
    _carregandoBarbearias = false;
    final raw = result['data'];
    _barbearias = raw is List
        ? raw.map((item) => Map<String, dynamic>.from(item)).toList()
        : [];

    if (_barbeariaSelecionada == null) {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getInt(AppConstants.keyBarbeariaId);
      if (savedId != null) {
        final matches = _barbearias.where((item) => item['id'] == savedId);
        if (matches.isNotEmpty) _barbeariaSelecionada = matches.first;
      }
    }
    notifyListeners();
    if (_barbeariaSelecionada != null &&
        _servicos.isEmpty &&
        _colaboradores.isEmpty) {
      await Future.wait([
        carregarServicos(barbeariaId: _barbeariaSelecionada!['id']),
        carregarColaboradores(barbeariaId: _barbeariaSelecionada!['id']),
      ]);
    }
  }

  Future<void> selecionarBarbearia(Map<String, dynamic> barbearia) async {
    _barbeariaSelecionada = barbearia;
    _servicos = [];
    _colaboradores = [];
    _horariosDisp = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.keyBarbeariaId, barbearia['id'] as int);
    notifyListeners();
    await Future.wait([
      carregarServicos(barbeariaId: barbearia['id']),
      carregarColaboradores(barbeariaId: barbearia['id']),
    ]);
  }

  Future<void> trocarBarbearia() async {
    _barbeariaSelecionada = null;
    _servicos = [];
    _colaboradores = [];
    _horariosDisp = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keyBarbeariaId);
    notifyListeners();
  }

  // RF12: Carrega serviços (público)
  Future<void> carregarServicos({required int barbeariaId}) async {
    _carregandoServicos = true;
    notifyListeners();
    final result = await ApiService.get('/servicos/$barbeariaId', auth: false);
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

  // RF14: Carrega colaboradores (público)
  Future<void> carregarColaboradores({required int barbeariaId}) async {
    _carregandoColaboradores = true;
    notifyListeners();
    final result =
        await ApiService.get('/colaboradores/$barbeariaId', auth: false);
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
  // RF05: Carrega horários disponíveis
  // Suporta duração total (múltiplos serviços)
  // ==========================================
  Future<void> carregarHorarios(
    int colaboradorId,
    String data, {
    int? duracaoTotal,
  }) async {
    _carregandoHorarios = true;
    _horariosDisp = [];
    notifyListeners();

    String endpoint = '/agenda/disponiveis/$colaboradorId?data=$data';
    if (duracaoTotal != null) {
      endpoint += '&duracao_total=$duracaoTotal';
    }

    final result = await ApiService.get(endpoint);
    _carregandoHorarios = false;

    if (result['disponiveis'] != null) {
      _horariosDisp = (result['disponiveis'] as List)
          .map((h) => {'hora': h.toString()})
          .toList();
    }
    notifyListeners();
  }

  // ==========================================
  // RF06: Criar agendamento(s)
  // Suporta múltiplos serviços sequenciais
  // ==========================================
  Future<bool> agendar({
    required int colaboradorId,
    required int servicoId,
    List<int>? servicosIds,
    required String dataHora,
    String? observacao,
  }) async {
    _salvando = true;
    _erro = '';
    notifyListeners();

    final body = <String, dynamic>{
      'colaborador_id': colaboradorId,
      'servico_id': servicoId,
      'servicos_ids': servicosIds ?? [servicoId],
      'data_hora': dataHora,
    };

    if (observacao != null) body['observacao'] = observacao;

    final result = await ApiService.post('/agendamentos', body);
    _salvando = false;

    if (result.containsKey('erro')) {
      _erro = result['erro'];
      notifyListeners();
      return false;
    }

    notifyListeners();
    return true;
  }

  // RF06: Agenda confirmada (próximos)
  Future<void> carregarMeusAgendamentos() async {
    _carregandoAgendamentos = true;
    notifyListeners();
    final result = await ApiService.get('/agendamentos/meus?tipo=agenda');
    _carregandoAgendamentos = false;
    if (result['data'] != null) {
      _meusAgendamentos = (result['data'] as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } else {
      _meusAgendamentos = [];
    }
    notifyListeners();
  }

  // RF10: Histórico (concluídos e cancelados)
  Future<void> carregarHistorico() async {
    _carregandoAgendamentos = true;
    notifyListeners();
    final result = await ApiService.get('/agendamentos/meus?tipo=historico');
    _carregandoAgendamentos = false;
    if (result['data'] != null) {
      _historico = (result['data'] as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } else {
      _historico = [];
    }
    notifyListeners();
  }

  // RF07: Cancelar agendamento
  Future<bool> cancelar(int agendamentoId) async {
    _erro = '';
    notifyListeners();
    final result =
        await ApiService.patch('/agendamentos/$agendamentoId/cancelar', {});
    if (result.containsKey('erro')) {
      _erro = result['erro'];
      notifyListeners();
      return false;
    }
    await carregarMeusAgendamentos();
    return true;
  }
}
