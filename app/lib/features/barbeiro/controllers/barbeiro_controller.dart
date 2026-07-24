// ==========================================
// CONTROLLER: Barbeiro
// RF05 - Agenda | RF11 - Bloqueios
// ==========================================
import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';

class BarbeiroController extends ChangeNotifier {
  List<Map<String, dynamic>> _agendamentos       = [];
  List<Map<String, dynamic>> _bloqueios          = [];
  bool   _carregandoAgenda    = false;
  bool   _carregandoBloqueios = false;
  bool   _salvando            = false;
  String _erro                = '';
  String _sucesso             = '';

  List<Map<String, dynamic>> get agendamentos        => _agendamentos;
  List<Map<String, dynamic>> get bloqueios           => _bloqueios;
  bool   get carregandoAgenda    => _carregandoAgenda;
  bool   get carregandoBloqueios => _carregandoBloqueios;
  bool   get salvando            => _salvando;
  String get erro                => _erro;
  String get sucesso             => _sucesso;

  // ==========================================
  // RF05: Carrega agenda do barbeiro
  // ==========================================
  Future<void> carregarAgenda(int colaboradorId, {String? data}) async {
    _carregandoAgenda = true;
    notifyListeners();

    final query  = data != null ? '?data=$data' : '';
    final result = await ApiService.get('/agendamentos/barbeiro/$colaboradorId$query');
    _carregandoAgenda = false;

    if (result['data'] != null) {
      _agendamentos = (result['data'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } else {
      _agendamentos = [];
    }
    notifyListeners();
  }

  // ==========================================
  // RF03: Concluir agendamento
  // ==========================================
  Future<bool> concluir(int agendamentoId) async {
    _erro = '';
    notifyListeners();
    final result = await ApiService.patch('/agendamentos/$agendamentoId/concluir', {});
    if (result.containsKey('erro')) {
      _erro = result['erro'];
      notifyListeners();
      return false;
    }
    return true;
  }

  // ==========================================
  // RF07: Cancelar agendamento
  // ==========================================
  Future<bool> cancelar(int agendamentoId) async {
    _erro = '';
    notifyListeners();
    final result = await ApiService.patch('/agendamentos/$agendamentoId/cancelar', {});
    if (result.containsKey('erro')) {
      _erro = result['erro'];
      notifyListeners();
      return false;
    }
    return true;
  }

  // ==========================================
  // RF11: Bloquear horário — retorna 'ok', 'conf' ou 'err'
  // ==========================================
  Future<String> bloquear({
    required int    colaboradorId,
    required String dataHoraIni,
    required String dataHoraFim,
    String?         motivo,
  }) async {
    final result = await ApiService.post('/agendamentos/bloquear', {
      'colaborador_id': colaboradorId,
      'data_hora_ini':  dataHoraIni,
      'data_hora_fim':  dataHoraFim,
      'motivo':         motivo,
    });

    if (!result.containsKey('erro')) return 'ok';

    final msg = (result['erro'] as String).toLowerCase();
    if (msg.contains('agendamento') || msg.contains('existem')) return 'conf';
    return 'err';
  }

  // ==========================================
  // RF11: Listar bloqueios futuros
  // ==========================================
  Future<void> carregarBloqueios(int colaboradorId) async {
    _carregandoBloqueios = true;
    notifyListeners();

    final hoje   = DateTime.now();
    final fim    = hoje.add(const Duration(days: 90));
    final fmt    = (DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final result = await ApiService.get(
      '/agendamentos/bloqueios/$colaboradorId?data_ini=${fmt(hoje)}&data_fim=${fmt(fim)}',
    );
    _carregandoBloqueios = false;

    if (result['data'] != null) {
      _bloqueios = (result['data'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } else if (!result.containsKey('erro')) {
      _bloqueios = [];
    }
    notifyListeners();
  }

  // ==========================================
  // RF11: Remover bloqueio
  // ==========================================
  Future<bool> removerBloqueio(int id) async {
    final result = await ApiService.delete('/agendamentos/bloquear/$id');
    if (result.containsKey('erro')) {
      _erro = result['erro'];
      notifyListeners();
      return false;
    }
    return true;
  }

  void limpar() {
    _erro    = '';
    _sucesso = '';
    notifyListeners();
  }
}