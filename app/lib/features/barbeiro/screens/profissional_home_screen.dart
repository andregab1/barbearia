// ==========================================
// TELA: Home Profissional (Barbeiro + Admin)
// RF05 - Agenda futura agrupada por dia
// ==========================================
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/barbearia_theme_service.dart';
import '../../../features/auth/controllers/auth_controller.dart';
import '../../../features/barbeiro/controllers/barbeiro_controller.dart';
import '../../../features/admin/controllers/admin_controller.dart';
import '../../../features/barbeiro/screens/bloquear_horario_screen.dart';
import '../../../features/barbeiro/screens/horarios_screen.dart';
import '../../../features/barbeiro/screens/contatos_screen.dart';
import '../../../features/admin/screens/personalizacao_screen.dart';
import '../../../shared/widgets/perfil_screen.dart';

class ProfissionalHomeScreen extends StatefulWidget {
  const ProfissionalHomeScreen({super.key});

  @override
  State<ProfissionalHomeScreen> createState() => _ProfissionalHomeScreenState();
}

class _ProfissionalHomeScreenState extends State<ProfissionalHomeScreen> {
  int _paginaAtual = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final role = context.read<AuthController>().role;
      if (role == AppConstants.roleAdmin) {
        context.read<AdminController>().carregarServicos();
        context.read<AdminController>().carregarColaboradores();
        context.read<AdminController>().carregarRelatorio();
        context.read<AdminController>().carregarRelatorioMensal();
      } else {
        _carregarAgenda();
      }
    });
  }

  Future<void> _carregarAgenda() async {
    final prefs   = await SharedPreferences.getInstance();
    final colabId = prefs.getInt(AppConstants.keyColaboradorId)
                 ?? prefs.getInt(AppConstants.keyUsuarioId)
                 ?? 0;
    if (mounted) context.read<BarbeiroController>().carregarAgenda(colabId);
  }

  List<Widget> get _paginasBarbeiro => [
    _AgendaTab(onCarregarAgenda: _carregarAgenda),
    const BloquearHorarioScreen(),
    HorariosScreen(),
    ContatosScreen(),
    const PerfilScreen(),
  ];

  List<Widget> get _paginasAdmin => [
    const _AgendaAdminTab(),
    HorariosScreen(),
    const _GestaoTab(),
    const PersonalizacaoScreen(),
    const PerfilScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final role       = context.read<AuthController>().role;
    final isAdmin    = role == AppConstants.roleAdmin;
    final paginas    = isAdmin ? _paginasAdmin    : _paginasBarbeiro;
    final paginaSegura = _paginaAtual.clamp(0, paginas.length - 1);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: paginas[paginaSegura],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: paginaSegura,
        onTap: (i) => setState(() => _paginaAtual = i),
        items: isAdmin ? const [
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month_outlined), activeIcon: Icon(Icons.calendar_month), label: 'Agenda'),
          BottomNavigationBarItem(icon: Icon(Icons.schedule_outlined),       activeIcon: Icon(Icons.schedule),       label: 'Horários'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined),      activeIcon: Icon(Icons.bar_chart),      label: 'Gestão'),
          BottomNavigationBarItem(icon: Icon(Icons.palette_outlined),        activeIcon: Icon(Icons.palette),        label: 'Visual'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline),          activeIcon: Icon(Icons.person),         label: 'Perfil'),
        ] : const [
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month_outlined), activeIcon: Icon(Icons.calendar_month), label: 'Agenda'),
          BottomNavigationBarItem(icon: Icon(Icons.block_outlined),          activeIcon: Icon(Icons.block),          label: 'Bloquear'),
          BottomNavigationBarItem(icon: Icon(Icons.schedule_outlined),       activeIcon: Icon(Icons.schedule),       label: 'Horários'),
          BottomNavigationBarItem(icon: Icon(Icons.contacts_outlined),       activeIcon: Icon(Icons.contacts),       label: 'Contatos'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline),          activeIcon: Icon(Icons.person),         label: 'Perfil'),
        ],
      ),
    );
  }
}

// ==========================================
// TAB: Agenda — agrupada por dia
// RF05 - Todos os agendamentos futuros
// ==========================================
class _AgendaTab extends StatelessWidget {
  final VoidCallback onCarregarAgenda;

  const _AgendaTab({required this.onCarregarAgenda});

  Color _corStatus(String status) {
    switch (status) {
      case 'confirmado': return AppTheme.corSucesso;
      case 'cancelado':  return AppTheme.corErro;
      case 'concluido':  return AppTheme.corSucesso;
      default:           return AppTheme.corTextoSecundario;
    }
  }

