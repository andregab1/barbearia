// ==========================================
// CONTROLLER: Agendamentos do Cliente
// RF06 - Agendar | RF07 - Cancelar
// ==========================================
import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';

class AgendamentoController extends ChangeNotifier {
  List<Map<String, dynamic>> _servicos            = [];
  List<Map<String, dynamic>> _colaboradores       = [];
  List<Map<String, dynamic>> _horariosDisp        = [];
  List<Map<String, dynamic>> _meusAgendamentos    = [];
  List<Map<String, dynamic>> _historico           = [];

  bool   _carregandoServicos      = false;
  bool   _carregandoColaboradores = false;
  bool   _carregandoHorarios      = false;
  bool   _carregandoAgendamentos  = false;
  bool   _salvando                = false;
  String _erro                    = '';
  String _sucesso                 = '';

  List<Map<String, dynamic>> get servicos            => _servicos;
  List<Map<String, dynamic>> get colaboradores       => _colaboradores;
  List<Map<String, dynamic>> get horariosDisp        => _horariosDisp;
  List<Map<String, dynamic>> get meusAgendamentos    => _meusAgendamentos;
  List<Map<String, dynamic>> get historico           => _historico;
  bool   get carregandoServicos      => _carregandoServicos;
  bool   get carregandoColaboradores => _carregandoColaboradores;
  bool   get carregandoHorarios      => _carregandoHorarios;
  bool   get carregandoAgendamentos  => _carregandoAgendamentos;
  bool   get salvando                => _salvando;
  String get erro                    => _erro;
  String get sucesso                 => _sucesso;

  // RF12: Carrega serviços (público)
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

  // RF14: Carrega colaboradores (público)
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
  // RF05: Carrega horários disponíveis
  // Suporta duração total (múltiplos serviços)
  // ==========================================
  Future<void> carregarHorarios(
    int colaboradorId,
    String data, {
    int? servicoId,
    int? duracaoTotal,
  }) async {
    _carregandoHorarios = true;
    _horariosDisp       = [];
    notifyListeners();

    String endpoint = '/agenda/disponiveis/$colaboradorId?data=$data';
    if (duracaoTotal != null) {
      endpoint += '&duracao_total=$duracaoTotal';
    } else if (servicoId != null) {
      endpoint += '&servico_id=$servicoId';
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
    required int    colaboradorId,
    required int    servicoId,
    required String dataHora,
    int?            duracaoTotal,
    double?         valorTotal,
    String?         observacao,
  }) async {
    _salvando = true;
    _erro     = '';
    _sucesso  = '';
    notifyListeners();

    final body = <String, dynamic>{
      'colaborador_id': colaboradorId,
      'servico_id':     servicoId,
      'data_hora':      dataHora,
    };

    if (duracaoTotal != null) body['duracao_override'] = duracaoTotal;
    if (valorTotal   != null) body['valor_override']   = valorTotal;
    if (observacao   != null) body['observacao']        = observacao;

    final result = await ApiService.post('/agendamentos', body);
    _salvando = false;

    if (result.containsKey('erro')) {
      _erro = result['erro'];
      notifyListeners();
      return false;
    }

    _sucesso = 'Agendamento realizado!';
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
    final result = await ApiService.patch('/agendamentos/$agendamentoId/cancelar', {});
    if (result.containsKey('erro')) {
      _erro = result['erro'];
      notifyListeners();
      return false;
    }
    await carregarMeusAgendamentos();
    return true;
  }

  void limpar() {
    _erro    = '';
    _sucesso = '';
    notifyListeners();
  }
}