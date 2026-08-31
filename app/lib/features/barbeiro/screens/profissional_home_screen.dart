import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/barbearia_theme_service.dart';
import '../../../features/auth/controllers/auth_controller.dart';
import '../../../features/barbeiro/controllers/barbeiro_controller.dart';
import '../../../features/admin/controllers/admin_controller.dart';
import '../../../features/admin/widgets/kpi_card.dart';
import '../../../features/admin/widgets/chart_card.dart';
import '../../../features/barbeiro/screens/bloquear_horario_screen.dart';
import '../../../features/barbeiro/screens/horarios_screen.dart';
import '../../../features/barbeiro/screens/contatos_screen.dart';
import '../../../features/barbeiro/widgets/agenda_dashboard.dart';
import '../../../features/admin/screens/personalizacao_screen.dart';
import '../../../shared/widgets/app_modal.dart';
import '../../../shared/widgets/perfil_screen.dart';
import '../../../shared/widgets/responsive_nav_shell.dart';
import '../../../shared/widgets/premium_ui.dart';

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
    final prefs = await SharedPreferences.getInstance();
    final colabId = prefs.getInt(AppConstants.keyColaboradorId) ??
        prefs.getInt(AppConstants.keyUsuarioId) ??
        0;
    if (mounted) context.read<BarbeiroController>().carregarAgenda(colabId);
  }

  List<Widget> get _paginasBarbeiro => [
        _AgendaTab(onCarregarAgenda: _carregarAgenda),
        const BloquearHorarioScreen(),
        const HorariosScreen(),
        const ContatosScreen(),
        const PerfilScreen(),
      ];

  List<Widget> get _paginasAdmin => [
        const _AgendaAdminTab(),
        const HorariosScreen(),
        const _GestaoTab(),
        const PersonalizacaoScreen(),
        const PerfilScreen(),
      ];

  static const _itensAdmin = [
    NavShellItem(
        icon: Icons.calendar_month_outlined,
        activeIcon: Icons.calendar_month,
        label: 'Agenda'),
    NavShellItem(
        icon: Icons.schedule_outlined,
        activeIcon: Icons.schedule,
        label: 'Horários'),
    NavShellItem(
        icon: Icons.bar_chart_outlined,
        activeIcon: Icons.bar_chart,
        label: 'Gestão'),
    NavShellItem(
        icon: Icons.palette_outlined,
        activeIcon: Icons.palette,
        label: 'Visual'),
    NavShellItem(
        icon: Icons.person_outline, activeIcon: Icons.person, label: 'Perfil'),
  ];

  static const _itensBarbeiro = [
    NavShellItem(
        icon: Icons.calendar_month_outlined,
        activeIcon: Icons.calendar_month,
        label: 'Agenda'),
    NavShellItem(
        icon: Icons.block_outlined, activeIcon: Icons.block, label: 'Bloquear'),
    NavShellItem(
        icon: Icons.schedule_outlined,
        activeIcon: Icons.schedule,
        label: 'Horários'),
    NavShellItem(
        icon: Icons.contacts_outlined,
        activeIcon: Icons.contacts,
        label: 'Contatos'),
    NavShellItem(
        icon: Icons.person_outline, activeIcon: Icons.person, label: 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    final role = context.read<AuthController>().role;
    final isAdmin = role == AppConstants.roleAdmin;
    final paginas = isAdmin ? _paginasAdmin : _paginasBarbeiro;
    final paginaSegura = _paginaAtual.clamp(0, paginas.length - 1);

    return ResponsiveNavShell(
      currentIndex: paginaSegura,
      onTap: (i) => setState(() => _paginaAtual = i),
      items: isAdmin ? _itensAdmin : _itensBarbeiro,
      tituloMarca: 'GetCutt',
      userName: context.watch<AuthController>().nomeUsuario,
      userRole: isAdmin ? 'Administrador' : 'Barbeiro',
      onLogout: () => context.read<AuthController>().logout(),
      body: paginas[paginaSegura],
    );
  }
}

// ==========================================
// TAB: Agenda — agrupada por dia
// ==========================================
class _AgendaTab extends StatelessWidget {
  final VoidCallback onCarregarAgenda;
  const _AgendaTab({required this.onCarregarAgenda});

  Color _corStatus(String status) {
    switch (status) {
      case 'confirmado':
        return AppTheme.sucesso;
      case 'cancelado':
        return AppTheme.erro;
      case 'concluido':
        return AppTheme.sucesso;
      default:
        return AppTheme.corTextoSecundario;
    }
  }

  Map<String, List<Map<String, dynamic>>> _agruparPorDia(
      List<Map<String, dynamic>> agendamentos) {
    final Map<String, List<Map<String, dynamic>>> grupos = {};
    for (final ag in agendamentos) {
      final data =
          DateFormat('yyyy-MM-dd').format(DateTime.parse(ag['data_hora']));
      grupos.putIfAbsent(data, () => []).add(ag);
    }
    return grupos;
  }

