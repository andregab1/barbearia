// ==========================================
// CONTROLLER: Barbeiro
// RF05 - Agenda | RF11 - Bloqueios
// ==========================================
import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';

class BarbeiroController extends ChangeNotifier {
  List<Map<String, dynamic>> _agendamentos = [];
  Map<String, dynamic> _resumo = const {};
  Map<String, dynamic>? _proximoAtendimento;
  Map<String, dynamic> _ocupacao = const {};
  bool _carregandoAgenda = false;
  final bool _salvando = false;
  String _erro = '';

  List<Map<String, dynamic>> get agendamentos => _agendamentos;
  Map<String, dynamic> get resumo => _resumo;
  Map<String, dynamic>? get proximoAtendimento => _proximoAtendimento;
  Map<String, dynamic> get ocupacao => _ocupacao;
  bool get carregandoAgenda => _carregandoAgenda;
  bool get salvando => _salvando;
  String get erro => _erro;

  // ==========================================
  // RF05: Carrega agenda do barbeiro
  // ==========================================
  Future<void> carregarAgenda(int colaboradorId, {String? data}) async {
    _carregandoAgenda = true;
    _erro = '';
    notifyListeners();

    final result = data == null
        ? await ApiService.get('/agenda/dashboard/$colaboradorId')
        : await ApiService.get(
            '/agendamentos/barbeiro/$colaboradorId?data=$data');
    _carregandoAgenda = false;

    if (result.containsKey('erro')) {
      _erro = result['erro'];
      _agendamentos = [];
    } else if (data == null && result['upcomingAppointments'] is List) {
      _agendamentos = (result['upcomingAppointments'] as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      _resumo = Map<String, dynamic>.from(result['summary'] ?? const {});
      _ocupacao = Map<String, dynamic>.from(result['occupancy'] ?? const {});
      _proximoAtendimento = result['nextAppointment'] == null
          ? null
          : Map<String, dynamic>.from(result['nextAppointment']);
    } else if (result['data'] != null) {
      _agendamentos = (result['data'] as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
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
    final result =
        await ApiService.patch('/agendamentos/$agendamentoId/concluir', {});
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
    final result =
        await ApiService.patch('/agendamentos/$agendamentoId/cancelar', {});
    if (result.containsKey('erro')) {
      _erro = result['erro'];
      notifyListeners();
      return false;
    }
    return true;
  }
}