  // ==========================================
  // Agrupa agendamentos por data
  // ==========================================
  Map<String, List<Map<String, dynamic>>> _agruparPorDia(List<Map<String, dynamic>> agendamentos) {
    final Map<String, List<Map<String, dynamic>>> grupos = {};
    for (final ag in agendamentos) {
      final data = DateFormat('yyyy-MM-dd').format(DateTime.parse(ag['data_hora']));
      grupos.putIfAbsent(data, () => []).add(ag);
    }
    return grupos;
  }

  String _labelDia(String dataStr) {
    final data  = DateTime.parse(dataStr);
    final hoje  = DateTime.now();
    final amanha = DateTime.now().add(const Duration(days: 1));

    if (DateFormat('yyyy-MM-dd').format(data) == DateFormat('yyyy-MM-dd').format(hoje)) {
      return 'Hoje';
    } else if (DateFormat('yyyy-MM-dd').format(data) == DateFormat('yyyy-MM-dd').format(amanha)) {
      return 'Amanhã';
    } else {
      // Formata dia da semana manualmente sem depender de locale
      const dias = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
      final diaSemana = dias[data.weekday % 7];
      return '$diaSemana, ${DateFormat('dd/MM').format(data)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<BarbeiroController>();
    context.watch<BarbeariaThemeService>(); // garante rebuild ao mudar tema
    final auth = context.read<AuthController>();
    final cor  = Theme.of(context).colorScheme.primary;

    final hoje          = DateTime.now();
    final agendamentos  = ctrl.agendamentos;
    final confirmados   = agendamentos.where((a) => a['status'] == 'confirmado').length;
    final grupos        = _agruparPorDia(agendamentos);
    final dias          = grupos.keys.toList()..sort();

    // Agendamentos de hoje
    final agHoje = agendamentos.where((a) {
      final data = DateTime.parse(a['data_hora']);
      return DateFormat('yyyy-MM-dd').format(data) == DateFormat('yyyy-MM-dd').format(hoje);
    }).length;

    return SafeArea(
      child: Column(children: [
        // ==========================================
        // Header
        // ==========================================
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Olá, ${auth.nomeUsuario?.split(' ').first ?? 'Profissional'}! ✂️',
                  style: TextStyle(color: AppTheme.corTextoSecundario, fontSize: 14)),
              Text('Próximos agendamentos',
                  style: TextStyle(color: AppTheme.corTexto, fontSize: 20, fontWeight: FontWeight.bold)),
            ]),
            Row(children: [
              IconButton(
                icon: Icon(Icons.refresh, color: cor),
                onPressed: onCarregarAgenda,
              ),
              IconButton(
                icon: Icon(Icons.logout, color: AppTheme.corTextoSecundario),
                onPressed: () => context.read<AuthController>().logout(),
              ),
            ]),
          ]),
        ),

        // ==========================================
        // Resumo rápido
        // ==========================================
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Row(children: [
            _ResumoCard(label: 'Hoje',      valor: agHoje.toString(),       icone: Icons.today,            cor: cor),
            const SizedBox(width: 12),
            _ResumoCard(label: 'Próximos',  valor: confirmados.toString(),  icone: Icons.calendar_month,   cor: cor),
            const SizedBox(width: 12),
            _ResumoCard(label: 'Total',     valor: agendamentos.length.toString(), icone: Icons.list_alt,  cor: cor),
          ]),
        ),

        // ==========================================
        // Lista agrupada por dia
        // ==========================================
        Expanded(
          child: ctrl.carregandoAgenda
              ? Center(child: CircularProgressIndicator(color: cor))
              : agendamentos.isEmpty
                  ? Center(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.calendar_month_outlined, color: cor.withOpacity(0.4), size: 64),
                        SizedBox(height: 16),
                        Text('Nenhum agendamento nos próximos dias.',
                            style: TextStyle(color: AppTheme.corTextoSecundario)),
                      ]),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: dias.length,
                      itemBuilder: (context, diaIndex) {
                        final dia  = dias[diaIndex];
                        final lista = grupos[dia]!;
                        final isHoje = dia == DateFormat('yyyy-MM-dd').format(hoje);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Label do dia
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                              child: Row(children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isHoje ? AppTheme.corErro : cor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _labelDia(dia),
                                    style: TextStyle(
                                      color: isHoje ? Colors.white : cor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: isHoje ? 14 : 13,
                                      letterSpacing: isHoje ? 1.5 : 0,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text('${lista.length} atendimento${lista.length > 1 ? 's' : ''}',
                                    style: TextStyle(color: AppTheme.corTextoSecundario, fontSize: 12)),
                              ]),
                            ),

                            // Cards do dia
                            ...lista.map((ag) {
                              final hora   = DateFormat('HH:mm').format(DateTime.parse(ag['data_hora']));
                              final status = ag['status'] as String;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: AppTheme.corCard,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border(left: BorderSide(color: _corStatus(status), width: 4)),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                      Row(children: [
                                        Icon(Icons.access_time, color: cor, size: 16),
                                        SizedBox(width: 6),
                                        Text(hora, style: TextStyle(color: cor, fontWeight: FontWeight.bold, fontSize: 18)),
                                        SizedBox(width: 8),
                                        Text('${ag['duracao_min']} min',
                                            style: TextStyle(color: AppTheme.corTextoSecundario, fontSize: 12)),
                                      ]),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: _corStatus(status).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(status,
                                            style: TextStyle(color: _corStatus(status), fontSize: 11, fontWeight: FontWeight.w600)),
                                      ),
                                    ]),
                                    const SizedBox(height: 8),
                                    Text(
                                      // observacao tem nomes de todos os serviços se múltiplos
                                      (ag['observacao'] != null && ag['observacao'].toString().isNotEmpty)
                                          ? ag['observacao']
                                          : ag['servico'],
                                      style: TextStyle(color: AppTheme.corTexto, fontWeight: FontWeight.w600, fontSize: 15),
                                    ),
                                    SizedBox(height: 4),
                                    Row(children: [
                                      Icon(Icons.person_outline, color: AppTheme.corTextoSecundario, size: 14),
                                      SizedBox(width: 4),
                                      Text(ag['cliente'] ?? '',
                                          style: TextStyle(color: AppTheme.corTextoSecundario, fontSize: 13)),
                                      if (ag['cliente_telefone'] != null && ag['cliente_telefone'] != '') ...[
                                        SizedBox(width: 10),
                                        Icon(Icons.phone_outlined, color: AppTheme.corTextoSecundario, size: 14),
                                        SizedBox(width: 4),
                                        Text(ag['cliente_telefone'],
                                            style: TextStyle(color: AppTheme.corTextoSecundario, fontSize: 13)),
                                      ],
                                    ]),
                                    Text('R\$ ${double.parse(ag['valor_cobrado'].toString()).toStringAsFixed(2)}',
                                        style: TextStyle(color: cor, fontWeight: FontWeight.bold, fontSize: 13)),

                                    if (status == 'confirmado') ...[
                                      const SizedBox(height: 10),
                                      Builder(builder: (context) {
                                        final dataAg  = DateTime.parse(ag['data_hora']);
                                        final hoje    = DateTime.now();
                                        final eHoje   = dataAg.year  == hoje.year &&
                                                        dataAg.month == hoje.month &&
                                                        dataAg.day   == hoje.day;
                                        return Row(children: [
                                          Expanded(child: SizedBox(
                                            height: 40,
                                            child: OutlinedButton(
                                              onPressed: () async {
                                                await context.read<BarbeiroController>().cancelar(ag['id']);
                                                onCarregarAgenda();
                                              },
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: AppTheme.corErro,
                                                side: const BorderSide(color: AppTheme.corErro),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                padding: EdgeInsets.zero,
                                              ),
                                              child: Text('Cancelar', style: TextStyle(fontSize: 13)),
                                            ),
                                          )),
                                          const SizedBox(width: 8),
                                          Expanded(child: SizedBox(
                                            height: 40,
                                            child: Tooltip(
                                              message: eHoje ? '' : 'Disponível somente no dia do atendimento',
                                              child: ElevatedButton.icon(
                                                onPressed: eHoje ? () async {
                                                  await context.read<BarbeiroController>().concluir(ag['id']);
                                                  onCarregarAgenda();
                                                } : null,
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: eHoje ? AppTheme.corSucesso : AppTheme.corFundoSecundario,
                                                  foregroundColor: eHoje ? Colors.white : AppTheme.corTextoSecundario,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                                  minimumSize: Size.zero,
                                                ),
                                                icon: Icon(eHoje ? Icons.check_circle_outline : Icons.lock_outline, size: 14),
                                                label: Text('Concluir', style: TextStyle(fontSize: 13)),
                                              ),
                                            ),
                                          )),
                                        ]);
                                      }),
                                    ],
                                  ]),
                                ),
                              );
                            }),
                          ],
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}