  String _labelDia(String dataStr) {
    final data = DateTime.parse(dataStr);
    final hoje = DateTime.now();
    final amanha = DateTime.now().add(const Duration(days: 1));

    if (DateFormat('yyyy-MM-dd').format(data) ==
        DateFormat('yyyy-MM-dd').format(hoje)) {
      return 'Hoje';
    } else if (DateFormat('yyyy-MM-dd').format(data) ==
        DateFormat('yyyy-MM-dd').format(amanha)) {
      return 'Amanhã';
    } else {
      const dias = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
      final diaSemana = dias[data.weekday % 7];
      return '$diaSemana, ${DateFormat('dd/MM').format(data)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<BarbeiroController>();
    final auth = context.read<AuthController>();
    return PremiumPage(
      title: 'Agenda',
      subtitle:
          'Ola, ${auth.nomeUsuario?.split(' ').first ?? 'profissional'}. Acompanhe seus proximos atendimentos.',
      actions: [
        _IconButton(
          icon: Icons.refresh_rounded,
          cor: PremiumColors.gold,
          onTap: onCarregarAgenda,
        ),
      ],
      child: ctrl.carregandoAgenda
          ? const PremiumLoadingState(label: 'Carregando agenda')
          : ctrl.erro.isNotEmpty
              ? AgendaErrorState(message: ctrl.erro, onRetry: onCarregarAgenda)
              : AgendaDashboard(
                  appointments: ctrl.agendamentos,
                  summary: ctrl.resumo,
                  occupancy: ctrl.ocupacao,
                  nextAppointment: ctrl.proximoAtendimento,
                  onComplete: (item) async {
                    final ok = await context
                        .read<BarbeiroController>()
                        .concluir(item['id']);
                    if (ok) onCarregarAgenda();
                  },
                  onCancel: (item) async {
                    final ok = await context
                        .read<BarbeiroController>()
                        .cancelar(item['id']);
                    if (ok) onCarregarAgenda();
                  },
                ),
    );
  }

  // ignore: unused_element
  Widget _buildLegacy(BuildContext context) {
    final ctrl = context.watch<BarbeiroController>();
    context.watch<BarbeariaThemeService>();
    final auth = context.read<AuthController>();
    final cor = Theme.of(context).colorScheme.primary;

    final hoje = DateTime.now();
    final agendamentos = ctrl.agendamentos;
    final confirmados =
        agendamentos.where((a) => a['status'] == 'confirmado').length;
    final grupos = _agruparPorDia(agendamentos);
    final dias = grupos.keys.toList()..sort();

    final agHoje = agendamentos.where((a) {
      final data = DateTime.parse(a['data_hora']);
      return DateFormat('yyyy-MM-dd').format(data) ==
          DateFormat('yyyy-MM-dd').format(hoje);
    }).length;

    return PremiumPage(
      title: 'Agenda',
      subtitle:
          'Olá, ${auth.nomeUsuario?.split(' ').first ?? 'Profissional'}. Acompanhe seus próximos atendimentos.',
      actions: [
        _IconButton(
            icon: Icons.refresh_rounded, cor: cor, onTap: onCarregarAgenda),
        const SizedBox(width: 4),
        _IconButton(
            icon: Icons.logout_rounded,
            cor: AppTheme.corTextoSecundario,
            onTap: () => context.read<AuthController>().logout()),
      ],
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 12),
          child: Row(children: [
            _ResumoCard(
                label: 'Hoje',
                valor: agHoje.toString(),
                icone: Icons.today,
                cor: cor),
            const SizedBox(width: 12),
            _ResumoCard(
                label: 'Próximos',
                valor: confirmados.toString(),
                icone: Icons.calendar_month,
                cor: cor),
            const SizedBox(width: 12),
            _ResumoCard(
                label: 'Total',
                valor: agendamentos.length.toString(),
                icone: Icons.list_alt,
                cor: cor),
          ]),
        ),
        Expanded(
          child: ctrl.carregandoAgenda
              ? Center(child: CircularProgressIndicator(color: cor))
              : agendamentos.isEmpty
                  ? Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_month_outlined,
                                color: cor.withValues(alpha: 0.3), size: 64),
                            const SizedBox(height: 16),
                            Text('Nenhum agendamento nos próximos dias.',
                                style: _inter(AppTheme.corTextoSecundario, 14,
                                    FontWeight.w400)),
                          ]),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                      itemCount: dias.length,
                      itemBuilder: (context, diaIndex) {
                        final dia = dias[diaIndex];
                        final lista = grupos[dia]!;
                        final isHoje =
                            dia == DateFormat('yyyy-MM-dd').format(hoje);

                        return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                                child: Row(children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: isHoje
                                          ? AppTheme.erro
                                          : cor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(_labelDia(dia),
                                        style: GoogleFonts.inter(
                                          color: isHoje ? Colors.white : cor,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                          letterSpacing: isHoje ? 1.2 : 0,
                                        )),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                      '${lista.length} atendimento${lista.length > 1 ? 's' : ''}',
                                      style: _inter(AppTheme.corTextoSecundario,
                                          12, FontWeight.w400)),
                                ]),
                              ),
                              ...lista.map((ag) {
                                final hora = DateFormat('HH:mm')
                                    .format(DateTime.parse(ag['data_hora']));
                                final status = ag['status'] as String;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceElev,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border(
                                        left: BorderSide(
                                            color: _corStatus(status),
                                            width: 4)),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Row(children: [
                                                  Icon(
                                                      Icons.access_time_rounded,
                                                      color: cor,
                                                      size: 16),
                                                  const SizedBox(width: 6),
                                                  Text(hora,
                                                      style: GoogleFonts.inter(
                                                          color: cor,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          fontSize: 18)),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                      '${ag['duracao_min']} min',
                                                      style: _inter(
                                                          AppTheme
                                                              .corTextoSecundario,
                                                          12,
                                                          FontWeight.w400)),
                                                ]),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 10,
                                                      vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: _corStatus(status)
                                                        .withValues(
                                                            alpha: 0.15),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20),
                                                  ),
                                                  child: Text(status,
                                                      style: GoogleFonts.inter(
                                                          color: _corStatus(
                                                              status),
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w600)),
                                                ),
                                              ]),
                                          const SizedBox(height: 10),
                                          Text(
                                            (ag['observacao'] != null &&
                                                    ag['observacao']
                                                        .toString()
                                                        .isNotEmpty)
                                                ? ag['observacao']
                                                : ag['servico'],
                                            style: GoogleFonts.inter(
                                                color: AppTheme.corTexto,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(children: [
                                            Icon(Icons.person_outline,
                                                color:
                                                    AppTheme.corTextoSecundario,
                                                size: 14),
                                            const SizedBox(width: 4),
                                            Text(ag['cliente'] ?? '',
                                                style: _inter(
                                                    AppTheme.corTextoSecundario,
                                                    13,
                                                    FontWeight.w400)),
                                            if (ag['cliente_telefone'] !=
                                                    null &&
                                                ag['cliente_telefone'] !=
                                                    '') ...[
                                              const SizedBox(width: 12),
                                              Icon(Icons.phone_outlined,
                                                  color: AppTheme
                                                      .corTextoSecundario,
                                                  size: 14),
                                              const SizedBox(width: 4),
                                              Text(ag['cliente_telefone'],
                                                  style: _inter(
                                                      AppTheme
                                                          .corTextoSecundario,
                                                      13,
                                                      FontWeight.w400)),
                                            ],
                                          ]),
                                          Text(
                                              'R\$ ${(double.tryParse(ag['valor_cobrado'].toString()) ?? 0).toStringAsFixed(2)}',
                                              style: GoogleFonts.inter(
                                                  color: cor,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13)),
                                          if (status == 'confirmado') ...[
                                            const SizedBox(height: 12),
                                            Builder(builder: (context) {
                                              final dataAg = DateTime.parse(
                                                  ag['data_hora']);
                                              final eHoje = dataAg.year ==
                                                      hoje.year &&
                                                  dataAg.month == hoje.month &&
                                                  dataAg.day == hoje.day;
                                              return Row(children: [
                                                Expanded(
                                                    child: SizedBox(
                                                  height: 44,
                                                  child: OutlinedButton(
                                                    onPressed: () async {
                                                      await context
                                                          .read<
                                                              BarbeiroController>()
                                                          .cancelar(ag['id']);
                                                      onCarregarAgenda();
                                                    },
                                                    style: OutlinedButton
                                                        .styleFrom(
                                                      foregroundColor:
                                                          AppTheme.erro,
                                                      side: BorderSide(
                                                          color: AppTheme.erro
                                                              .withValues(
                                                                  alpha: 0.4)),
                                                      shape:
                                                          RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8)),
                                                      padding: EdgeInsets.zero,
                                                    ),
                                                    child: Text('Cancelar',
                                                        style:
                                                            GoogleFonts.inter(
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600)),
                                                  ),
                                                )),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                    child: SizedBox(
                                                  height: 44,
                                                  child: Tooltip(
                                                    message: eHoje
                                                        ? ''
                                                        : 'Disponível somente no dia do atendimento',
                                                    child: ElevatedButton.icon(
                                                      onPressed: eHoje
                                                          ? () async {
                                                              await context
                                                                  .read<
                                                                      BarbeiroController>()
                                                                  .concluir(
                                                                      ag['id']);
                                                              onCarregarAgenda();
                                                            }
                                                          : null,
                                                      style: ElevatedButton
                                                          .styleFrom(
                                                        backgroundColor: eHoje
                                                            ? AppTheme.sucesso
                                                            : AppTheme
                                                                .surfaceElev,
                                                        foregroundColor: eHoje
                                                            ? Colors.white
                                                            : AppTheme
                                                                .corTextoSecundario,
                                                        shape:
                                                            RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            8)),
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 8),
                                                        minimumSize: Size.zero,
                                                      ),
                                                      icon: Icon(
                                                          eHoje
                                                              ? Icons
                                                                  .check_circle_outline
                                                              : Icons
                                                                  .lock_outline,
                                                          size: 14),
                                                      label: Text('Concluir',
                                                          style:
                                                              GoogleFonts.inter(
                                                                  fontSize: 13,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600)),
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
                            ]);
                      },
                    ),
        ),
      ]),
    );
  }
}

