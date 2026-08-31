import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/premium_ui.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/api_service.dart';
import '../../../shared/widgets/app_toast.dart';

class BloquearHorarioScreen extends StatefulWidget {
  const BloquearHorarioScreen({super.key});

  @override
  State<BloquearHorarioScreen> createState() => _BloquearHorarioScreenState();
}

class _BloquearHorarioScreenState extends State<BloquearHorarioScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  DateTime? _dataIni;
  TimeOfDay? _horaIni;
  TimeOfDay? _horaFim;
  String? _motivo;
  final _motivoCtrl = TextEditingController();
  bool _repetirTodosDias = false;
  int _diasRepeticao = 30;
  bool _salvando = false;
  int _colabId = 0;

  List<Map<String, dynamic>> _bloqueios = [];
  bool _carregandoBloqueios = true;

  final List<String> _motivosPadrao = [
    'Almoço',
    'Compromisso pessoal',
    'Folga',
    'Outro...',
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final usuarioId = prefs.getInt(AppConstants.keyUsuarioId) ?? 0;
    int colabId = prefs.getInt(AppConstants.keyColaboradorId) ?? 0;

    if (colabId == 0 && usuarioId > 0) {
      final result = await ApiService.get('/colaboradores/usuario/$usuarioId');
      if (!mounted) return;
      if (!result.containsKey('erro') && result['id'] != null) {
        colabId = result['id'];
        await prefs.setInt(AppConstants.keyColaboradorId, colabId);
        if (!mounted) return;
      } else {
        colabId = usuarioId;
      }
    }

    if (!mounted) return;
    setState(() => _colabId = colabId);
    if (colabId > 0) await _carregarBloqueios();
  }

  Future<void> _carregarBloqueios() async {
    if (!mounted) return;
    setState(() => _carregandoBloqueios = true);
    final hoje = DateTime.now();
    final fim = hoje.add(const Duration(days: 90));
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final result = await ApiService.get(
      '/agendamentos/bloqueios/$_colabId?data_ini=${fmt(hoje)}&data_fim=${fmt(fim)}',
    );
    if (!mounted) return;
    List<Map<String, dynamic>>? bloqueios;
    if (!result.containsKey('erro')) {
      final raw = result['data'] ?? result;
      if (raw is List) {
        bloqueios = raw.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    }
    setState(() {
      _carregandoBloqueios = false;
      if (bloqueios != null) _bloqueios = bloqueios;
    });
  }

  Future<void> _selecionarData() async {
    final cor = Theme.of(context).colorScheme.primary;
    final data = await showDatePicker(
      context: context,
      initialDate: _dataIni ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      builder: (_, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme:
              ColorScheme.dark(primary: cor, surface: AppTheme.surfaceElev),
        ),
        child: child!,
      ),
    );
    if (data != null && mounted) setState(() => _dataIni = data);
  }

  Future<void> _selecionarHora(bool isInicio) async {
    final cor = Theme.of(context).colorScheme.primary;
    final hora = await showTimePicker(
      context: context,
      initialTime: isInicio
          ? (_horaIni ?? const TimeOfDay(hour: 9, minute: 0))
          : (_horaFim ?? const TimeOfDay(hour: 10, minute: 0)),
      builder: (_, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: Theme(
          data: Theme.of(context).copyWith(
            colorScheme:
                ColorScheme.dark(primary: cor, surface: AppTheme.surfaceElev),
          ),
          child: child!,
        ),
      ),
    );
    if (hora != null && mounted)
      setState(() => isInicio ? _horaIni = hora : _horaFim = hora);
  }

  Future<void> _bloquear() async {
    if (_dataIni == null || _horaIni == null || _horaFim == null) {
      _showSnackBar('Preencha a data e os horários.', AppTheme.erro);
      return;
    }
    if (_colabId == 0) {
      _showSnackBar('Erro: faça logout e login novamente.', AppTheme.erro);
      return;
    }

    final inicioSelecionado = DateTime(_dataIni!.year, _dataIni!.month,
        _dataIni!.day, _horaIni!.hour, _horaIni!.minute);
    final fimSelecionado = DateTime(_dataIni!.year, _dataIni!.month,
        _dataIni!.day, _horaFim!.hour, _horaFim!.minute);
    if (!fimSelecionado.isAfter(inicioSelecionado)) {
      _showSnackBar(
          'O horario final deve ser posterior ao inicial.', AppTheme.erro);
      return;
    }

    setState(() => _salvando = true);
    final motivo = _motivo == 'Outro...' ? _motivoCtrl.text : _motivo;
    final dias = _repetirTodosDias ? _diasRepeticao : 1;
    final endpoint = _repetirTodosDias
        ? '/agendamentos/bloquear/recorrente'
        : '/agendamentos/bloquear';
    final res = await ApiService.post(endpoint, {
      'colaborador_id': _colabId,
      'data_hora_ini': _fmt(inicioSelecionado),
      'data_hora_fim': _fmt(fimSelecionado),
      'motivo': motivo,
      if (_repetirTodosDias) 'dias': dias,
    });
    if (!mounted) return;
    setState(() => _salvando = false);

    final sucesso = !res.containsKey('erro');
    final msg = sucesso
        ? (res['mensagem'] ?? 'Horário bloqueado com sucesso!')
        : res['erro'];
    if (!mounted) return;
    _showSnackBar(msg, sucesso ? AppTheme.sucesso : AppTheme.erro);

    if (sucesso) {
      setState(() {
        _dataIni = null;
        _horaIni = null;
        _horaFim = null;
        _motivo = null;
        _repetirTodosDias = false;
      });
      await _carregarBloqueios();
      if (mounted) _tabCtrl.animateTo(1);
    }
  }

  String _fmt(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:00';

  int get _duracaoMinutos {
    if (_horaIni == null || _horaFim == null) return 0;
    return (_horaFim!.hour * 60 + _horaFim!.minute) -
        (_horaIni!.hour * 60 + _horaIni!.minute);
  }

  Future<void> _excluirTodos() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceElev,
        title: Text('Excluir todos os bloqueios?',
            style: GoogleFonts.playfairDisplay(
                color: AppTheme.corTexto, fontWeight: FontWeight.w600)),
        content: Text('${_bloqueios.length} bloqueio(s) serão removidos.',
            style: GoogleFonts.inter(color: AppTheme.corTextoSecundario)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar',
                style: GoogleFonts.inter(color: AppTheme.corTextoSecundario)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Excluir tudo',
                style: GoogleFonts.inter(
                    color: AppTheme.erro, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (ok == true) {
      for (final b in List.from(_bloqueios)) {
        await ApiService.delete('/agendamentos/bloquear/${b['id']}');
        if (!mounted) return;
      }
      await _carregarBloqueios();
      if (mounted)
        _showSnackBar('Todos os bloqueios removidos!', AppTheme.sucesso);
    }
  }

  Future<void> _remover(int id) async {
    await ApiService.delete('/agendamentos/bloquear/$id');
    if (!mounted) return;
    await _carregarBloqueios();
  }

  void _showSnackBar(String msg, Color cor) {
    if (!mounted) return;
    AppToast.show(context, msg,
        type: cor == AppTheme.erro ? AppToastType.error : AppToastType.success);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _motivoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.primary;

    return PremiumPage(
      title: 'Bloquear horário',
      subtitle: 'Gerencie indisponibilidades sem afetar sua agenda existente.',
      child: Column(
        children: [
          TabBar(
            controller: _tabCtrl,
            indicatorColor: cor,
            labelColor: cor,
            unselectedLabelColor: AppTheme.corTextoSecundario,
            labelStyle:
                GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
            tabs: const [
              Tab(icon: Icon(Icons.block), text: 'Novo Bloqueio'),
              Tab(icon: Icon(Icons.list_alt), text: 'Bloqueios Ativos'),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: PremiumSurface(
              padding: EdgeInsets.zero,
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  LayoutBuilder(builder: (context, constraints) {
                    final desktop = constraints.maxWidth >= 900;
                    final editor = SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('Data',
                                style: GoogleFonts.inter(
                                    color: AppTheme.corTextoSecundario,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500)),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: _selecionarData,
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: _dataIni != null
                                      ? cor.withValues(alpha: 0.1)
                                      : AppTheme.surfaceElev,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: _dataIni != null
                                          ? cor.withValues(alpha: 0.5)
                                          : Colors.transparent),
                                ),
                                child: Row(children: [
                                  Icon(Icons.calendar_today, color: cor),
                                  const SizedBox(width: 12),
                                  Text(
                                    _dataIni != null
                                        ? DateFormat('dd/MM/yyyy')
                                            .format(_dataIni!)
                                        : 'Toque para selecionar',
                                    style: GoogleFonts.inter(
                                      color: _dataIni != null
                                          ? AppTheme.corTexto
                                          : AppTheme.corTextoSecundario,
                                      fontWeight: _dataIni != null
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ]),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text('Horário',
                                style: GoogleFonts.inter(
                                    color: AppTheme.corTextoSecundario,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500)),
                            const SizedBox(height: 8),
                            Row(children: [
                              Expanded(
                                  child: _timeChip(_horaIni, 'Início', cor,
                                      () => _selecionarHora(true))),
                              Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10),
                                  child: Text('até',
                                      style: GoogleFonts.inter(
                                          color: cor,
                                          fontWeight: FontWeight.w500))),
                              Expanded(
                                  child: _timeChip(_horaFim, 'Fim', cor,
                                      () => _selecionarHora(false))),
                            ]),
                            if (_duracaoMinutos > 0) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: PremiumColors.surfaceSecondary,
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: PremiumColors.border),
                                ),
                                child: Row(children: [
                                  const Icon(Icons.timelapse_rounded,
                                      color: PremiumColors.gold, size: 18),
                                  const SizedBox(width: 8),
                                  Text('Duração',
                                      style: GoogleFonts.inter(
                                          color: PremiumColors.textSecondary,
                                          fontSize: 12)),
                                  const Spacer(),
                                  Text(
                                      '${_duracaoMinutos ~/ 60}h ${(_duracaoMinutos % 60).toString().padLeft(2, '0')}min',
                                      style: GoogleFonts.inter(
                                          color: PremiumColors.textPrimary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600)),
                                ]),
                              ),
                            ],
                            const SizedBox(height: 16),

                            // Repetir todos os dias
                            Material(
                              color: _repetirTodosDias
                                  ? cor.withValues(alpha: 0.08)
                                  : AppTheme.surfaceElev,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                  color: _repetirTodosDias
                                      ? cor.withValues(alpha: 0.4)
                                      : Colors.transparent,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(children: [
                                SwitchListTile(
                                  value: _repetirTodosDias,
                                  activeThumbColor: cor,
                                  onChanged: (v) =>
                                      setState(() => _repetirTodosDias = v),
                                  title: Text('Repetir todos os dias',
                                      style: GoogleFonts.inter(
                                          color: AppTheme.corTexto,
                                          fontWeight: FontWeight.w600)),
                                  subtitle: Text(
                                      'Bloqueia este horário diariamente',
                                      style: GoogleFonts.inter(
                                          color: AppTheme.corTextoSecundario,
                                          fontSize: 12)),
                                  secondary: Icon(Icons.repeat, color: cor),
                                ),
                                if (_repetirTodosDias)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 0, 16, 14),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              'Repetir por $_diasRepeticao dias',
                                              style: GoogleFonts.inter(
                                                  color: cor,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13)),
                                          Slider(
                                            value: _diasRepeticao.toDouble(),
                                            min: 7,
                                            max: 90,
                                            divisions: 11,
                                            activeColor: cor,
                                            inactiveColor:
                                                cor.withValues(alpha: 0.2),
                                            label: '$_diasRepeticao dias',
                                            onChanged: (v) => setState(() =>
                                                _diasRepeticao = v.toInt()),
                                          ),
                                          Text(
                                              'A recorrência só será salva se todos os dias estiverem livres',
                                              style: GoogleFonts.inter(
                                                  color: AppTheme
                                                      .corTextoSecundario,
                                                  fontSize: 11)),
                                        ]),
                                  ),
                              ]),
                            ),
                            const SizedBox(height: 16),

                            Text('Motivo',
                                style: GoogleFonts.inter(
                                    color: AppTheme.corTextoSecundario,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _motivosPadrao.map((m) {
                                final sel = _motivo == m;
                                return GestureDetector(
                                  onTap: () => setState(() => _motivo = m),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: sel ? cor : AppTheme.surfaceElev,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(m,
                                        style: GoogleFonts.inter(
                                          color: sel
                                              ? AppTheme.blackPure
                                              : AppTheme.corTexto,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 13,
                                        )),
                                  ),
                                );
                              }).toList(),
                            ),
                            if (_motivo == 'Outro...') ...[
                              const SizedBox(height: 10),
                              TextField(
                                  controller: _motivoCtrl,
                                  style: GoogleFonts.inter(
                                      color: AppTheme.corTexto),
                                  decoration: const InputDecoration(
                                      labelText: 'Descreva o motivo')),
                            ],
                            const SizedBox(height: 24),

                            Center(
                              child: ElevatedButton(
                                onPressed: _salvando ? null : _bloquear,
                                child: _salvando
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                            color: AppTheme.blackPure,
                                            strokeWidth: 2))
                                    : Text(_repetirTodosDias
                                        ? 'Bloquear por $_diasRepeticao dias'
                                        : 'Bloquear Período'),
                              ),
                            ),
                          ]),
                    );
                    final summary = _buildBlockSummary(cor);
                    if (!desktop) {
                      return SingleChildScrollView(
                        child: Column(children: [
                          SizedBox(height: 620, child: editor),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: summary,
                          ),
                        ]),
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 2, child: editor),
                        const VerticalDivider(
                            width: 1, color: PremiumColors.border),
                        SizedBox(
                          width: 330,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: summary,
                          ),
                        ),
                      ],
                    );
                  }),

                  // ABA 2: Bloqueios Ativos
                  _carregandoBloqueios
                      ? Center(child: CircularProgressIndicator(color: cor))
                      : _bloqueios.isEmpty
                          ? Center(
                              child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                  Icon(Icons.check_circle_outline,
                                      color: cor.withValues(alpha: 0.3),
                                      size: 64),
                                  const SizedBox(height: 16),
                                  Text('Nenhum bloqueio ativo.',
                                      style: GoogleFonts.inter(
                                          color: AppTheme.corTextoSecundario)),
                                ]))
                          : Column(children: [
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 12, 16, 4),
                                child: Center(
                                  child: OutlinedButton.icon(
                                    onPressed: _excluirTodos,
                                    icon: const Icon(Icons.delete_sweep,
                                        color: AppTheme.erro),
                                    label: Text(
                                        'Excluir todos (${_bloqueios.length})',
                                        style: GoogleFonts.inter(
                                            color: AppTheme.erro,
                                            fontWeight: FontWeight.w600)),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                          color: AppTheme.erro
                                              .withValues(alpha: 0.4)),
                                      minimumSize: const Size(0, 44),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 24, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: RefreshIndicator(
                                  color: cor,
                                  onRefresh: _carregarBloqueios,
                                  child: ListView.builder(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: _bloqueios.length,
                                    itemBuilder: (_, i) {
                                      final b = _bloqueios[i];
                                      final ini =
                                          DateTime.parse(b['data_hora_ini']);
                                      final fim =
                                          DateTime.parse(b['data_hora_fim']);
                                      return Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 10),
                                        decoration: BoxDecoration(
                                          color: AppTheme.surfaceElev,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: const Border(
                                              left: BorderSide(
                                                  color: AppTheme.erro,
                                                  width: 4)),
                                        ),
                                        child: ListTile(
                                          leading: const Icon(Icons.block,
                                              color: AppTheme.erro),
                                          title: Text(
                                            '${DateFormat('dd/MM/yy').format(ini)}  ${DateFormat('HH:mm').format(ini)} – ${DateFormat('HH:mm').format(fim)}',
                                            style: GoogleFonts.inter(
                                                color: AppTheme.corTexto,
                                                fontWeight: FontWeight.w600),
                                          ),
                                          subtitle: b['motivo'] != null
                                              ? Text(b['motivo'],
                                                  style: GoogleFonts.inter(
                                                      color: AppTheme
                                                          .corTextoSecundario,
                                                      fontSize: 12))
                                              : null,
                                          trailing: IconButton(
                                            icon: const Icon(
                                                Icons.delete_outline,
                                                color: AppTheme.erro),
                                            onPressed: () async {
                                              final ok = await showDialog<bool>(
                                                context: context,
                                                builder: (_) => AlertDialog(
                                                  backgroundColor:
                                                      AppTheme.surfaceElev,
                                                  title: Text(
                                                      'Remover bloqueio?',
                                                      style: GoogleFonts
                                                          .playfairDisplay(
                                                              color: AppTheme
                                                                  .corTexto,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600)),
                                                  content: Text(
                                                    '${DateFormat('dd/MM/yy').format(ini)} · ${DateFormat('HH:mm').format(ini)}–${DateFormat('HH:mm').format(fim)}',
                                                    style: GoogleFonts.inter(
                                                        color: AppTheme
                                                            .corTextoSecundario),
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                context, false),
                                                        child: Text('Cancelar',
                                                            style: GoogleFonts.inter(
                                                                color: AppTheme
                                                                    .corTextoSecundario))),
                                                    TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                context, true),
                                                        child: Text('Remover',
                                                            style: GoogleFonts.inter(
                                                                color: AppTheme
                                                                    .erro,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600))),
                                                  ],
                                                ),
                                              );
                                              if (ok == true)
                                                await _remover(b['id']);
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockSummary(Color cor) {
    final dateLabel = _dataIni == null
        ? 'Nenhuma data selecionada'
        : DateFormat("EEEE, dd 'de' MMMM 'de' yyyy", 'pt_BR').format(_dataIni!);
    final timeLabel = _horaIni == null || _horaFim == null
        ? 'Defina o horário'
        : '${_horaIni!.format(context)} – ${_horaFim!.format(context)}';
    final duration = _duracaoMinutos > 0
        ? ' (${_duracaoMinutos ~/ 60}h ${(_duracaoMinutos % 60).toString().padLeft(2, '0')}min)'
        : '';

    Widget item(IconData icon, String title, String value) => Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: PremiumColors.surfaceSecondary,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: PremiumColors.border),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: PremiumColors.textSecondary, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.inter(
                            color: PremiumColors.textSecondary, fontSize: 11)),
                    const SizedBox(height: 3),
                    Text(value,
                        style: GoogleFonts.inter(
                            color: PremiumColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                  ]),
            ),
          ]),
        );

    return PremiumSurface(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.bookmark_border_rounded, color: cor, size: 19),
          const SizedBox(width: 9),
          Text('Resumo do bloqueio',
              style: GoogleFonts.playfairDisplay(
                  color: PremiumColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 16),
        item(Icons.calendar_today_outlined, 'Data', dateLabel),
        item(Icons.schedule_outlined, 'Horário', '$timeLabel$duration'),
        item(Icons.repeat_rounded, 'Repetição',
            _repetirTodosDias ? 'Por $_diasRepeticao dias' : 'Não repetir'),
        item(Icons.sell_outlined, 'Motivo', _motivo ?? 'Não selecionado'),
        const SizedBox(height: 8),
        Text('Impacto na agenda',
            style: GoogleFonts.inter(
                color: PremiumColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Container(
          height: 58,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: PremiumColors.surfaceSecondary,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: PremiumColors.border),
          ),
          child: Row(children: [
            Expanded(child: Container(height: 10, color: PremiumColors.border)),
            Expanded(
              child: Container(
                height: 16,
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: .16),
                  border: Border.all(color: cor),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            Expanded(child: Container(height: 10, color: PremiumColors.border)),
          ]),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _salvando ? null : _bloquear,
            icon: const Icon(Icons.lock_outline, size: 17),
            label: Text(_salvando ? 'Salvando...' : 'Bloquear período'),
          ),
        ),
      ]),
    );
  }

  Widget _timeChip(
      TimeOfDay? hora, String label, Color cor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:
              hora != null ? cor.withValues(alpha: 0.1) : AppTheme.surfaceElev,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: hora != null
                  ? cor.withValues(alpha: 0.5)
                  : Colors.transparent),
        ),
        child: Row(children: [
          Icon(Icons.access_time, color: cor, size: 18),
          const SizedBox(width: 8),
          Text(
            hora?.format(context) ?? label,
            style: GoogleFonts.inter(
              color: hora != null
                  ? AppTheme.corTexto
                  : AppTheme.corTextoSecundario,
              fontWeight: hora != null ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ]),
      ),
    );
  }
}
