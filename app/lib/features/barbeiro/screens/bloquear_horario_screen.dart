// ==========================================
// TELA: Bloquear Horário
// RF11 - Bloqueio com repetição e gestão por dia
// ==========================================
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/api_service.dart';

class BloquearHorarioScreen extends StatefulWidget {
  const BloquearHorarioScreen({super.key});

  @override
  State<BloquearHorarioScreen> createState() => _BloquearHorarioScreenState();
}

class _BloquearHorarioScreenState extends State<BloquearHorarioScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  DateTime?  _dataIni;
  TimeOfDay? _horaIni;
  TimeOfDay? _horaFim;
  String?    _motivo;
  final _motivoCtrl = TextEditingController();
  bool _repetirTodosDias = false;
  int  _diasRepeticao    = 30;
  bool _salvando         = false;
  int  _colabId          = 0;

  List<Map<String, dynamic>> _bloqueios          = [];
  bool                       _carregandoBloqueios = true;

  final List<String> _motivosPadrao = [
    'Almoço', 'Compromisso pessoal', 'Folga', 'Outro...',
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _init();
  }

  // ==========================================
  // Busca colaborador_id correto da API
  // ==========================================
  Future<void> _init() async {
    final prefs     = await SharedPreferences.getInstance();
    final usuarioId = prefs.getInt(AppConstants.keyUsuarioId) ?? 0;

    // Tenta primeiro o colaborador_id salvo no login
    int colabId = prefs.getInt(AppConstants.keyColaboradorId) ?? 0;

    // Se não tiver (usuário antigo sem re-login), busca da API
    if (colabId == 0 && usuarioId > 0) {
      final result = await ApiService.get('/colaboradores/usuario/$usuarioId');
      if (!result.containsKey('erro') && result['id'] != null) {
        colabId = result['id'];
        await prefs.setInt(AppConstants.keyColaboradorId, colabId);
      } else {
        // Fallback: usa o usuario_id (funciona apenas se admin com id=1)
        colabId = usuarioId;
      }
    }

    setState(() => _colabId = colabId);
    if (colabId > 0) await _carregarBloqueios();
  }

  Future<void> _carregarBloqueios() async {
    setState(() => _carregandoBloqueios = true);
    final hoje = DateTime.now();
    final fim  = hoje.add(const Duration(days: 90));
    final fmt  = (DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

    final result = await ApiService.get(
      '/agendamentos/bloqueios/$_colabId?data_ini=${fmt(hoje)}&data_fim=${fmt(fim)}',
    );

    setState(() => _carregandoBloqueios = false);

    if (!result.containsKey('erro')) {
      final raw = result['data'] ?? result;
      if (raw is List) {
        setState(() => _bloqueios = raw.map((e) => Map<String, dynamic>.from(e)).toList());
      }
    }
  }

  Future<void> _selecionarData() async {
    final cor  = Theme.of(context).colorScheme.primary;
    final data = await showDatePicker(
      context: context,
      initialDate: _dataIni ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      builder: (_, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(primary: cor, surface: AppTheme.corFundoSecundario),
        ),
        child: child!,
      ),
    );
    if (data != null) setState(() => _dataIni = data);
  }

  Future<void> _selecionarHora(bool isInicio) async {
    final cor  = Theme.of(context).colorScheme.primary;
    final hora = await showTimePicker(
      context: context,
      initialTime: isInicio
          ? (_horaIni ?? const TimeOfDay(hour: 9, minute: 0))
          : (_horaFim ?? const TimeOfDay(hour: 10, minute: 0)),
      builder: (_, child) => MediaQuery(
        // Força formato 24h para evitar confusão AM/PM
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
                primary: cor, surface: AppTheme.corFundoSecundario),
          ),
          child: child!,
        ),
      ),
    );
    if (hora != null) setState(() => isInicio ? _horaIni = hora : _horaFim = hora);
  }

  // ==========================================
  // RF11: Bloquear horário(s)
  // ==========================================
  Future<void> _bloquear() async {
    if (_dataIni == null || _horaIni == null || _horaFim == null) {
      _snack('Preencha a data e os horários.', AppTheme.corErro);
      return;
    }
    if (_colabId == 0) {
      _snack('Erro: faça logout e login novamente.', AppTheme.corErro);
      return;
    }

    setState(() => _salvando = true);

    // Captura o messenger ANTES de qualquer await para evitar context inválido
    final messenger = ScaffoldMessenger.of(context);

    final motivo = _motivo == 'Outro...' ? _motivoCtrl.text : _motivo;
    final dias   = _repetirTodosDias ? _diasRepeticao : 1;
    int bloqueados = 0, pulados = 0, erros = 0;

    for (int d = 0; d < dias; d++) {
      final dia = _dataIni!.add(Duration(days: d));
      final ini = DateTime(dia.year, dia.month, dia.day, _horaIni!.hour, _horaIni!.minute);
      final fim = DateTime(dia.year, dia.month, dia.day, _horaFim!.hour, _horaFim!.minute);

      final res = await ApiService.post('/agendamentos/bloquear', {
        'colaborador_id': _colabId,
        'data_hora_ini':  _fmt(ini),
        'data_hora_fim':  _fmt(fim),
        'motivo':         motivo,
      });

      if (!res.containsKey('erro')) {
        bloqueados++;
      } else {
        final msg = (res['erro'] as String? ?? '').toLowerCase();
        if (msg.contains('agendamento') || msg.contains('existem')) pulados++;
        else erros++;
      }
    }

    setState(() => _salvando = false);

    // Mostra feedback ANTES de qualquer navegação
    String msg;
    Color  bgCor;

    if (bloqueados > 0) {
      final extra = pulados > 0 ? ' ($pulados pulados por agendamentos)' : '';
      msg   = _repetirTodosDias
          ? '$bloqueados dia(s) bloqueado(s)$extra!'
          : 'Horário bloqueado com sucesso!';
      bgCor = AppTheme.corSucesso;
    } else if (pulados > 0) {
      msg   = 'Todos os dias tinham agendamentos. Nenhum bloqueado.';
      bgCor = AppTheme.corErro;
    } else {
      msg   = 'Erro ao bloquear. Tente novamente.';
      bgCor = AppTheme.corErro;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(msg, style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: bgCor,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );

    if (bloqueados > 0) {
      setState(() {
        _dataIni = null; _horaIni = null; _horaFim = null;
        _motivo  = null; _repetirTodosDias = false;
      });
      await _carregarBloqueios();
      if (mounted) _tabCtrl.animateTo(1);
    }
  }

  // Formata sem timezone para evitar conversão incorreta
  String _fmt(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')} '
      '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}:00';

  Future<void> _excluirTodos() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.corFundoSecundario,
        title: Text('Excluir todos os bloqueios?',
            style: TextStyle(color: AppTheme.corTexto)),
        content: Text('${_bloqueios.length} bloqueio(s) serão removidos.',
            style: TextStyle(color: AppTheme.corTextoSecundario)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: TextStyle(color: AppTheme.corTextoSecundario)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Excluir tudo', style: TextStyle(color: AppTheme.corErro)),
          ),
        ],
      ),
    );
    if (ok == true) {
      for (final b in List.from(_bloqueios)) {
        await ApiService.delete('/agendamentos/bloquear/${b['id']}');
      }
      await _carregarBloqueios();
      if (mounted) _snack('Todos os bloqueios removidos!', AppTheme.corSucesso);
    }
  }

  Future<void> _remover(int id) async {
    await ApiService.delete('/agendamentos/bloquear/$id');
    await _carregarBloqueios();
  }

  void _snack(String msg, Color cor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: cor, duration: const Duration(seconds: 3)),
    );
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

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Bloquear Horário'),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: cor,
          labelColor: cor,
          unselectedLabelColor: AppTheme.corTextoSecundario,
          tabs: const [
            Tab(icon: Icon(Icons.block), text: 'Novo Bloqueio'),
            Tab(icon: Icon(Icons.list_alt), text: 'Bloqueios Ativos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // ==========================================
          // ABA 1: Novo Bloqueio
          // ==========================================
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(height: 4),

              // Data
              Text('Data', style: TextStyle(color: AppTheme.corTextoSecundario, fontSize: 13)),
              SizedBox(height: 8),
              GestureDetector(
                onTap: _selecionarData,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _dataIni != null ? cor.withOpacity(0.1) : AppTheme.corCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _dataIni != null ? cor.withOpacity(0.5) : Colors.transparent),
                  ),
                  child: Row(children: [
                    Icon(Icons.calendar_today, color: cor),
                    SizedBox(width: 12),
                    Text(
                      _dataIni != null ? DateFormat('dd/MM/yyyy').format(_dataIni!) : 'Toque para selecionar',
                      style: TextStyle(
                        color: _dataIni != null ? AppTheme.corTexto : AppTheme.corTextoSecundario,
                        fontWeight: _dataIni != null ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ]),
                ),
              ),
              SizedBox(height: 16),

              // Horários
              Text('Horário', style: TextStyle(color: AppTheme.corTextoSecundario, fontSize: 13)),
              SizedBox(height: 8),
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => _selecionarHora(true),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _horaIni != null ? cor.withOpacity(0.1) : AppTheme.corCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _horaIni != null ? cor.withOpacity(0.5) : Colors.transparent),
                    ),
                    child: Row(children: [
                      Icon(Icons.access_time, color: cor, size: 18),
                      SizedBox(width: 8),
                      Text(
                        _horaIni?.format(context) ?? 'Início',
                        style: TextStyle(
                          color: _horaIni != null ? AppTheme.corTexto : AppTheme.corTextoSecundario,
                          fontWeight: _horaIni != null ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ]),
                  ),
                )),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('até', style: TextStyle(color: cor)),
                ),
                Expanded(child: GestureDetector(
                  onTap: () => _selecionarHora(false),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _horaFim != null ? cor.withOpacity(0.1) : AppTheme.corCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _horaFim != null ? cor.withOpacity(0.5) : Colors.transparent),
                    ),
                    child: Row(children: [
                      Icon(Icons.access_time, color: cor, size: 18),
                      SizedBox(width: 8),
                      Text(
                        _horaFim?.format(context) ?? 'Fim',
                        style: TextStyle(
                          color: _horaFim != null ? AppTheme.corTexto : AppTheme.corTextoSecundario,
                          fontWeight: _horaFim != null ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ]),
                  ),
                )),
              ]),
              SizedBox(height: 16),

              // Repetir todos os dias
              Container(
                decoration: BoxDecoration(
                  color: _repetirTodosDias ? cor.withOpacity(0.1) : AppTheme.corCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _repetirTodosDias ? cor.withOpacity(0.4) : Colors.transparent),
                ),
                child: Column(children: [
                  SwitchListTile(
                    value: _repetirTodosDias,
                    activeColor: cor,
                    onChanged: (v) => setState(() => _repetirTodosDias = v),
                    title: Text('Repetir todos os dias',
                        style: TextStyle(color: AppTheme.corTexto, fontWeight: FontWeight.w600)),
                    subtitle: Text('Bloqueia este horário diariamente',
                        style: TextStyle(color: AppTheme.corTextoSecundario, fontSize: 12)),
                    secondary: Icon(Icons.repeat, color: cor),
                  ),
                  if (_repetirTodosDias) Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Repetir por $_diasRepeticao dias',
                          style: TextStyle(color: cor, fontWeight: FontWeight.w500, fontSize: 13)),
                      Slider(
                        value: _diasRepeticao.toDouble(),
                        min: 7, max: 90, divisions: 11,
                        activeColor: cor,
                        inactiveColor: cor.withOpacity(0.2),
                        label: '$_diasRepeticao dias',
                        onChanged: (v) => setState(() => _diasRepeticao = v.toInt()),
                      ),
                      Text('Dias com agendamentos serão pulados automaticamente',
                          style: TextStyle(color: AppTheme.corTextoSecundario, fontSize: 11)),
                    ]),
                  ),
                ]),
              ),
              SizedBox(height: 16),

              // Motivo
              Text('Motivo', style: TextStyle(color: AppTheme.corTextoSecundario, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _motivosPadrao.map((m) {
                  final sel = _motivo == m;
                  return GestureDetector(
                    onTap: () => setState(() => _motivo = m),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? cor : AppTheme.corCard,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(m, style: TextStyle(
                        color: sel ? AppTheme.corFundo : AppTheme.corTexto,
                        fontWeight: FontWeight.w500, fontSize: 13,
                      )),
                    ),
                  );
                }).toList(),
              ),
              if (_motivo == 'Outro...') ...[
                SizedBox(height: 10),
                TextField(controller: _motivoCtrl,
                    style: TextStyle(color: AppTheme.corTexto),
                    decoration: const InputDecoration(labelText: 'Descreva o motivo')),
              ],
              SizedBox(height: 24),

              ElevatedButton(
                onPressed: _salvando ? null : _bloquear,
                child: _salvando
                    ? SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(color: AppTheme.corFundo, strokeWidth: 2))
                    : Text(_repetirTodosDias
                        ? 'Bloquear por $_diasRepeticao dias'
                        : 'Bloquear Período'),
              ),
            ]),
          ),

          // ==========================================
          // ABA 2: Bloqueios Ativos
          // ==========================================
          _carregandoBloqueios
              ? Center(child: CircularProgressIndicator(color: cor))
              : _bloqueios.isEmpty
                  ? Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, color: cor.withOpacity(0.4), size: 64),
                        SizedBox(height: 16),
                        Text('Nenhum bloqueio ativo.',
                            style: TextStyle(color: AppTheme.corTextoSecundario)),
                      ],
                    ))
                  : Column(children: [
                      // Botão excluir todos
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: OutlinedButton.icon(
                          onPressed: _excluirTodos,
                          icon: Icon(Icons.delete_sweep, color: AppTheme.corErro),
                          label: Text('Excluir todos (${_bloqueios.length})',
                              style: TextStyle(color: AppTheme.corErro)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.corErro),
                            minimumSize: const Size(double.infinity, 44),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                              final b   = _bloqueios[i];
                              final ini = DateTime.parse(b['data_hora_ini']);
                              final fim = DateTime.parse(b['data_hora_fim']);
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: AppTheme.corCard,
                                  borderRadius: BorderRadius.circular(14),
                                  border: const Border(left: BorderSide(color: AppTheme.corErro, width: 4)),
                                ),
                                child: ListTile(
                                  leading: Icon(Icons.block, color: AppTheme.corErro),
                                  title: Text(
                                    '${DateFormat('dd/MM/yy').format(ini)}  ${DateFormat('HH:mm').format(ini)} – ${DateFormat('HH:mm').format(fim)}',
                                    style: TextStyle(color: AppTheme.corTexto, fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: b['motivo'] != null
                                      ? Text(b['motivo'], style: TextStyle(
                                          color: AppTheme.corTextoSecundario, fontSize: 12))
                                      : null,
                                  trailing: IconButton(
                                    icon: Icon(Icons.delete_outline, color: AppTheme.corErro),
                                    onPressed: () async {
                                      final ok = await showDialog<bool>(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          backgroundColor: AppTheme.corFundoSecundario,
                                          title: Text('Remover bloqueio?',
                                              style: TextStyle(color: AppTheme.corTexto)),
                                          content: Text(
                                            '${DateFormat('dd/MM/yy').format(ini)} · ${DateFormat('HH:mm').format(ini)}–${DateFormat('HH:mm').format(fim)}',
                                            style: TextStyle(color: AppTheme.corTextoSecundario),
                                          ),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(context, false),
                                                child: Text('Cancelar',
                                                    style: TextStyle(color: AppTheme.corTextoSecundario))),
                                            TextButton(onPressed: () => Navigator.pop(context, true),
                                                child: Text('Remover',
                                                    style: TextStyle(color: AppTheme.corErro))),
                                          ],
                                        ),
                                      );
                                      if (ok == true) await _remover(b['id']);
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
    );
  }
}