// ==========================================
// TAB: Gestão Admin — Serviços e Equipe
// ==========================================
class _GestaoTab extends StatefulWidget {
  const _GestaoTab();
  @override
  State<_GestaoTab> createState() => _GestaoTabState();
}

class _GestaoTabState extends State<_GestaoTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctrl = context.read<AdminController>();
      ctrl.carregarServicos();
      ctrl.carregarColaboradores();
      ctrl.carregarRelatorio();
      ctrl.carregarRelatorioMensal();
    });
  }

  String? _tagServico(Map<String, dynamic> s) {
    if (s['tag'] != null && s['tag'].toString().isNotEmpty)
      return s['tag'].toString();
    if (s['destaque'] == true || s['destaque'] == 1) return 'Destaque';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AdminController>();
    context.watch<BarbeariaThemeService>();
    final cor = Theme.of(context).colorScheme.primary;

    return PremiumPage(
      title: 'Gestão',
      subtitle: 'Acompanhe resultados e administre serviços e equipe.',
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ===== Financeiro =====
          _buildRelatorioSection(ctrl, cor),
          const SizedBox(height: 36),

          // ===== Serviços =====
          _headerSecao(
            titulo: 'Serviços',
            subtitulo: 'Gerencie os serviços oferecidos pela sua barbearia.',
            botaoLabel: '+ Novo serviço',
            botaoIcon: Icons.add,
            onBotao: () => _mostrarFormServico(context),
          ),
          const SizedBox(height: 24),
          if (ctrl.carregandoServicos)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator(color: cor)),
            )
          else if (ctrl.servicos.isEmpty)
            const _EmptyState(
                icon: Icons.content_cut_outlined,
                message: 'Nenhum serviço cadastrado.')
          else
            ...ctrl.servicos.map((s) => _buildServicoCard(context, ctrl, s)),
          const SizedBox(height: 36),

          // ===== Equipe =====
          _headerSecao(
            titulo: 'Equipe',
            subtitulo: 'Gerencie os membros da sua equipe.',
            botaoLabel: '+ Adicionar membro',
            botaoIcon: Icons.person_add,
            onBotao: () => _mostrarFormColaborador(context),
          ),
          const SizedBox(height: 24),
          if (ctrl.carregandoColaboradores)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator(color: cor)),
            )
          else if (ctrl.colaboradores.isEmpty)
            const _EmptyState(
                icon: Icons.group_outlined,
                message: 'Nenhum colaborador cadastrado.')
          else
            ...ctrl.colaboradores
                .map((c) => _buildColaboradorCard(context, ctrl, c)),
        ]),
      ),
    );
  }

  Widget _headerSecao({
    required String titulo,
    required String subtitulo,
    String? botaoLabel,
    IconData? botaoIcon,
    VoidCallback? onBotao,
  }) {
    final cor = Theme.of(context).colorScheme.primary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo,
                style: GoogleFonts.inter(
                    color: AppTheme.corTexto,
                    fontSize: 26,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(subtitulo,
                style: GoogleFonts.inter(
                    color: AppTheme.corTextoSecundario,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.3)),
          ]),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: onBotao,
          style: ElevatedButton.styleFrom(
            backgroundColor: cor,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            minimumSize: const Size(0, 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: Icon(botaoIcon ?? Icons.add, size: 18),
          label: Text(botaoLabel ?? '',
              style:
                  GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildServicoCard(
      BuildContext context, AdminController ctrl, Map<String, dynamic> s) {
    final cor = Theme.of(context).colorScheme.primary;
    final nome = s['nome'] ?? 'Serviço';
    final duracao = '${s['duracao_min'] ?? 0} min';
    final preco =
        'R\$ ${double.parse(s['preco'].toString()).toStringAsFixed(2)}';
    final categoria = s['categoria'];
    final tag = _tagServico(s);

    return _HoverCard(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.content_cut, color: cor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nome,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              color: AppTheme.corTexto,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 5),
                      Row(children: [
                        Icon(Icons.schedule,
                            color: AppTheme.corTextoSecundario, size: 13),
                        const SizedBox(width: 4),
                        Text(duracao,
                            style: _inter(AppTheme.corTextoSecundario, 13,
                                FontWeight.w400)),
                        Text(' · ',
                            style: _inter(AppTheme.corTextoSecundario, 13,
                                FontWeight.w400)),
                        Icon(Icons.attach_money,
                            color: AppTheme.corTextoSecundario, size: 13),
                        const SizedBox(width: 4),
                        Text(preco,
                            style: _inter(AppTheme.corTextoSecundario, 13,
                                FontWeight.w400)),
                        if (categoria != null &&
                            categoria.toString().isNotEmpty) ...[
                          Text(' · ',
                              style: _inter(AppTheme.corTextoSecundario, 13,
                                  FontWeight.w400)),
                          Icon(Icons.person_outline,
                              color: AppTheme.corTextoSecundario, size: 13),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(categoria.toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _inter(AppTheme.corTextoSecundario, 13,
                                    FontWeight.w400)),
                          ),
                        ],
                      ]),
                    ]),
              ),
            ]),
            if (tag != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(tag.toUpperCase(),
                    style: GoogleFonts.inter(
                        color: cor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5)),
              ),
            ],
          ]),
        ),
        const SizedBox(width: 16),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          const _BadgeAtivo(),
          const SizedBox(height: 10),
          Text(preco,
              style: GoogleFonts.inter(
                  color: cor, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          _CardMenuButton(
            items: [
              PopupMenuItem(
                  value: 'editar',
                  child: Text('Editar',
                      style: GoogleFonts.inter(color: AppTheme.corTexto))),
              PopupMenuItem(
                  value: 'excluir',
                  child: Text('Excluir',
                      style: GoogleFonts.inter(color: AppTheme.erro))),
            ],
            onSelected: (v) async {
              if (v == 'editar') _mostrarFormServico(context, servico: s);
              if (v == 'excluir') await ctrl.desativarServico(s['id']);
            },
          ),
        ]),
      ]),
    );
  }

  Widget _buildColaboradorCard(
      BuildContext context, AdminController ctrl, Map<String, dynamic> c) {
    final cor = Theme.of(context).colorScheme.primary;
    final nome = c['nome'] ?? '';
    final telefone = c['telefone'] ?? '';
    final roleRaw = (c['role'] ?? 'barbeiro').toString();
    final roleLabel =
        roleRaw.toUpperCase().contains('ADMIN') ? 'ADMIN' : 'BARBEIRO';

    return _HoverCard(
      child: Row(children: [
        CircleAvatar(
          radius: 23,
          backgroundColor: cor.withValues(alpha: 0.15),
          child: Text(nome.isNotEmpty ? nome[0].toUpperCase() : '?',
              style: GoogleFonts.inter(
                  color: cor, fontSize: 16, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(nome,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    color: AppTheme.corTexto,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text(telefone,
                style: GoogleFonts.inter(
                    color: AppTheme.corTextoSecundario, fontSize: 13)),
          ]),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(roleLabel,
              style: GoogleFonts.inter(
                  color: AppTheme.corTextoSecundario,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
        ),
        const SizedBox(width: 16),
        const _BadgeAtivo(),
        const SizedBox(width: 12),
        Switch(
          value: c['ativo'] == 1,
          activeThumbColor: cor,
          activeTrackColor: cor.withValues(alpha: 0.3),
          onChanged: (v) async {
            await ApiService.patch(
                '/colaboradores/${c['id']}/status', {'ativo': v});
            ctrl.carregarColaboradores();
          },
        ),
        const SizedBox(width: 8),
        _CardMenuButton(
          items: [
            PopupMenuItem(
                value: 'excluir',
                child: Text('Excluir',
                    style: GoogleFonts.inter(color: AppTheme.erro))),
          ],
          onSelected: (v) async {
            if (v == 'excluir') {
              final confirmar = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: AppTheme.surfaceElev,
                  title: Text('Excluir colaborador?',
                      style: GoogleFonts.playfairDisplay(
                          color: AppTheme.corTexto)),
                  content: Text('Tem certeza que deseja excluir $nome?',
                      style: _inter(
                          AppTheme.corTextoSecundario, 14, FontWeight.w400)),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text('Cancelar',
                            style: GoogleFonts.inter(
                                color: AppTheme.corTextoSecundario))),
                    TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text('Excluir',
                            style: GoogleFonts.inter(
                                color: AppTheme.erro,
                                fontWeight: FontWeight.w600))),
                  ],
                ),
              );
              if (confirmar == true) {
                final ok = await ctrl.removerColaborador(c['id']);
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(ctrl.erro),
                        backgroundColor: AppTheme.erro,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                  );
                }
              }
            }
          },
        ),
      ]),
    );
  }

  void _mostrarFormServico(BuildContext context,
      {Map<String, dynamic>? servico}) {
    final nomeCtrl = TextEditingController(text: servico?['nome']);
    final precoCtrl =
        TextEditingController(text: servico?['preco']?.toString());
    final duracaoCtrl =
        TextEditingController(text: servico?['duracao_min']?.toString());
    final editando = servico != null;
    final adminCtrl = context.read<AdminController>();
    adminCtrl.limpar();

    AppModal.show(
      context: context,
      size: AppModalSize.small,
      icon: Icons.content_cut_outlined,
      title: editando ? 'Editar Serviço' : 'Novo Serviço',
      subtitle:
          'Preencha as informações abaixo para cadastrar um novo serviço.',
      child: ChangeNotifierProvider.value(
        value: adminCtrl,
        child: Consumer<AdminController>(
          builder: (context, ctrl, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppModalInput(
                  controller: nomeCtrl,
                  label: 'Nome do serviço',
                  prefixIcon: Icons.content_cut_outlined,
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: AppModalInput(
                    controller: precoCtrl,
                    label: 'Preço (R\$)',
                    prefixIcon: Icons.attach_money,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  )),
                  const SizedBox(width: 12),
                  Expanded(
                      child: AppModalInput(
                    controller: duracaoCtrl,
                    label: 'Duração (min)',
                    prefixIcon: Icons.schedule,
                    keyboardType: TextInputType.number,
                  )),
                ]),
                const SizedBox(height: 16),
                if (ctrl.erro.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.erro.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(ctrl.erro,
                        style: GoogleFonts.inter(
                            color: AppTheme.erro, fontSize: 13)),
                  ),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  const AppModalCancelButton(),
                  const SizedBox(width: 12),
                  AppModalPrimaryButton(
                    label: editando ? 'Salvar' : 'Criar Serviço',
                    icon: editando ? Icons.save_outlined : Icons.add,
                    isLoading: ctrl.salvando,
                    onPressed: ctrl.salvando
                        ? null
                        : () async {
                            if (nomeCtrl.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Informe o nome do serviço.'),
                                      backgroundColor: AppTheme.erro));
                              return;
                            }
                            final preco = double.tryParse(
                                precoCtrl.text.replaceAll(',', '.'));
                            final duracao = int.tryParse(duracaoCtrl.text);
                            if (preco == null || preco <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Informe um preço válido.'),
                                      backgroundColor: AppTheme.erro));
                              return;
                            }
                            if (duracao == null || duracao <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Informe a duração em minutos.'),
                                      backgroundColor: AppTheme.erro));
                              return;
                            }
                            final ok = editando
                                ? await ctrl.atualizarServico(
                                    id: servico['id'],
                                    nome: nomeCtrl.text.trim(),
                                    preco: preco,
                                    duracaoMin: duracao)
                                : await ctrl.criarServico(
                                    nome: nomeCtrl.text.trim(),
                                    preco: preco,
                                    duracaoMin: duracao);
                            if (ok && context.mounted) Navigator.pop(context);
                          },
                  ),
                ]),
              ],
            );
          },
        ),
      ),
    );
  }

  void _mostrarFormColaborador(BuildContext context) {
    final nomeCtrl = TextEditingController();
    final telefoneCtrl = TextEditingController();
    final senhaCtrl = TextEditingController();

    AppModal.show(
      context: context,
      size: AppModalSize.small,
      icon: Icons.person_add_outlined,
      title: 'Novo Colaborador',
      subtitle:
          'Preencha as informações abaixo para adicionar um novo membro à equipe.',
      child: ChangeNotifierProvider.value(
        value: context.read<AdminController>(),
        child: Consumer<AdminController>(
          builder: (context, ctrl, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppModalInput(
                  controller: nomeCtrl,
                  label: 'Nome completo',
                  prefixIcon: Icons.person_outline,
                ),
                const SizedBox(height: 12),
                AppModalInput(
                  controller: telefoneCtrl,
                  label: 'Telefone com DDD',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                AppModalInput(
                  controller: senhaCtrl,
                  label: 'Senha inicial',
                  prefixIcon: Icons.lock_outline,
                  obscureText: true,
                ),
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  const AppModalCancelButton(),
                  const SizedBox(width: 12),
                  AppModalPrimaryButton(
                    label: 'Cadastrar',
                    icon: Icons.person_add,
                    isLoading: ctrl.salvando,
                    onPressed: ctrl.salvando
                        ? null
                        : () async {
                            final ok = await ctrl.cadastrarColaborador(
                              nome: nomeCtrl.text,
                              telefone: telefoneCtrl.text,
                              senha: senhaCtrl.text,
                            );
                            if (ok && context.mounted) Navigator.pop(context);
                          },
                  ),
                ]),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildRelatorioSection(AdminController ctrl, Color cor) {
    final rel = ctrl.relatorio;
    final relMes = ctrl.relatorioMensal;
    final now = DateTime.now();
    final meses = [
      'Jan',
      'Fev',
      'Mar',
      'Abr',
      'Mai',
      'Jun',
      'Jul',
      'Ago',
      'Set',
      'Out',
      'Nov',
      'Dez'
    ];
    final corSec = AppTheme.corTextoSecundario;

    final fmtReal = NumberFormat('R\$ #,##0.00');
    final fmtCompact = NumberFormat.compact();
    const diasSemana = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

    // ===== KPI (faturamento diário) =====
    final faturado =
        double.tryParse((rel['total_faturado'] ?? '0').toString()) ?? 0;
    final previsto =
        double.tryParse((rel['total_previsto'] ?? '0').toString()) ?? 0;
    final totalAtend = (rel['total_atendimentos'] ?? 0).toString();

    // ===== Bar chart (últimos 7 dias com atendimento no mês) =====
    final porDiaRaw = relMes['por_dia'];
    final porDia = porDiaRaw is List ? porDiaRaw : const [];
    final ultimos7 =
        porDia.length > 7 ? porDia.sublist(porDia.length - 7) : porDia;
    final maxDia = ultimos7.isEmpty
        ? 0.0
        : ultimos7.fold<double>(0, (acc, e) {
            final v = double.tryParse(e['total_faturado'].toString()) ?? 0;
            return v > acc ? v : acc;
          });
    final maxY = maxDia <= 0 ? 10.0 : maxDia * 1.25;
    final gridInterval = maxY / 4;

    // ===== Pie chart (serviços de hoje) =====
    final atendList = rel['atendimentos'];
    final atendimentosHoje = atendList is List ? atendList : const [];
    final porServico = <String, int>{};
    for (final a in atendimentosHoje) {
      if (a is! Map) continue;
      final nome = a['servico']?.toString() ?? 'Outros';
      porServico[nome] = (porServico[nome] ?? 0) + 1;
    }
    final servicosList = porServico.entries.toList();
    final totalServ = porServico.values.fold<int>(0, (a, b) => a + b);
    final palette = <Color>[
      cor,
      AppTheme.sucesso,
      const Color(0xFF3B82F6),
      const Color(0xFF8B5CF6),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF06B6D4),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _headerSecao(
        titulo: 'Relatório',
        subtitulo: 'Acompanhe o faturamento e os atendimentos do dia.',
      ),
      const SizedBox(height: 20),
      if (ctrl.carregandoRelatorio)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator(color: cor)),
        )
      else ...[
        // ===== 1. KPI Row =====
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            SizedBox(
                width: 200,
                child: KpiCard(
                  icon: Icons.attach_money,
                  value: fmtReal.format(faturado),
                  label: 'Faturado',
                  color: cor,
                )),
            const SizedBox(width: 12),
            SizedBox(
                width: 200,
                child: KpiCard(
                  icon: Icons.trending_up,
                  value: fmtReal.format(previsto),
                  label: 'Previsto',
                  color: AppTheme.sucesso,
                )),
            const SizedBox(width: 12),
            SizedBox(
                width: 200,
                child: KpiCard(
                  icon: Icons.groups_outlined,
                  value: totalAtend,
                  label: 'Atendimentos',
                  color: const Color(0xFF3B82F6),
                )),
            const SizedBox(width: 12),
            SizedBox(
                width: 200,
                child: KpiCard(
                  icon: Icons.content_cut,
                  value: ctrl.servicos.length.toString(),
                  label: 'Serviços',
                  color: const Color(0xFF8B5CF6),
                )),
          ]),
        ),
        const SizedBox(height: 16),

        // ===== 2. Bar Chart — Receita dos últimos 7 dias =====
        ChartCard(
          title: 'Receita dos últimos 7 dias',
          child: SizedBox(
            height: 240,
            child: Stack(
              children: [
                BarChart(
                  BarChartData(
                    minY: 0,
                    maxY: maxY,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: gridInterval,
                      getDrawingHorizontalLine: (v) => FlLine(
                        color: corSec.withValues(alpha: 0.05),
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 56,
                        getTitlesWidget: (value, meta) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text('R\$${fmtCompact.format(value)}',
                              style: GoogleFonts.inter(
                                  color: corSec,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500)),
                        ),
                      )),
                      bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= ultimos7.length)
                            return const SizedBox.shrink();
                          final dt =
                              DateTime.parse(ultimos7[i]['dia'].toString());
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(diasSemana[dt.weekday - 1],
                                style: GoogleFonts.inter(
                                    color: corSec,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500)),
                          );
                        },
                      )),
                    ),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final i = group.x;
                          final dt =
                              DateTime.parse(ultimos7[i]['dia'].toString());
                          return BarTooltipItem(
                            '${diasSemana[dt.weekday - 1]} · ${DateFormat('dd/MM').format(dt)}\n${fmtReal.format(rod.toY)}',
                            GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                height: 1.4),
                          );
                        },
                      ),
                    ),
                    barGroups: List.generate(ultimos7.length, (i) {
                      final v = double.tryParse(
                              ultimos7[i]['total_faturado'].toString()) ??
                          0;
                      return BarChartGroupData(x: i, barRods: [
                        BarChartRodData(
                          toY: v,
                          color: cor,
                          width: 18,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(6),
                            topRight: Radius.circular(6),
                          ),
                        ),
                      ]);
                    }),
                  ),
                ),
                if (ultimos7.isEmpty)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: Text('Sem dados de faturamento neste mês.',
                            style:
                                GoogleFonts.inter(color: corSec, fontSize: 14)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ===== 3. Pie Chart — Serviços mais solicitados =====
        ChartCard(
          title: 'Serviços mais solicitados',
          child: LayoutBuilder(builder: (context, constraints) {
            final horizontal = constraints.maxWidth >= 560;
            final pie = SizedBox(
              width: 220,
              height: 220,
              child: Stack(
                children: [
                  PieChart(PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    startDegreeOffset: -90,
                    sections: [
                      for (var i = 0; i < servicosList.length; i++)
                        PieChartSectionData(
                          value: servicosList[i].value.toDouble(),
                          color: palette[i % palette.length],
                          radius: 80,
                          title:
                              '${((servicosList[i].value / totalServ) * 100).toStringAsFixed(0)}%',
                          showTitle: true,
                          titleStyle: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700),
                          titlePositionPercentageOffset: 0.55,
                        ),
                    ],
                  )),
                  if (porServico.isEmpty)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Center(
                          child: Text('Nenhum atendimento hoje',
                              style: GoogleFonts.inter(
                                  color: corSec, fontSize: 14)),
                        ),
                      ),
                    ),
                ],
              ),
            );
            final legend = Wrap(
              spacing: 16,
              runSpacing: 10,
              children: [
                for (var i = 0; i < servicosList.length; i++)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: palette[i % palette.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('${servicosList[i].key} (${servicosList[i].value})',
                        style: GoogleFonts.inter(
                            color: corSec,
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                  ]),
              ],
            );
            return horizontal
                ? Row(children: [
                    pie,
                    const SizedBox(width: 24),
                    Expanded(child: legend)
                  ])
                : Column(children: [pie, const SizedBox(height: 16), legend]);
          }),
        ),
        const SizedBox(height: 24),

        // ===== 4. Mês atual =====
        _tituloSecao('${meses[now.month - 1]}/${now.year}', cor,
            trailing: IconButton(
                icon: Icon(Icons.refresh, color: cor, size: 18),
                onPressed: () => ctrl.carregarRelatorioMensal())),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: _cardFaturamento(
                  titulo: 'Faturado no mês',
                  valor: 'R\$ ${relMes['total_faturado'] ?? '0.00'}',
                  sub: '${relMes['total_atendimentos'] ?? 0} atendimentos',
                  cor: cor,
                  icone: Icons.calendar_month)),
          const SizedBox(width: 14),
          Expanded(
              child: _cardFaturamento(
                  titulo: 'Previsto no mês',
                  valor: 'R\$ ${relMes['total_previsto'] ?? '0.00'}',
                  sub: 'Agendamentos futuros',
                  cor: AppTheme.sucesso,
                  icone: Icons.trending_up)),
        ]),
      ],
    ]);
  }

  Widget _tituloSecao(String texto, Color cor, {Widget? trailing}) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(texto,
          style: GoogleFonts.inter(
              color: cor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5)),
      if (trailing != null) trailing,
    ]);
  }

  Widget _cardFaturamento({
    required String titulo,
    required String valor,
    required String sub,
    required Color cor,
    required IconData icone,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cor.withValues(alpha: 0.12),
            cor.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cor.withValues(alpha: 0.15)),
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: cor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icone, color: cor, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(titulo,
                style: GoogleFonts.inter(
                    color: AppTheme.corTextoSecundario,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(valor,
                style: GoogleFonts.inter(
                    color: cor,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3)),
            const SizedBox(height: 2),
            Text(sub,
                style: GoogleFonts.inter(
                    color: AppTheme.corTextoSecundario,
                    fontSize: 11,
                    fontWeight: FontWeight.w400)),
          ],
        )),
      ]),
    );
  }
}