// ==========================================

// ==========================================
// TAB: Gestão Admin — Relatórios e Equipe
// ==========================================
class _GestaoTab extends StatefulWidget {
  const _GestaoTab();
  @override
  State<_GestaoTab> createState() => _GestaoTabState();
}

class _GestaoTabState extends State<_GestaoTab> {
  DateTime? _filtroIni;
  DateTime? _filtroFim;
  bool      _mostraPeriodo  = false;
  bool      _periodoBuscado = false;
  bool      _buscandoPeriodo = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctrl = context.read<AdminController>();
      ctrl.carregarRelatorio();
      ctrl.carregarRelatorioMensal();
    });
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  Future<void> _selecionarData(bool isIni) async {
    final cor  = Theme.of(context).colorScheme.primary;
    final data = await showDatePicker(
      context: context,
      initialDate: isIni ? (_filtroIni ?? DateTime.now()) : (_filtroFim ?? DateTime.now()),
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (_, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(primary: cor, surface: AppTheme.corFundoSecundario),
        ),
        child: child!,
      ),
    );
    if (data != null) setState(() => isIni ? _filtroIni = data : _filtroFim = data);
  }

  Future<void> _buscarPeriodo() async {
    if (_filtroIni == null || _filtroFim == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Selecione as datas de início e fim.'),
        backgroundColor: AppTheme.corErro,
      ));
      return;
    }
    setState(() => _buscandoPeriodo = true);
    await context.read<AdminController>().carregarRelatorioPeriodo(
      dataIni: _fmt(_filtroIni!),
      dataFim: _fmt(_filtroFim!),
    );
    setState(() {
      _buscandoPeriodo  = false;
      _periodoBuscado   = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl    = context.watch<AdminController>();
    context.watch<BarbeariaThemeService>(); // garante rebuild ao mudar tema
    final rel     = ctrl.relatorio;
    final relMes  = ctrl.relatorioMensal;
    final relPer  = ctrl.relatorioPeriodo;
    final cor     = Theme.of(context).colorScheme.primary;
    final now     = DateTime.now();
    final meses   = ['Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez'];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Gestão', style: TextStyle(color: AppTheme.corTexto, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          // ==========================================
          // Faturamento de Hoje
          // ==========================================
          _tituloSecao('Hoje — ${now.day.toString().padLeft(2,'0')}/${now.month.toString().padLeft(2,'0')}/${now.year}', cor),
          const SizedBox(height: 8),
          ctrl.carregandoRelatorio
              ? Center(child: CircularProgressIndicator(color: cor))
              : Row(children: [
                  Expanded(child: _cardFaturamento(
                    titulo: 'Faturado',
                    valor:  'R\$ ${rel['total_faturado'] ?? '0.00'}',
                    sub:    '${rel['total_atendimentos'] ?? 0} concluídos',
                    cor:    cor,
                    icone:  Icons.check_circle_outline,
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _cardFaturamento(
                    titulo: 'Previsto',
                    valor:  'R\$ ${rel['total_previsto'] ?? '0.00'}',
                    sub:    '${rel['confirmados_pendentes'] ?? 0} confirmados',
                    cor:    AppTheme.corSucesso,
                    icone:  Icons.schedule,
                  )),
                ]),
          const SizedBox(height: 20),

          // ==========================================
          // Faturamento do Mês
          // ==========================================
          _tituloSecao('${meses[now.month - 1]}/${now.year}', cor,
              trailing: IconButton(
                icon: Icon(Icons.refresh, color: cor, size: 18),
                onPressed: () => ctrl.carregarRelatorioMensal(),
              )),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _cardFaturamento(
              titulo: 'Faturado no mês',
              valor:  'R\$ ${relMes['total_faturado'] ?? '0.00'}',
              sub:    '${relMes['total_atendimentos'] ?? 0} atendimentos',
              cor:    cor,
              icone:  Icons.calendar_month,
            )),
            const SizedBox(width: 10),
            Expanded(child: _cardFaturamento(
              titulo: 'Previsto no mês',
              valor:  'R\$ ${relMes['total_previsto'] ?? '0.00'}',
              sub:    'Agendamentos futuros',
              cor:    AppTheme.corSucesso,
              icone:  Icons.trending_up,
            )),
          ]),
          const SizedBox(height: 20),

          // ==========================================
          // Faturamento por Período
          // ==========================================
          GestureDetector(
            onTap: () => setState(() => _mostraPeriodo = !_mostraPeriodo),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _mostraPeriodo ? cor.withOpacity(0.1) : AppTheme.corCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _mostraPeriodo ? cor : Colors.transparent),
              ),
              child: Row(children: [
                Icon(Icons.date_range, color: cor, size: 18),
                SizedBox(width: 8),
                Text('Filtrar por período', style: TextStyle(color: AppTheme.corTexto, fontWeight: FontWeight.w600)),
                const Spacer(),
                Icon(_mostraPeriodo ? Icons.expand_less : Icons.expand_more, color: cor),
              ]),
            ),
          ),

          if (_mostraPeriodo) ...[
            SizedBox(height: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Data inicial', style: TextStyle(color: AppTheme.corTextoSecundario, fontSize: 12)),
              SizedBox(height: 6),
              GestureDetector(
                onTap: () => _selecionarData(true),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _filtroIni != null ? cor.withOpacity(0.1) : AppTheme.corCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _filtroIni != null ? cor.withOpacity(0.5) : Colors.transparent),
                  ),
                  child: Row(children: [
                    Icon(Icons.calendar_today, color: cor, size: 16),
                    SizedBox(width: 8),
                    Text(
                      _filtroIni != null
                          ? '${_filtroIni!.day.toString().padLeft(2,'0')}/${_filtroIni!.month.toString().padLeft(2,'0')}/${_filtroIni!.year}'
                          : 'Selecionar data inicial',
                      style: TextStyle(color: _filtroIni != null ? AppTheme.corTexto : AppTheme.corTextoSecundario),
                    ),
                  ]),
                ),
              ),
              SizedBox(height: 10),
              Text('Data final', style: TextStyle(color: AppTheme.corTextoSecundario, fontSize: 12)),
              SizedBox(height: 6),
              GestureDetector(
                onTap: () => _selecionarData(false),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _filtroFim != null ? cor.withOpacity(0.1) : AppTheme.corCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _filtroFim != null ? cor.withOpacity(0.5) : Colors.transparent),
                  ),
                  child: Row(children: [
                    Icon(Icons.calendar_today, color: cor, size: 16),
                    SizedBox(width: 8),
                    Text(
                      _filtroFim != null
                          ? '${_filtroFim!.day.toString().padLeft(2,'0')}/${_filtroFim!.month.toString().padLeft(2,'0')}/${_filtroFim!.year}'
                          : 'Selecionar data final',
                      style: TextStyle(color: _filtroFim != null ? AppTheme.corTexto : AppTheme.corTextoSecundario),
                    ),
                  ]),
                ),
              ),
              SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: (_filtroIni == null || _filtroFim == null || _buscandoPeriodo) ? null : _buscarPeriodo,
                icon: _buscandoPeriodo
                    ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.corFundo))
                    : Icon(Icons.search),
                label: Text(_buscandoPeriodo ? 'Buscando...' : 'Buscar faturamento'),
              ),
              if (_periodoBuscado) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cor.withOpacity(0.3)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      'Período: ${_filtroIni!.day.toString().padLeft(2,'0')}/${_filtroIni!.month.toString().padLeft(2,'0')} '
                      'até ${_filtroFim!.day.toString().padLeft(2,'0')}/${_filtroFim!.month.toString().padLeft(2,'0')}/${_filtroFim!.year}',
                      style: TextStyle(color: AppTheme.corTextoSecundario, fontSize: 12),
                    ),
                    SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Total faturado', style: TextStyle(color: AppTheme.corTextoSecundario, fontSize: 12)),
                        SizedBox(height: 4),
                        Text('R\$ ${relPer['total_geral'] ?? '0.00'}',
                            style: TextStyle(color: cor, fontSize: 20, fontWeight: FontWeight.bold)),
                      ])),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('Atendimentos', style: TextStyle(color: AppTheme.corTextoSecundario, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          '${(relPer['por_dia'] as List? ?? []).fold<int>(0, (a, d) => a + ((d['total_atendimentos'] as num?)?.toInt() ?? 0))}',
                          style: TextStyle(color: cor, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ]),
                    ]),
                    if ((relPer['por_dia'] as List? ?? []).isEmpty)
                      Padding(padding: EdgeInsets.only(top: 8),
                          child: Text('Nenhum atendimento concluído neste período.',
                              style: TextStyle(color: AppTheme.corTextoSecundario, fontSize: 12))),
                  ]),
                ),
              ],
            ]),
          ],
          SizedBox(height: 24),

          // ==========================================
          // Serviços
          // ==========================================
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Serviços', style: TextStyle(color: AppTheme.corTexto, fontSize: 16, fontWeight: FontWeight.w600)),
            TextButton.icon(
              onPressed: () => _mostrarFormServico(context),
              icon: Icon(Icons.add, color: cor, size: 18),
              label: Text('Novo', style: TextStyle(color: cor)),
            ),
          ]),
          SizedBox(height: 8),
          if (ctrl.carregandoServicos)
            Center(child: CircularProgressIndicator(color: cor))
          else
            ...ctrl.servicos.map((s) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: AppTheme.corCard, borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Icon(Icons.content_cut, color: cor),
                title: Text(s['nome'], style: TextStyle(color: AppTheme.corTexto, fontWeight: FontWeight.w600)),
                subtitle: Text('${s['duracao_min']} min', style: TextStyle(color: AppTheme.corTextoSecundario, fontSize: 12)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('R\$ ${double.parse(s['preco'].toString()).toStringAsFixed(2)}',
                      style: TextStyle(color: cor, fontWeight: FontWeight.bold)),
                  PopupMenuButton<String>(
                    color: AppTheme.corCard,
                    icon: Icon(Icons.more_vert, color: AppTheme.corTextoSecundario),
                    onSelected: (v) async {
                      if (v == 'editar')  _mostrarFormServico(context, servico: s);
                      if (v == 'excluir') await ctrl.desativarServico(s['id']);
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'editar',  child: Text('Editar',  style: TextStyle(color: AppTheme.corTexto))),
                      PopupMenuItem(value: 'excluir', child: Text('Excluir', style: TextStyle(color: AppTheme.corErro))),
                    ],
                  ),
                ]),
              ),
            )),

          SizedBox(height: 20),

          // ==========================================
          // Equipe
          // ==========================================
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Equipe', style: TextStyle(color: AppTheme.corTexto, fontSize: 16, fontWeight: FontWeight.w600)),
            TextButton.icon(
              onPressed: () => _mostrarFormColaborador(context),
              icon: Icon(Icons.person_add, color: cor, size: 18),
              label: Text('Adicionar', style: TextStyle(color: cor)),
            ),
          ]),
          SizedBox(height: 8),
          if (ctrl.carregandoColaboradores)
            Center(child: CircularProgressIndicator(color: cor))
          else
            ...ctrl.colaboradores.map((c) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: AppTheme.corCard, borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: cor.withOpacity(0.2),
                  child: Text(c['nome'][0].toUpperCase(), style: TextStyle(color: cor, fontWeight: FontWeight.bold)),
                ),
                title: Text(c['nome'], style: TextStyle(color: AppTheme.corTexto, fontWeight: FontWeight.w600)),
                subtitle: Text(c['telefone'] ?? '', style: TextStyle(color: AppTheme.corTextoSecundario, fontSize: 12)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Switch(
                    value: c['ativo'] == 1,
                    activeColor: cor,
                    onChanged: (v) async {
                      await ApiService.patch('/colaboradores/${c['id']}/status', {'ativo': v});
                      ctrl.carregarColaboradores();
                    },
                  ),
                  PopupMenuButton<String>(
                    color: AppTheme.corCard,
                    icon: Icon(Icons.more_vert, color: AppTheme.corTextoSecundario),
                    onSelected: (v) async {
                      if (v == 'excluir') {
                        final confirmar = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            backgroundColor: AppTheme.corFundoSecundario,
                            title: Text('Excluir colaborador?', style: TextStyle(color: AppTheme.corTexto)),
                            content: Text('Tem certeza que deseja excluir ${c['nome']}?',
                                style: TextStyle(color: AppTheme.corTextoSecundario)),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false),
                                  child: Text('Cancelar', style: TextStyle(color: AppTheme.corTextoSecundario))),
                              TextButton(onPressed: () => Navigator.pop(context, true),
                                  child: Text('Excluir', style: TextStyle(color: AppTheme.corErro))),
                            ],
                          ),
                        );
                        if (confirmar == true) {
                          final ok = await ctrl.removerColaborador(c['id']);
                          if (!ok && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(ctrl.erro), backgroundColor: AppTheme.corErro),
                            );
                          }
                        }
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'excluir',
                          child: Text('Excluir', style: TextStyle(color: AppTheme.corErro))),
                    ],
                  ),
                ]),
              ),
            )),
        ]),
      ),
    );
  }

  Widget _tituloSecao(String titulo, Color cor, {Widget? trailing}) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(titulo, style: TextStyle(color: cor, fontSize: 13, fontWeight: FontWeight.w600)),
      if (trailing != null) trailing,
    ]);
  }

  Widget _cardFaturamento({
    required String titulo,
    required String valor,
    required String sub,
    required Color  cor,
    required IconData icone,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icone, color: cor, size: 16),
          SizedBox(width: 6),
          Expanded(child: Text(titulo, style: TextStyle(color: AppTheme.corTextoSecundario, fontSize: 11))),
        ]),
        SizedBox(height: 6),
        Text(valor, style: TextStyle(color: cor, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(sub, style: TextStyle(color: AppTheme.corTextoSecundario, fontSize: 11)),
      ]),
    );
  }

  void _mostrarFormServico(BuildContext context, {Map<String, dynamic>? servico}) {
    final nomeCtrl    = TextEditingController(text: servico?['nome']);
    final precoCtrl   = TextEditingController(text: servico?['preco']?.toString());
    final duracaoCtrl = TextEditingController(text: servico?['duracao_min']?.toString());
    final editando    = servico != null;
    final adminCtrl   = context.read<AdminController>();
    adminCtrl.limpar();

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: AppTheme.corFundoSecundario,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => ChangeNotifierProvider.value(
        value: adminCtrl,
        child: StatefulBuilder(
          builder: (ctx, setModalState) => Padding(
            padding: MediaQuery.of(sheetContext).viewInsets,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(editando ? 'Editar Serviço' : 'Novo Serviço',
                  style: TextStyle(color: AppTheme.corTexto, fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 16),
              TextField(controller: nomeCtrl, style: TextStyle(color: AppTheme.corTexto),
                  decoration: const InputDecoration(labelText: 'Nome do serviço')),
              SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(
                  controller: precoCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: AppTheme.corTexto),
                  decoration: const InputDecoration(labelText: 'Preço (R\$)', prefixText: 'R\$ '),
                )),
                SizedBox(width: 12),
                Expanded(child: TextField(
                  controller: duracaoCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: AppTheme.corTexto),
                  decoration: const InputDecoration(labelText: 'Duração (min)', suffixText: 'min'),
                )),
              ]),
              const SizedBox(height: 20),
              Consumer<AdminController>(builder: (context, ctrl, _) {
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (ctrl.erro.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.corErro.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(ctrl.erro, style: TextStyle(color: AppTheme.corErro, fontSize: 13)),
                    ),
                  ElevatedButton(
                    onPressed: ctrl.salvando ? null : () async {
                      if (nomeCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Informe o nome do serviço.'), backgroundColor: AppTheme.corErro));
                        return;
                      }
                      final preco   = double.tryParse(precoCtrl.text.replaceAll(',', '.'));
                      final duracao = int.tryParse(duracaoCtrl.text);
                      if (preco == null || preco <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Informe um preço válido.'), backgroundColor: AppTheme.corErro));
                        return;
                      }
                      if (duracao == null || duracao <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Informe a duração em minutos.'), backgroundColor: AppTheme.corErro));
                        return;
                      }
                      final ok = editando
                          ? await ctrl.atualizarServico(id: servico!['id'], nome: nomeCtrl.text.trim(),
                              preco: preco, duracaoMin: duracao)
                          : await ctrl.criarServico(nome: nomeCtrl.text.trim(),
                              preco: preco, duracaoMin: duracao);
                      if (ok && context.mounted) Navigator.pop(context);
                    },
                    child: ctrl.salvando
                        ? SizedBox(height: 20, width: 20,
                            child: CircularProgressIndicator(color: AppTheme.corFundo, strokeWidth: 2))
                        : Text(editando ? 'Salvar' : 'Criar Serviço'),
                  ),
                ]);
              }),
            ]),
            ),  // SingleChildScrollView
          ),
        ),
      ),
    );
  }

  void _mostrarFormColaborador(BuildContext context) {
    final nomeCtrl     = TextEditingController();
    final telefoneCtrl = TextEditingController();
    final senhaCtrl    = TextEditingController();

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: AppTheme.corFundoSecundario,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => ChangeNotifierProvider.value(
        value: context.read<AdminController>(),
        child: Padding(
          padding: MediaQuery.of(sheetCtx).viewInsets,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Novo Colaborador',
                style: TextStyle(color: AppTheme.corTexto, fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            TextField(controller: nomeCtrl, style: TextStyle(color: AppTheme.corTexto),
                decoration: const InputDecoration(labelText: 'Nome completo')),
            SizedBox(height: 12),
            TextField(controller: telefoneCtrl, keyboardType: TextInputType.phone,
                style: TextStyle(color: AppTheme.corTexto),
                decoration: const InputDecoration(labelText: 'Telefone com DDD')),
            SizedBox(height: 12),
            TextField(controller: senhaCtrl, obscureText: true,
                style: TextStyle(color: AppTheme.corTexto),
                decoration: const InputDecoration(labelText: 'Senha inicial')),
            const SizedBox(height: 20),
            Consumer<AdminController>(builder: (context, ctrl, _) {
              return ElevatedButton(
                onPressed: ctrl.salvando ? null : () async {
                  final ok = await ctrl.cadastrarColaborador(
                    nome: nomeCtrl.text, telefone: telefoneCtrl.text, senha: senhaCtrl.text,
                  );
                  if (ok && context.mounted) Navigator.pop(context);
                },
                child: Text('Cadastrar'),
              );
            }),
          ]),
          ),  // SingleChildScrollView
        ),
      ),
    );
  }
}

