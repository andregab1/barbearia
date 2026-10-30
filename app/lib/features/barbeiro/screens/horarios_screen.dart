import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/premium_ui.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/api_service.dart';
import '../../../shared/widgets/app_toast.dart';
import 'bloquear_horario_screen.dart';

class HorariosScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const HorariosScreen({super.key, this.onBack});
  @override
  State<HorariosScreen> createState() => _HorariosScreenState();
}

class _HorariosScreenState extends State<HorariosScreen> {
  static const _labels = [
    'Segunda',
    'Terca',
    'Quarta',
    'Quinta',
    'Sexta',
    'Sabado',
    'Domingo'
  ];
  static const _dayOrder = [1, 2, 3, 4, 5, 6, 0];
  final Map<int, bool> _ativo = {};
  final Map<int, String> _horaInicio = {};
  final Map<int, String> _horaFim = {};
  List<Map<String, dynamic>> _colaboradores = [];
  Map<String, dynamic>? _colaboradorSel;
  int? _colaboradorId;
  String _role = '';
  bool _carregando = true;
  bool _carregandoHorarios = false;
  bool _salvando = false;
  String _modelo = 'Comercial';
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _defaults();
    _inicializar();
  }

  @override
  void dispose() {
    _requestId++;
    super.dispose();
  }

  void _defaults() {
    for (var i = 0; i < 7; i++) {
      _ativo[i] = i != 0;
      _horaInicio[i] = '08:00';
      _horaFim[i] = '18:00';
    }
  }

  Future<void> _inicializar() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    _role = prefs.getString(AppConstants.keyUsuarioRole) ?? '';
    final usuarioId = prefs.getInt(AppConstants.keyUsuarioId) ?? 0;
    if (_role == AppConstants.roleAdmin) {
      await _carregarColaboradores();
      if (_colaboradores.isNotEmpty)
        await _selecionarBarbeiro(_colaboradores.first);
    } else {
      final result = await ApiService.get('/colaboradores/usuario/$usuarioId');
      if (result['id'] != null) {
        _colaboradorId = result['id'];
        await _carregarHorarios(_colaboradorId!);
      }
    }
    if (mounted) setState(() => _carregando = false);
  }

  Future<void> _carregarColaboradores() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt(AppConstants.keyBarbeariaId) ?? 1;
    final result = await ApiService.get('/colaboradores/$id');
    if (!mounted || result.containsKey('erro')) return;
    final raw = result['data'] is List ? result['data'] : result;
    if (raw is List)
      setState(() => _colaboradores =
          raw.map((e) => Map<String, dynamic>.from(e)).toList());
  }

  Future<void> _selecionarBarbeiro(Map<String, dynamic> colab) async {
    setState(() {
      _colaboradorSel = colab;
      _colaboradorId = int.tryParse('${colab['id']}');
      _carregandoHorarios = true;
    });
    await _carregarHorarios(_colaboradorId!);
    if (mounted) setState(() => _carregandoHorarios = false);
  }

  Future<void> _carregarHorarios(int id) async {
    final request = ++_requestId;
    final result = await ApiService.get('/horarios/$id');
    if (!mounted || request != _requestId || result.containsKey('erro')) return;
    for (var i = 0; i < 7; i++) {
      final item = result['$i'];
      if (item is Map) {
        _ativo[i] = item['ativo'] == true;
        _horaInicio[i] = '${item['hora_inicio'] ?? '08:00'}';
        _horaFim[i] = '${item['hora_fim'] ?? '18:00'}';
      }
    }
    setState(() {});
  }

  Future<void> _selecionarHora(int dia, bool inicio) async {
    final atual = inicio ? _horaInicio[dia]! : _horaFim[dia]!;
    final p = atual.split(':');
    final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1])));
    if (picked == null || !mounted) return;
    final value =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() {
      if (inicio) {
        _horaInicio[dia] = value;
      } else {
        _horaFim[dia] = value;
      }
    });
  }

  Future<void> _salvar() async {
    if (_colaboradorId == null) return;
    setState(() => _salvando = true);
    final horarios = <String, dynamic>{};
    for (var i = 0; i < 7; i++) {
      horarios['$i'] = {
        'ativo': _ativo[i] == true,
        'hora_inicio': _horaInicio[i],
        'hora_fim': _horaFim[i]
      };
    }
    final result = await ApiService.post(
        '/horarios/$_colaboradorId', {'horarios': horarios});
    if (!mounted) return;
    setState(() => _salvando = false);
    AppToast.show(
        context,
        result.containsKey('erro')
            ? '${result['erro']}'
            : 'Horarios salvos com sucesso.',
        type: result.containsKey('erro')
            ? AppToastType.error
            : AppToastType.success);
  }

  void _aplicarModelo() {
    setState(() {
      for (var i = 0; i < 7; i++) {
        final day = _dayOrder[i];
        _ativo[day] = day != 0;
        _horaInicio[day] = day == 6 ? '09:00' : '08:00';
        _horaFim[day] = day == 6 ? '14:00' : '18:00';
      }
    });
    AppToast.show(context, 'Modelo $_modelo aplicado. Salve para confirmar.',
        type: AppToastType.success);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final pageActions = <Widget>[];
    if (_carregando)
      return PremiumPage(
          title: 'Horarios de atendimento',
          subtitle: 'Configure os horarios da equipe.',
          actions: pageActions,
          child: const PremiumLoadingState(label: 'Carregando horarios'));
    return PremiumPage(
      title: 'Horarios de atendimento',
      subtitle:
          'Configure os horarios de cada profissional e mantenha sua agenda organizada.',
      actions: pageActions,
      headingFontSize: 28,
      child: _carregandoHorarios
          ? Center(child: CircularProgressIndicator(color: primary))
          : SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 28),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _topBar(primary),
                    SizedBox(height: 12),
                    LayoutBuilder(builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 1080;
                      final bloqueio = BloquearHorarioScreen(
                        embedded: true,
                        colaboradorId: _colaboradorId,
                      );
                      if (!wide) {
                        return Column(children: [
                          _weeklySchedule(primary),
                          SizedBox(height: 12),
                          bloqueio,
                        ]);
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _weeklySchedule(primary)),
                          SizedBox(width: 12),
                          SizedBox(width: 360, child: bloqueio),
                        ],
                      );
                    }),
                    SizedBox(height: 12),
                    _models(primary),
                  ]),
            ),
    );
  }

  Widget _topBar(Color primary) {
    final selected = _colaboradorSel;
    final isAdmin = _role == AppConstants.roleAdmin;
    return Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 12,
        children: [
          if (isAdmin)
            Container(
                width: 285,
                height: 58,
                padding: EdgeInsets.symmetric(horizontal: 12),
                decoration: _panel(),
                child: Row(children: [
                  Text('Profissional', style: _muted(11)),
                  SizedBox(width: 10),
                  Expanded(
                      child: DropdownButtonHideUnderline(
                          child: DropdownButton<Map<String, dynamic>>(
                    isExpanded: true,
                    value: selected,
                    dropdownColor: AppTheme.surfaceElev,
                    icon: Icon(Icons.keyboard_arrow_down),
                    items: _colaboradores
                        .map((c) => DropdownMenuItem(
                            value: c,
                            child: Row(children: [
                              CircleAvatar(
                                  radius: 13,
                                  backgroundColor:
                                      primary.withValues(alpha: .16),
                                  child: Text(
                                      '${c['nome']}'.isEmpty
                                          ? '?'
                                          : '${c['nome']}'[0].toUpperCase(),
                                      style: TextStyle(
                                          color: primary, fontSize: 11))),
                              SizedBox(width: 8),
                              Expanded(
                                  child: Text('${c['nome']}',
                                      overflow: TextOverflow.ellipsis,
                                      style: _strong(12))),
                            ])))
                        .toList(),
                    onChanged: (c) {
                      if (c != null) _selecionarBarbeiro(c);
                    },
                  ))),
                ])),
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (isAdmin)
              OutlinedButton.icon(
                  onPressed: () => AppToast.show(
                      context, 'Cadastre o profissional na aba Equipe.'),
                  icon: Icon(Icons.person_add_alt_1, size: 16),
                  label: Text('Novo profissional')),
            if (isAdmin) SizedBox(width: 12),
            OutlinedButton.icon(
                onPressed: _aplicarModelo,
                icon: Icon(Icons.save_alt_outlined, size: 16),
                label: Text('Aplicar modelo')),
            SizedBox(width: 8),
            FilledButton.icon(
                onPressed: _salvando ? null : _salvar,
                icon: Icon(Icons.save_outlined, size: 16),
                label: Text(_salvando ? 'Salvando...' : 'Salvar alteracoes')),
          ]),
        ]);
  }

  Widget _weeklySchedule(Color primary) => Container(
      padding: EdgeInsets.all(14),
      decoration: _panel(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Agenda semanal', style: _strong(15)),
                  SizedBox(height: 3),
                  Text(
                      'Defina os dias e horarios de atendimento deste profissional.',
                      style: _muted(11))
                ])),
            Icon(Icons.lightbulb_outline, size: 17)
          ],
        ),
        SizedBox(height: 12),
        LayoutBuilder(builder: (context, constraints) {
          final compact = constraints.maxWidth < 880;
          return compact
              ? Column(
                  children: List.generate(
                      7,
                      (i) => Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: _dayCard(_dayOrder[i], _labels[i], primary))))
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(
                      7,
                      (i) => Expanded(
                          child: Padding(
                              padding: EdgeInsets.only(right: i == 6 ? 0 : 7),
                              child: _dayCard(
                                  _dayOrder[i], _labels[i], primary)))));
        }),
      ]));

  Widget _dayCard(int day, String label, Color primary) {
    final active = _ativo[day] == true;
    final ranges = _ranges(day);
    return Container(
        padding: EdgeInsets.all(9),
        decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color:
                    active ? primary.withValues(alpha: .28) : AppTheme.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: _strong(11)),
          Row(children: [
            Expanded(
                child: Text(active ? 'Ativo' : 'Inativo',
                    style: TextStyle(
                        color: active ? primary : AppTheme.corTextoSecundario,
                        fontSize: 9,
                        fontWeight: FontWeight.w600))),
            Transform.scale(
                scale: .65,
                alignment: Alignment.centerRight,
                child: Switch(
                    value: active,
                    activeThumbColor: primary,
                    onChanged: (v) => setState(() => _ativo[day] = v)))
          ]),
          if (active)
            ...ranges.map((range) => Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: InkWell(
                    onTap: () => _selecionarHora(day, range == ranges.first),
                    child: Container(
                        width: double.infinity,
                        padding:
                            EdgeInsets.symmetric(horizontal: 7, vertical: 6),
                        decoration: BoxDecoration(
                            border: Border.all(
                                color: primary.withValues(alpha: .55)),
                            borderRadius: BorderRadius.circular(12)),
                        child: Row(children: [
                          Expanded(
                              child: Text(range,
                                  style: TextStyle(
                                      color: AppTheme.corTexto, fontSize: 9))),
                          Icon(Icons.close, size: 11, color: primary)
                        ]))))),
          if (!active)
            Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                    child: Text('Sem horarios\nconfigurados',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 9, color: AppTheme.corTextoSecundario)))),
          TextButton.icon(
              onPressed: () => _selecionarHora(day, true),
              icon: Icon(Icons.add, size: 13, color: primary),
              label: Text('Adicionar horario',
                  style: TextStyle(color: primary, fontSize: 9))),
        ]));
  }

  List<String> _ranges(int day) {
    final start = _horaInicio[day] ?? '08:00';
    final end = _horaFim[day] ?? '18:00';
    if (start == '08:00' && end == '18:00')
      return const ['08:00 - 12:00', '13:00 - 18:00'];
    return ['$start - $end'];
  }

  Widget _models(Color primary) => Container(
      padding: EdgeInsets.all(14),
      decoration: _panel(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Modelos de agenda', style: _strong(15)),
                SizedBox(height: 3),
                Text(
                    'Aplique um modelo padrão para configurar os horarios rapidamente.',
                    style: _muted(11))
              ])),
          TextButton(
              onPressed: _aplicarModelo,
              child: Text('Usar modelo',
                  style: TextStyle(
                      color: primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11)))
        ]),
        SizedBox(height: 10),
        LayoutBuilder(builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final cards = [
            _modelCard('Comercial', 'Segunda a sexta, 08h as 18h',
                Icons.business_center_outlined, primary, 'Mais usado'),
            _modelCard('Estendido', 'Segunda a sabado, 08h as 20h',
                Icons.wb_sunny_outlined, primary, ''),
            _modelCard(
                'Sabado reduzido',
                'Segunda a sexta, 08h as 18h\nSabado, 09h as 14h',
                Icons.schedule,
                primary,
                '')
          ];
          return compact
              ? Column(
                  children: cards
                      .map((e) => Padding(
                          padding: EdgeInsets.only(bottom: 8), child: e))
                      .toList())
              : Row(
                  children: cards
                      .map((e) => Expanded(
                          child: Padding(
                              padding: EdgeInsets.only(right: 8), child: e)))
                      .toList());
        }),
      ]));

  Widget _modelCard(String name, String description, IconData icon,
      Color primary, String badge) {
    final selected = _modelo == name;
    return InkWell(
        onTap: () => setState(() => _modelo = name),
        child: Container(
            height: 82,
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: selected
                    ? primary.withValues(alpha: .08)
                    : AppTheme.surface,
                border: Border.all(
                    color: selected ? primary : AppTheme.border,
                    width: selected ? 1.4 : 1),
                borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: primary.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(6)),
                  child: Icon(icon, color: primary, size: 20)),
              SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    Row(children: [
                      Expanded(child: Text(name, style: _strong(11))),
                      if (badge.isNotEmpty)
                        Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                                color: primary,
                                borderRadius: BorderRadius.circular(8)),
                            child: Text(badge,
                                style: TextStyle(
                                    fontSize: 8, fontWeight: FontWeight.w700)))
                    ]),
                    SizedBox(height: 4),
                    Text(description, maxLines: 2, style: _muted(9))
                  ])),
              Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected ? primary : AppTheme.corTextoSecundario,
                  size: 15)
            ])));
  }

  BoxDecoration _panel() => BoxDecoration(
      color: AppTheme.surfaceElev,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppTheme.border));
  TextStyle _strong(double size) => GoogleFonts.inter(
      color: AppTheme.corTexto, fontSize: size, fontWeight: FontWeight.w700);
  TextStyle _muted(double size) =>
      GoogleFonts.inter(color: AppTheme.corTextoSecundario, fontSize: size);
}