// ==========================================
// CARD: Cartão elevável com hover (Gestão)
// ==========================================
class _HoverCard extends StatefulWidget {
  final Widget child;
  const _HoverCard({required this.child});

  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.primary;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: AppTheme.surfaceElev,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: _hover ? cor.withValues(alpha: 0.2) : Colors.transparent),
          boxShadow: _hover
              ? [
                  BoxShadow(
                      color: cor.withValues(alpha: 0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 8))
                ]
              : null,
        ),
        child: widget.child,
      ),
    );
  }
}

// ==========================================
// MENU: Botão de três pontos com hover
// ==========================================
class _CardMenuButton extends StatefulWidget {
  final List<PopupMenuEntry<String>> items;
  final ValueChanged<String> onSelected;
  const _CardMenuButton({required this.items, required this.onSelected});

  @override
  State<_CardMenuButton> createState() => _CardMenuButtonState();
}

class _CardMenuButtonState extends State<_CardMenuButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _hover ? AppTheme.surfaceElev : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: PopupMenuButton<String>(
          color: AppTheme.surfaceElev,
          icon: Icon(Icons.more_vert,
              color: AppTheme.corTextoSecundario, size: 20),
          padding: EdgeInsets.zero,
          iconSize: 20,
          onSelected: widget.onSelected,
          itemBuilder: (_) => widget.items,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

// ==========================================
// BADGE: Status "Ativo"
// ==========================================
class _BadgeAtivo extends StatelessWidget {
  const _BadgeAtivo();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.sucesso.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
                color: AppTheme.sucesso, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text('Ativo',
            style: GoogleFonts.inter(
                color: AppTheme.sucesso,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ==========================================
// EMPTY STATE: Nenhum registro
// ==========================================
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: cor.withValues(alpha: 0.3), size: 48),
          const SizedBox(height: 16),
          Text(message,
              style: GoogleFonts.inter(
                  color: AppTheme.corTextoSecundario, fontSize: 14)),
        ]),
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
  Map<String, dynamic> _resumo = {};
  Map<String, dynamic> _ocupacao = {};
  Map<String, dynamic>? _proximo;
  String _erro = '';
  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _carregarColaboradores());
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
    final result =
        await ApiService.get('/agenda/dashboard/${_barbeiro!['id']}');
    if (!mounted) return;
    setState(() {
      _carregando = false;
      _erro = result['erro'] ?? '';
      _agendamentos = result['upcomingAppointments'] is List
          ? (result['upcomingAppointments'] as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : [];
      _resumo = Map<String, dynamic>.from(result['summary'] ?? const {});
      _ocupacao = Map<String, dynamic>.from(result['occupancy'] ?? const {});
      _proximo = result['nextAppointment'] == null
          ? null
          : Map<String, dynamic>.from(result['nextAppointment']);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AdminController>();
    return PremiumPage(
      title: 'Agenda da equipe',
      subtitle: 'Consulte a operacao e a ocupacao de cada profissional.',
      child: Column(children: [
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: ctrl.colaboradores.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, index) {
              final item = ctrl.colaboradores[index];
              final selected = _barbeiro?['id'] == item['id'];
              return ChoiceChip(
                selected: selected,
                label: Text(item['nome']),
                onSelected: (_) async {
                  setState(() => _barbeiro = item);
                  await _carregarAgenda();
                },
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _carregando
              ? const PremiumLoadingState(label: 'Carregando agenda da equipe')
              : _erro.isNotEmpty
                  ? AgendaErrorState(message: _erro, onRetry: _carregarAgenda)
                  : AgendaDashboard(
                      appointments: _agendamentos,
                      summary: _resumo,
                      occupancy: _ocupacao,
                      nextAppointment: _proximo,
                      onComplete: (item) async {
                        await ApiService.patch(
                            '/agendamentos/${item['id']}/concluir', {});
                        await _carregarAgenda();
                      },
                      onCancel: (item) async {
                        await ApiService.patch(
                            '/agendamentos/${item['id']}/cancelar', {});
                        await _carregarAgenda();
                      },
                    ),
        ),
      ]),
    );
  }

  // ignore: unused_element
  Widget _buildLegacy(BuildContext context) {
    final ctrl = context.watch<AdminController>();
    context.watch<BarbeariaThemeService>();
    final cor = Theme.of(context).colorScheme.primary;

    return PremiumPage(
      title: 'Agenda da equipe',
      subtitle: 'Consulte os próximos atendimentos de cada profissional.',
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(28),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Agenda por profissional',
                style: _playfair(AppTheme.corTexto, 26, FontWeight.w600,
                    letterSpacing: -0.6)),
            const SizedBox(height: 14),
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
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: sel ? cor : AppTheme.surfaceElev,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: sel ? cor : Colors.transparent),
                              ),
                              child: Text(c['nome'],
                                  style: GoogleFonts.inter(
                                    color: sel
                                        ? AppTheme.blackPure
                                        : AppTheme.corTexto,
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
        Expanded(
          child: _carregando
              ? Center(child: CircularProgressIndicator(color: cor))
              : _agendamentos.isEmpty
                  ? Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                          Icon(Icons.calendar_month_outlined,
                              color: cor.withValues(alpha: 0.3), size: 64),
                          const SizedBox(height: 12),
                          Text(
                            _barbeiro == null
                                ? 'Selecione um profissional'
                                : 'Nenhum agendamento futuro',
                            style: _inter(AppTheme.corTextoSecundario, 14,
                                FontWeight.w400),
                          ),
                        ]))
                  : RefreshIndicator(
                      color: cor,
                      onRefresh: _carregarAgenda,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _agendamentos.length,
                        itemBuilder: (context, i) {
                          final ag = _agendamentos[i];
                          final data = DateTime.parse(ag['data_hora']);
                          final servico = ag['observacao'] != null &&
                                  ag['observacao'].toString().isNotEmpty
                              ? ag['observacao']
                              : ag['servico'];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceElev,
                              borderRadius: BorderRadius.circular(14),
                              border: Border(
                                  left: BorderSide(color: cor, width: 4)),
                            ),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')} · ${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}',
                                    style: GoogleFonts.inter(
                                        color: cor,
                                        fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(servico ?? '',
                                      style: GoogleFonts.inter(
                                          color: AppTheme.corTexto,
                                          fontWeight: FontWeight.w600)),
                                  Text(ag['cliente'] ?? '',
                                      style: _inter(AppTheme.corTextoSecundario,
                                          13, FontWeight.w400)),
                                  Text(
                                      'R\$ ${double.parse(ag['valor_cobrado'].toString()).toStringAsFixed(2)}',
                                      style: GoogleFonts.inter(
                                          color: cor,
                                          fontWeight: FontWeight.w700)),
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
  final String label;
  final String valor;
  final IconData icone;
  final Color cor;
  const _ResumoCard(
      {required this.label,
      required this.valor,
      required this.icone,
      required this.cor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppTheme.surfaceElev,
            borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          Icon(icone, color: cor, size: 20),
          const SizedBox(height: 6),
          Text(valor,
              style: GoogleFonts.inter(
                  color: AppTheme.corTexto,
                  fontWeight: FontWeight.w700,
                  fontSize: 18)),
          Text(label,
              style: GoogleFonts.inter(
                  color: AppTheme.corTextoSecundario, fontSize: 11)),
        ]),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final Color cor;
  final VoidCallback onTap;
  const _IconButton(
      {required this.icon, required this.cor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceElev,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
              padding: const EdgeInsets.all(10),
              child: Icon(icon, color: cor, size: 20))),
    );
  }
}

TextStyle _playfair(Color cor, double tamanho, FontWeight peso,
        {double letterSpacing = -0.4}) =>
    GoogleFonts.playfairDisplay().copyWith(
        color: cor,
        fontSize: tamanho,
        fontWeight: peso,
        letterSpacing: letterSpacing,
        height: 1.15);

TextStyle _inter(Color cor, double tamanho, FontWeight peso,
        {double height = 1.5}) =>
    GoogleFonts.inter().copyWith(
        color: cor, fontSize: tamanho, fontWeight: peso, height: height);