// ==========================================
// TAB: Agenda do Admin — todos os barbeiros
// ==========================================
class _AgendaAdminTab extends StatefulWidget {
  const _AgendaAdminTab();
  @override
  State<_AgendaAdminTab> createState() => _AgendaAdminTabState();
}

class _AgendaAdminTabState extends State<_AgendaAdminTab> {
  Map<String, dynamic>? _barbeiro;
  List<Map<String, dynamic>> _agendamentos = [];
  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _carregarColaboradores());
  }

  Future<void> _carregarColaboradores() async {
    await context.read<AdminController>().carregarColaboradores();
    if (!mounted) return;
    final colabs = context.read<AdminController>().colaboradores;
    if (colabs.isNotEmpty && _barbeiro == null) {
      setState(() => _barbeiro = colabs.first);
      await _carregarAgenda();
    }
  }

  Future<void> _carregarAgenda() async {
    if (_barbeiro == null || !mounted) return;
    setState(() => _carregando = true);
    final result = await ApiService.get(
      '/agendamentos/barbeiro/${_barbeiro!['id']}',
    );
    if (!mounted) return;
    setState(() {
      _carregando   = false;
      _agendamentos = result['data'] != null
          ? (result['data'] as List).map((e) => Map<String, dynamic>.from(e)).toList()
          : [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AdminController>();
    context.watch<BarbeariaThemeService>();
    final cor = Theme.of(context).colorScheme.primary;

    return SafeArea(
      child: Column(children: [
        // Seletor de barbeiro
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Agenda por profissional',
                style: TextStyle(color: AppTheme.corTexto, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ctrl.colaboradores.isEmpty
                ? Center(child: CircularProgressIndicator(color: cor))
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ctrl.colaboradores.map((c) {
                        final sel = _barbeiro?['id'] == c['id'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () async {
                              setState(() => _barbeiro = c);
                              await _carregarAgenda();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: sel ? cor : AppTheme.corCard,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: sel ? cor : Colors.transparent),
                              ),
                              child: Text(c['nome'],
                                  style: TextStyle(
                                    color: sel ? Colors.black : AppTheme.corTexto,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  )),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
          ]),
        ),

        // Lista de agendamentos
        Expanded(
          child: _carregando
              ? Center(child: CircularProgressIndicator(color: cor))
              : _agendamentos.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.calendar_month_outlined, color: cor.withOpacity(0.3), size: 64),
                      SizedBox(height: 12),
                      Text(
                        _barbeiro == null
                            ? 'Selecione um profissional'
                            : 'Nenhum agendamento futuro',
                        style: TextStyle(color: AppTheme.corTextoSecundario),
                      ),
                    ]))
                  : RefreshIndicator(
                      color: cor,
                      onRefresh: _carregarAgenda,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _agendamentos.length,
                        itemBuilder: (context, i) {
                          final ag   = _agendamentos[i];
                          final data = DateTime.parse(ag['data_hora']);
                          final servico = ag['observacao'] != null && ag['observacao'].toString().isNotEmpty
                              ? ag['observacao']
                              : ag['servico'];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.corCard,
                              borderRadius: BorderRadius.circular(14),
                              border: Border(left: BorderSide(color: cor, width: 4)),
                            ),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(
                                '${data.day.toString().padLeft(2,'0')}/${data.month.toString().padLeft(2,'0')} · ${data.hour.toString().padLeft(2,'0')}:${data.minute.toString().padLeft(2,'0')}',
                                style: TextStyle(color: cor, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(servico ?? '', style: TextStyle(
                                  color: AppTheme.corTexto, fontWeight: FontWeight.w600)),
                              Text(ag['cliente'] ?? '',
                                  style: TextStyle(color: AppTheme.corTextoSecundario, fontSize: 13)),
                              Text('R\$ ${double.parse(ag['valor_cobrado'].toString()).toStringAsFixed(2)}',
                                  style: TextStyle(color: cor, fontWeight: FontWeight.bold)),
                            ]),
                          );
                        },
                      ),
                    ),
        ),
      ]),
    );
  }
}

// ==========================================
// CARD: Resumo
// ==========================================
class _ResumoCard extends StatelessWidget {
  final String label; final String valor; final IconData icone; final Color cor;
  const _ResumoCard({required this.label, required this.valor, required this.icone, required this.cor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppTheme.corCard, borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Icon(icone, color: cor, size: 20),
          SizedBox(height: 4),
          Text(valor, style: TextStyle(color: AppTheme.corTexto, fontWeight: FontWeight.bold, fontSize: 18)),
          Text(label, style: TextStyle(color: AppTheme.corTextoSecundario, fontSize: 11)),
        ]),
      ),
    );
  }
}