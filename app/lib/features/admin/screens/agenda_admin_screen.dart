import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/services/api_service.dart';
import '../../../shared/widgets/premium_ui.dart';
import '../controllers/admin_controller.dart';

class AgendaAdminScreen extends StatefulWidget {
  const AgendaAdminScreen({super.key});

  @override
  State<AgendaAdminScreen> createState() => _AgendaAdminScreenState();
}

class _AgendaAdminScreenState extends State<AgendaAdminScreen> {
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');
  final Map<int, Map<String, dynamic>> _agendas = {};
  int? _barbeiroFiltro;
  int? _servicoFiltro;
  String _erro = '';
  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _carregarAgendas());
  }

  Future<void> _carregarAgendas() async {
    if (!mounted) return;
    setState(() {
      _carregando = true;
      _erro = '';
    });

    final controller = context.read<AdminController>();
    await Future.wait([
      controller.carregarColaboradores(),
      controller.carregarServicos(),
    ]);
    if (!mounted) return;

    final colaboradores = controller.colaboradores
        .where((colaborador) => colaborador['id'] != null)
        .toList();
    final respostas = await Future.wait(colaboradores.map((colaborador) async {
      final id = int.tryParse(colaborador['id'].toString());
      if (id == null) {
        return <String, dynamic>{
          'colaborador': colaborador,
          'agendamentos': <Map<String, dynamic>>[],
          'erro': 'ID inválido',
        };
      }
      final resultado = await ApiService.get('/agenda/dashboard/$id');
      final agendamentos = resultado['upcomingAppointments'] is List
          ? (resultado['upcomingAppointments'] as List)
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : <Map<String, dynamic>>[];
      return <String, dynamic>{
        'colaborador': colaborador,
        'agendamentos': agendamentos,
        'erro': resultado['erro']?.toString() ?? '',
      };
    }));

    if (!mounted) return;
    setState(() {
      _agendas
        ..clear()
        ..addEntries(respostas.map((resposta) {
          final colaborador =
              Map<String, dynamic>.from(resposta['colaborador']);
          final id = int.parse(colaborador['id'].toString());
          return MapEntry(id, {
            'colaborador': colaborador,
            'agendamentos':
                resposta['agendamentos'] ?? <Map<String, dynamic>>[],
            'erro': resposta['erro'] ?? '',
          });
        }));
      _carregando = false;
      _erro = controller.erroColaboradores;
      if (_barbeiroFiltro != null && !_agendas.containsKey(_barbeiroFiltro)) {
        _barbeiroFiltro = null;
      }
    });
  }

  List<Map<String, dynamic>> _agendamentosFiltrados(
      Map<String, dynamic> agenda) {
    final agendamentos = (agenda['agendamentos'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item))
        .where(_filtraServico)
        .toList();
    agendamentos.sort((a, b) {
      final dataA = _parseDate(a['data_hora']);
      final dataB = _parseDate(b['data_hora']);
      if (dataA == null || dataB == null) return 0;
      return dataA.compareTo(dataB);
    });
    return agendamentos;
  }

  bool _filtraServico(Map<String, dynamic> agendamento) {
    if (_servicoFiltro == null) return true;
    final id = int.tryParse(agendamento['servico_id']?.toString() ?? '');
    return id == _servicoFiltro;
  }

  DateTime? _parseDate(dynamic value) {
    final texto = value?.toString();
    if (texto == null || texto.isEmpty) return null;
    return DateTime.tryParse(texto.replaceFirst(' ', 'T'));
  }

  String _nomeServico(AdminController controller, int id) {
    for (final item in controller.servicos) {
      if (int.tryParse(item['id']?.toString() ?? '') == id) {
        return item['nome']?.toString() ?? 'Serviço';
      }
    }
    return 'Serviço';
  }

  String _statusLabel(dynamic status) {
    const labels = {
      'pendente': 'Pendente',
      'confirmado': 'Confirmado',
      'cliente_chegou': 'Cliente chegou',
      'em_atendimento': 'Em atendimento',
      'concluido': 'Concluído',
      'cancelado': 'Cancelado',
      'nao_compareceu': 'Não compareceu',
    };
    return labels[status?.toString()] ?? 'Agendado';
  }

  Color _statusColor(dynamic status) {
    switch (status?.toString()) {
      case 'cancelado':
      case 'nao_compareceu':
        return PremiumColors.error;
      case 'concluido':
        return PremiumColors.success;
      case 'cliente_chegou':
      case 'em_atendimento':
        return PremiumColors.goldBright;
      default:
        return PremiumColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AdminController>();
    final agendas = _agendas.values.where((agenda) {
      final colaborador = agenda['colaborador'] as Map<String, dynamic>;
      final id = int.tryParse(colaborador['id'].toString());
      return _barbeiroFiltro == null || id == _barbeiroFiltro;
    }).toList();
    final total = agendas.fold<int>(
      0,
      (total, agenda) => total + _agendamentosFiltrados(agenda).length,
    );

    return PremiumPage(
      title: 'Agenda da equipe',
      subtitle:
          'Acompanhe os atendimentos de todos os profissionais em um só lugar.',
      actions: [
        OutlinedButton.icon(
          onPressed: _carregando ? null : _carregarAgendas,
          icon: const Icon(Icons.refresh, size: 17),
          label: const Text('Atualizar'),
        ),
      ],
      child: Column(
        children: [
          _buildFilters(controller),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '$total ${total == 1 ? 'atendimento encontrado' : 'atendimentos encontrados'}',
              style: GoogleFonts.inter(
                color: PremiumColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _carregando
                ? const PremiumLoadingState(
                    label: 'Carregando agenda da equipe')
                : _erro.isNotEmpty
                    ? _buildErrorState()
                    : agendas.isEmpty
                        ? const PremiumEmptyState(
                            icon: Icons.event_busy_outlined,
                            title: 'Nenhum profissional encontrado',
                            subtitle:
                                'Cadastre ou ative um profissional para visualizar a agenda.',
                          )
                        : total == 0
                            ? const PremiumEmptyState(
                                icon: Icons.event_available_outlined,
                                title: 'Nenhum atendimento para estes filtros',
                                subtitle:
                                    'Tente selecionar outro barbeiro ou serviço.',
                              )
                            : ListView.separated(
                                itemCount: agendas.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (_, index) => _buildAgendaCard(
                                  agendas[index],
                                  controller,
                                ),
                              ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(AdminController controller) {
    final colaboradores = controller.colaboradores
        .where((colaborador) => colaborador['id'] != null)
        .toList();
    final servicos =
        controller.servicos.where((servico) => servico['id'] != null).toList();

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildFilter<int>(
          label: 'Barbeiro',
          icon: Icons.person_outline,
          value: _barbeiroFiltro,
          items: [
            const DropdownMenuItem<int>(
                value: null, child: Text('Todos os barbeiros')),
            ...colaboradores.map((colaborador) => DropdownMenuItem<int>(
                  value: int.tryParse(colaborador['id'].toString()),
                  child:
                      Text(colaborador['nome']?.toString() ?? 'Profissional'),
                )),
          ],
          onChanged: (value) => setState(() => _barbeiroFiltro = value),
        ),
        _buildFilter<int>(
          label: 'Serviço',
          icon: Icons.content_cut_outlined,
          value: _servicoFiltro,
          items: [
            const DropdownMenuItem<int>(
                value: null, child: Text('Todos os serviços')),
            ...servicos.map((servico) => DropdownMenuItem<int>(
                  value: int.tryParse(servico['id'].toString()),
                  child: Text(servico['nome']?.toString() ?? 'Serviço'),
                )),
          ],
          onChanged: (value) => setState(() => _servicoFiltro = value),
        ),
      ],
    );
  }

  Widget _buildFilter<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return SizedBox(
      width: 290,
      child: DropdownButtonFormField<T>(
        initialValue: value,
        items: items,
        onChanged: onChanged,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 18),
          filled: true,
          fillColor: PremiumColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: PremiumColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: PremiumColors.border),
          ),
        ),
        dropdownColor: PremiumColors.surfaceSecondary,
      ),
    );
  }

  Widget _buildAgendaCard(
      Map<String, dynamic> agenda, AdminController controller) {
    final colaborador = agenda['colaborador'] as Map<String, dynamic>;
    final agendamentos = _agendamentosFiltrados(agenda);
    final erro = agenda['erro']?.toString() ?? '';
    final nome = colaborador['nome']?.toString() ?? 'Profissional';

    return PremiumSurface(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: PremiumColors.gold.withValues(alpha: .12),
                  child: Text(
                    nome.isEmpty ? '?' : nome.substring(0, 1).toUpperCase(),
                    style: GoogleFonts.inter(
                      color: PremiumColors.gold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    nome,
                    style: GoogleFonts.inter(
                      color: PremiumColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  '${agendamentos.length} ${agendamentos.length == 1 ? 'atendimento' : 'atendimentos'}',
                  style: GoogleFonts.inter(
                    color: PremiumColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: PremiumColors.border),
          if (erro.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                'Não foi possível carregar esta agenda.',
                style:
                    GoogleFonts.inter(color: PremiumColors.error, fontSize: 13),
              ),
            )
          else if (agendamentos.isEmpty)
            Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                'Nenhum atendimento nos próximos 30 dias para este filtro.',
                style: GoogleFonts.inter(
                    color: PremiumColors.textMuted, fontSize: 13),
              ),
            )
          else
            ...agendamentos.asMap().entries.map(
                  (entry) => _buildAppointmentRow(entry.value, controller,
                      entry.key == agendamentos.length - 1),
                ),
        ],
      ),
    );
  }

  Widget _buildAppointmentRow(
      Map<String, dynamic> appointment, AdminController controller, bool last) {
    final data = _parseDate(appointment['data_hora']);
    final status = appointment['status'];
    final servicoId = int.tryParse(appointment['servico_id']?.toString() ?? '');
    final servico = appointment['servico']?.toString() ??
        (servicoId == null ? 'Serviço' : _nomeServico(controller, servicoId));
    final cliente = appointment['cliente']?.toString() ?? 'Cliente';
    final statusColor = _statusColor(status);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 13, 18, 13),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: PremiumColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              data == null ? 'Data indisponível' : _dateFormat.format(data),
              style: GoogleFonts.inter(
                color: PremiumColors.gold,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  servico,
                  style: GoogleFonts.inter(
                    color: PremiumColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  cliente,
                  style: GoogleFonts.inter(
                    color: PremiumColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  _statusLabel(status),
                  style: GoogleFonts.inter(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                premiumCurrency(appointment['valor_cobrado']),
                style: GoogleFonts.inter(
                  color: PremiumColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return PremiumEmptyState(
      icon: Icons.error_outline,
      title: 'Não foi possível carregar a agenda',
      subtitle: _erro.isEmpty ? 'Tente novamente.' : _erro,
    );
  }
}
