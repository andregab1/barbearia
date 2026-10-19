import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/api_service.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/premium_ui.dart';
import 'bloquear_horario_screen.dart';
import '../domain/schedule_models.dart';
import '../domain/schedule_utils.dart';

class HorariosScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const HorariosScreen({super.key, this.onBack});

  @override
  State<HorariosScreen> createState() => _HorariosScreenState();
}

class _HorariosScreenState extends State<HorariosScreen> {
  static const _dayOrder = [1, 2, 3, 4, 5, 6, 0];
  static const _dayLabels = {
    0: 'Domingo',
    1: 'Segunda',
    2: 'Terça',
    3: 'Quarta',
    4: 'Quinta',
    5: 'Sexta',
    6: 'Sábado',
  };
  static const _hourHeight = 35.0;
  static const _timelineHeight = 14 * _hourHeight;

  final GlobalKey _templatesKey = GlobalKey();
  final Map<int, String> _dayError = {};
  List<Map<String, dynamic>> _colaboradores = [];
  Map<String, dynamic>? _colaboradorSelecionado;
  WeeklySchedule? _persistedSchedule;
  WeeklySchedule? _draftSchedule;
  int? _colaboradorId;
  String _role = '';
  String _selectedTemplateId = 'extended';
  bool _showBreaks = true;
  bool _loading = true;
  bool _loadingSchedule = false;
  bool _saving = false;
  String? _error;
  int _requestId = 0;
  ScheduleRange? _gestureRange;
  int? _gestureDay;
  String? _gestureMode;
  double _gestureDeltaY = 0;

  @override
  void initState() {
    super.initState();
    _draftSchedule = _fallbackSchedule(0);
    _inicializar();
  }

  @override
  void dispose() {
    _requestId++;
    super.dispose();
  }

  WeeklySchedule _fallbackSchedule(int professionalId) {
    ScheduleRange range(String id, String start, String end) =>
        ScheduleRange(id: id, start: start, end: end);

    final days = <DaySchedule>[];
    for (var weekday = 0; weekday < 7; weekday++) {
      if (weekday == 0) {
        days.add(const DaySchedule(weekday: 0, enabled: false, ranges: []));
      } else if (weekday == 6) {
        days.add(DaySchedule(
          weekday: weekday,
          enabled: true,
          ranges: [range('$weekday-morning', '09:00', '14:00')],
        ));
      } else {
        days.add(DaySchedule(
          weekday: weekday,
          enabled: true,
          ranges: [
            range('$weekday-morning', '08:00', '12:00'),
            range('$weekday-afternoon', '13:00', '18:00'),
          ],
        ));
      }
    }
    return WeeklySchedule(professionalId: professionalId, days: days);
  }

  Future<void> _inicializar() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    _role = preferences.getString(AppConstants.keyUsuarioRole) ?? '';
    final usuarioId = preferences.getInt(AppConstants.keyUsuarioId) ?? 0;

    if (_role == AppConstants.roleAdmin) {
      await _carregarColaboradores();
      if (_colaboradores.isNotEmpty) {
        await _selecionarBarbeiro(_colaboradores.first);
      } else if (mounted) {
        setState(
            () => _error = 'Nenhum profissional disponível para configurar.');
      }
    } else {
      final result = await ApiService.get('/colaboradores/usuario/$usuarioId');
      if (result['id'] != null) {
        _colaboradorId = int.tryParse('${result['id']}');
        if (_colaboradorId != null) await _carregarHorarios(_colaboradorId!);
      } else if (mounted) {
        setState(() => _error = result['erro']?.toString() ??
            'Não foi possível localizar seu profissional.');
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _carregarColaboradores() async {
    final preferences = await SharedPreferences.getInstance();
    final barbeariaId = preferences.getInt(AppConstants.keyBarbeariaId) ?? 1;
    final result = await ApiService.get('/colaboradores/$barbeariaId');
    if (!mounted || result.containsKey('erro')) {
      if (mounted) setState(() => _error = result['erro']?.toString());
      return;
    }
    final raw = result['data'] is List ? result['data'] : result;
    if (raw is List) {
      setState(() => _colaboradores =
          raw.map((item) => Map<String, dynamic>.from(item)).toList());
    }
  }

  Future<void> _selecionarBarbeiro(Map<String, dynamic> colaborador) async {
    final id = int.tryParse('${colaborador['id']}');
    if (id == null) return;
    setState(() {
      _colaboradorSelecionado = colaborador;
      _colaboradorId = id;
      _loadingSchedule = true;
      _error = null;
    });
    await _carregarHorarios(id);
    if (mounted) setState(() => _loadingSchedule = false);
  }

  Future<void> _carregarHorarios(int professionalId) async {
    final request = ++_requestId;
    final result = await ApiService.get('/horarios/$professionalId');
    if (!mounted || request != _requestId) return;
    if (result.containsKey('erro')) {
      setState(() => _error = result['erro']?.toString() ??
          'Não foi possível carregar os horários.');
      return;
    }
    final schedule = WeeklySchedule.fromApi(professionalId, result);
    setState(() {
      _persistedSchedule = schedule;
      _draftSchedule = schedule;
      _error = null;
      _dayError.clear();
    });
  }

  WeeklySchedule get _schedule =>
      _draftSchedule ?? _fallbackSchedule(_colaboradorId ?? 0);

  bool get _dirty {
    final persisted = _persistedSchedule;
    final draft = _draftSchedule;
    if (persisted == null || draft == null) return false;
    return _scheduleSignature(persisted) != _scheduleSignature(draft);
  }

  String _scheduleSignature(WeeklySchedule schedule) {
    return schedule.days
        .map((day) =>
            '${day.weekday}:${day.enabled}:${day.ranges.map((range) => '${range.start}-${range.end}').join(',')}')
        .join('|');
  }

  void _updateDay(DaySchedule updatedDay) {
    final days = _schedule.days
        .map((day) => day.weekday == updatedDay.weekday ? updatedDay : day)
        .toList();
    setState(() {
      _draftSchedule = _schedule.copyWith(days: days);
      _dayError.remove(updatedDay.weekday);
    });
  }

  Future<void> _toggleDay(DaySchedule day) async {
    if (day.enabled && day.ranges.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => _ConfirmationDialog(
          title: 'Desativar ${_dayLabels[day.weekday]}?',
          message:
              'Os horários serão mantidos no rascunho e poderão ser reativados depois.',
          confirmLabel: 'Desativar dia',
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    _updateDay(day.copyWith(enabled: !day.enabled));
  }

  Future<void> _openDisableDayDialog() async {
    final activeDays = _schedule.days.where((day) => day.enabled).toList();
    if (activeDays.isEmpty) {
      AppToast.show(context, 'Não há dias ativos para inativar.',
          type: AppToastType.info);
      return;
    }

    final weekday = await showDialog<int>(
      context: context,
      builder: (context) => _DaySelectionDialog(
        title: 'Inativar dia',
        description: 'Escolha o dia que não terá atendimento.',
        days: activeDays,
        labels: _dayLabels,
        confirmLabel: 'Continuar',
      ),
    );
    if (weekday == null || !mounted) return;
    await _toggleDay(_schedule.day(weekday));
  }

  Future<void> _saveSchedule() async {
    if (_colaboradorId == null || _saving) return;
    final validationErrors = validateWeeklySchedule(_schedule);
    if (validationErrors.isNotEmpty) {
      AppToast.show(context, validationErrors.first, type: AppToastType.error);
      return;
    }
    setState(() => _saving = true);
    final result = await ApiService.post(
        '/horarios/$_colaboradorId', _schedule.toApiPayload());
    if (!mounted) return;
    if (result.containsKey('erro')) {
      setState(() => _saving = false);
      AppToast.show(context, result['erro'].toString(),
          type: AppToastType.error);
      return;
    }
    await _carregarHorarios(_colaboradorId!);
    if (!mounted) return;
    setState(() => _saving = false);
    AppToast.show(context, 'Horários atualizados com sucesso.',
        type: AppToastType.success);
  }

  Future<void> _applySelectedTemplate({bool focusIfMissing = false}) async {
    final template =
        _templates.firstWhere((item) => item.id == _selectedTemplateId);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmationDialog(
        title: 'Aplicar modelo ${template.name}?',
        message:
            'Isso substituirá os horários que você está editando. A alteração só será salva ao clicar em “Salvar alterações”.',
        confirmLabel: 'Aplicar modelo',
      ),
    );
    if (confirmed == true && mounted) {
      setState(
          () => _draftSchedule = applyScheduleTemplate(_schedule, template));
      AppToast.show(
          context, 'Modelo ${template.name} aplicado. Salve para confirmar.',
          type: AppToastType.success);
    } else if (focusIfMissing &&
        mounted &&
        _templatesKey.currentContext != null) {
      Scrollable.ensureVisible(_templatesKey.currentContext!,
          duration: const Duration(milliseconds: 350));
    }
  }

  Future<void> _openRangeEditor(int weekday, {ScheduleRange? range}) async {
    final result = await showDialog<_RangeDialogResult>(
      context: context,
      builder: (context) => _RangeDialog(range: range),
    );
    if (result == null || !mounted) return;
    final day = _schedule.day(weekday);
    if (result.deleted && range != null) {
      _updateDay(day.copyWith(
          ranges: day.ranges.where((item) => item.id != range.id).toList()));
      return;
    }
    if (result.start == null || result.end == null) return;
    final edited = ScheduleRange(
      id: range?.id ?? '$weekday-${DateTime.now().microsecondsSinceEpoch}',
      start: result.start!,
      end: result.end!,
    );
    final nextRanges = range == null
        ? [...day.ranges, edited]
        : day.ranges
            .map((item) => item.id == range.id ? edited : item)
            .toList();
    final nextDay = day.copyWith(enabled: true, ranges: sortRanges(nextRanges));
    final errors = validateDay(nextDay);
    if (errors.isNotEmpty) {
      AppToast.show(context, errors.first, type: AppToastType.error);
      return;
    }
    _updateDay(nextDay);
  }

  void _deleteRange(int weekday, ScheduleRange range) {
    final day = _schedule.day(weekday);
    _updateDay(day.copyWith(
        ranges: day.ranges.where((item) => item.id != range.id).toList()));
  }

  void _beginGesture(int weekday, ScheduleRange range, String mode) {
    _gestureDay = weekday;
    _gestureRange = range;
    _gestureMode = mode;
    _gestureDeltaY = 0;
  }

  void _updateGesture(double deltaY) {
    final day = _gestureDay;
    final original = _gestureRange;
    final mode = _gestureMode;
    if (day == null || original == null || mode == null) return;
    _gestureDeltaY += deltaY;
    final deltaMinutes =
        snapMinutesValue((_gestureDeltaY / _hourHeight * 60).round());
    final originalStart = timeToMinutes(original.start);
    final originalEnd = timeToMinutes(original.end);
    var nextStart = originalStart;
    var nextEnd = originalEnd;
    if (mode == 'move') {
      nextStart = _clampMinutes(originalStart + deltaMinutes, dayStartMinutes,
          dayEndMinutes - (originalEnd - originalStart));
      nextEnd = nextStart + (originalEnd - originalStart);
    } else if (mode == 'start') {
      nextStart = _clampMinutes(originalStart + deltaMinutes, dayStartMinutes,
          originalEnd - snapMinutes);
    } else {
      nextEnd = _clampMinutes(originalEnd + deltaMinutes,
          originalStart + snapMinutes, dayEndMinutes);
    }
    final next = original.copyWith(
        start: minutesToTime(nextStart), end: minutesToTime(nextEnd));
    final daySchedule = _schedule.day(day);
    final nextDay = daySchedule.copyWith(
        ranges: daySchedule.ranges
            .map((item) => item.id == original.id ? next : item)
            .toList());
    if (validateDay(nextDay).isEmpty) _updateDay(nextDay);
  }

  void _endGesture() {
    _gestureDay = null;
    _gestureRange = null;
    _gestureMode = null;
    _gestureDeltaY = 0;
  }

  int _clampMinutes(int value, int minimum, int maximum) =>
      math.max(minimum, math.min(maximum, value));

  Future<void> _openCopyDialog({bool weekdaysOnly = false}) async {
    final result = await showDialog<_CopyDialogResult>(
      context: context,
      builder: (context) => _CopyDialog(weekdaysOnly: weekdaysOnly),
    );
    if (result == null || !mounted) return;
    final sourceDay = _schedule.day(result.source);
    final days = _schedule.days.map((day) {
      if (!result.targets.contains(day.weekday)) return day;
      return copyScheduleDay(sourceDay, day.weekday);
    }).toList();
    setState(() => _draftSchedule = _schedule.copyWith(days: days));
    AppToast.show(context, 'Horários copiados no rascunho.',
        type: AppToastType.success);
  }

  List<ScheduleTemplate> get _templates {
    List<ScheduleRange> ranges(String prefix, String start, String end,
        {String? secondStart, String? secondEnd}) {
      return [
        ScheduleRange(id: '$prefix-1', start: start, end: end),
        if (secondStart != null && secondEnd != null)
          ScheduleRange(id: '$prefix-2', start: secondStart, end: secondEnd),
      ];
    }

    final commercialDays = <int, ScheduleTemplateDay>{
      for (var weekday = 1; weekday <= 5; weekday++)
        weekday: ScheduleTemplateDay(
            enabled: true,
            ranges: ranges('commercial-$weekday', '08:00', '12:00',
                secondStart: '13:00', secondEnd: '18:00')),
    };
    final extendedDays = <int, ScheduleTemplateDay>{
      for (var weekday = 1; weekday <= 6; weekday++)
        weekday: ScheduleTemplateDay(
            enabled: true,
            ranges: ranges('extended-$weekday', '08:00', '12:00',
                secondStart: '13:00', secondEnd: '20:00')),
    };
    final reducedSaturdayDays = <int, ScheduleTemplateDay>{
      ...commercialDays,
      6: ScheduleTemplateDay(
          enabled: true, ranges: ranges('reduced-saturday', '09:00', '14:00')),
    };
    return [
      ScheduleTemplate(
          id: 'commercial',
          name: 'Comercial',
          description: 'Segunda a sexta, 08h às 18h',
          days: commercialDays),
      ScheduleTemplate(
          id: 'extended',
          name: 'Estendido',
          description: 'Segunda a sábado, 08h às 20h',
          days: extendedDays),
      ScheduleTemplate(
          id: 'reduced-saturday',
          name: 'Sábado reduzido',
          description: 'Segunda a sexta, 08h às 18h\nSábado, 09h às 14h',
          days: reducedSaturdayDays),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: PremiumColors.background,
      child: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          final compact = constraints.maxWidth < 1100;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                compact ? 16 : 32, compact ? 20 : 27, compact ? 16 : 32, 32),
            child: _loading ? _buildLoading(compact) : _buildContent(compact),
          );
        }),
      ),
    );
  }

  Widget _buildLoading(bool compact) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildHeader(compact, loading: true),
        const SizedBox(height: 22),
        Container(height: 620, decoration: _panelDecoration())
      ]);

  Widget _buildContent(bool compact) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _buildHeader(compact),
        const SizedBox(height: 22),
        if (_error != null) ...[_buildErrorState(), const SizedBox(height: 16)],
        if (_loadingSchedule)
          const SizedBox(
              height: 640,
              child: Center(
                  child: CircularProgressIndicator(color: PremiumColors.gold)))
        else
          _buildWorkspace(),
      ]);

  Widget _buildHeader(bool compact, {bool loading = false}) {
    final actions = Row(mainAxisSize: MainAxisSize.min, children: [
      OutlinedButton.icon(
          onPressed: loading
              ? null
              : () => _applySelectedTemplate(focusIfMissing: true),
          icon: const Icon(Icons.file_copy_outlined, size: 17),
          label: const Text('Aplicar modelo'),
          style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF75A9CF),
              side: const BorderSide(color: Color(0xFF41677D)),
              minimumSize: const Size(172, 51),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)))),
      const SizedBox(width: 12),
      FilledButton.icon(
          onPressed: loading || !_dirty ? null : _saveSchedule,
          icon: _saving
              ? const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.black))
              : const Icon(Icons.save_outlined, size: 17),
          label: Text(_saving ? 'Salvando...' : 'Salvar alterações'),
          style: FilledButton.styleFrom(
              backgroundColor: PremiumColors.gold,
              foregroundColor: Colors.black,
              disabledBackgroundColor:
                  PremiumColors.gold.withValues(alpha: .35),
              disabledForegroundColor: Colors.black54,
              minimumSize: const Size(192, 51),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)))),
    ]);
    final heading =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('HORÁRIOS', style: _eyebrowStyle),
      const SizedBox(height: 5),
      Text('Horários de atendimento', style: _headingStyle(compact)),
      const SizedBox(height: 7),
      Text(
          'Defina os horários de cada profissional e mantenha sua agenda organizada.',
          style: _subtitleStyle),
      if (_role == AppConstants.roleAdmin && _colaboradores.isNotEmpty) ...[
        const SizedBox(height: 16),
        _professionalSelector()
      ]
    ]);
    if (compact)
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        heading,
        const SizedBox(height: 18),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: actions)
      ]);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: heading),
      const SizedBox(width: 20),
      actions
    ]);
  }

  Widget _professionalSelector() => Container(
      width: 285,
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: _panelDecoration(color: PremiumColors.surfaceSecondary),
      child: Row(children: [
        const Icon(Icons.person_outline,
            color: PremiumColors.textMuted, size: 17),
        const SizedBox(width: 8),
        Expanded(
            child: DropdownButtonHideUnderline(
                child: DropdownButton<Map<String, dynamic>>(
                    value: _colaboradorSelecionado,
                    isExpanded: true,
                    dropdownColor: PremiumColors.surfaceSecondary,
                    icon: const Icon(Icons.keyboard_arrow_down,
                        color: PremiumColors.textSecondary),
                    style: _bodyStyle(PremiumColors.textPrimary, 12),
                    items: _colaboradores
                        .map((colaborador) => DropdownMenuItem(
                            value: colaborador,
                            child: Text(
                                '${colaborador['nome'] ?? 'Profissional'}',
                                overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) _selecionarBarbeiro(value);
                    })))
      ]));

  Widget _buildWorkspace() => LayoutBuilder(builder: (context, constraints) {
        final planner = _buildPlanner();
        final sidebar = _buildSidebar();
        if (constraints.maxWidth < 1180)
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [planner, const SizedBox(height: 18), sidebar]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: planner),
          const SizedBox(width: 20),
          SizedBox(width: 374, child: sidebar)
        ]);
      });

  Widget _buildPlanner() => Container(
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _buildPlannerHeader(),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, constraints) {
          final plannerWidth = math.max(1110.0, constraints.maxWidth);
          return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                  width: plannerWidth,
                  child: _buildTimelineGrid(plannerWidth)));
        })
      ]));

  Widget _buildPlannerHeader() =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: const Color(0xFF3B6073).withValues(alpha: .25),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.calendar_month_outlined,
                color: Color(0xFF79B3D7), size: 22)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Planejador semanal', style: _sectionTitleStyle),
          const SizedBox(height: 4),
          Text(
              'Clique nos blocos para editar os horários. Arraste para ajustar ou adicione novos períodos.',
              style: _bodyStyle(PremiumColors.textSecondary, 12))
        ])),
        const SizedBox(width: 12),
        Wrap(spacing: 18, runSpacing: 8, children: [
          _legend('Período da manhã', const Color(0xFF61B679)),
          _legend('Período da tarde', const Color(0xFF5D9DD1)),
          _legend('Inativo', const Color(0xFF898D91))
        ])
      ]);
  Widget _legend(String label, Color color) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: _bodyStyle(PremiumColors.textSecondary, 11))
      ]);

  Widget _buildTimelineGrid(double width) {
    const timeRailWidth = 58.0;
    final dayWidth = (width - timeRailWidth) / 7;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: PremiumColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: timeRailWidth, height: 95),
              ..._dayOrder.map(
                (day) => SizedBox(width: dayWidth, child: _buildDayHeader(day)),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: timeRailWidth, child: _buildTimeRail()),
              ..._dayOrder.map(
                (day) =>
                    SizedBox(width: dayWidth, child: _buildDayTimeline(day)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDayHeader(int weekday) {
    final day = _schedule.day(weekday);
    return Container(
        height: 95,
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
        decoration: BoxDecoration(
            border: Border(
                left: BorderSide(color: PremiumColors.border),
                bottom: BorderSide(color: PremiumColors.border))),
        child: Column(children: [
          Text(_dayLabels[weekday]!,
              style: _bodyStyle(PremiumColors.textPrimary, 13,
                  weight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(day.enabled ? 'Ativo' : 'Inativo',
              style: _bodyStyle(
                  day.enabled
                      ? const Color(0xFF6AA9D1)
                      : PremiumColors.textMuted,
                  11,
                  weight: FontWeight.w600)),
          const Spacer(),
          OutlinedButton.icon(
              onPressed: day.enabled
                  ? () => _openRangeEditor(weekday)
                  : () => _toggleDay(day),
              icon: Icon(day.enabled ? Icons.add : Icons.play_arrow_outlined,
                  size: 14),
              label: Text(day.enabled ? 'Adicionar horário' : 'Ativar dia'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: day.enabled
                      ? const Color(0xFF79B3D7)
                      : PremiumColors.textSecondary,
                  side: BorderSide(
                      color: day.enabled
                          ? const Color(0xFF35566D)
                          : PremiumColors.border),
                  minimumSize: const Size(0, 29),
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  textStyle: _bodyStyle(
                      day.enabled
                          ? const Color(0xFF79B3D7)
                          : PremiumColors.textSecondary,
                      10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7))))
        ]));
  }

  Widget _buildTimeRail() => SizedBox(
      height: _timelineHeight,
      child: Stack(children: [
        for (var index = 0; index <= 14; index++)
          Positioned(
              top: index * _hourHeight - 7,
              left: 8,
              child: Text('${(7 + index).toString().padLeft(2, '0')}:00',
                  style: _bodyStyle(PremiumColors.textSecondary, 10)))
      ]));

  Widget _buildDayTimeline(int weekday) {
    final day = _schedule.day(weekday);
    return Container(
        height: _timelineHeight,
        decoration: BoxDecoration(
            border: Border(left: BorderSide(color: PremiumColors.border)),
            color: PremiumColors.background.withValues(alpha: .42)),
        child: Stack(children: [
          for (var index = 0; index <= 14; index++)
            Positioned(
                top: index * _hourHeight,
                left: 0,
                right: 0,
                child: Container(
                    height: 1,
                    color: PremiumColors.border.withValues(alpha: .42))),
          if (!day.enabled) _buildInactiveDay(weekday),
          if (day.enabled) ...[
            ...(_showBreaks
                    ? deriveBreaks(day.ranges)
                    : const <ScheduleRange>[])
                .map(_buildBreakBlock),
            ...day.ranges.map((range) => _buildRangeBlock(weekday, range))
          ]
        ]));
  }

  Widget _buildInactiveDay(int weekday) => Center(
      child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.nightlight_outlined,
                color: PremiumColors.textMuted, size: 28),
            const SizedBox(height: 10),
            Text('Dia indisponível',
                textAlign: TextAlign.center,
                style: _bodyStyle(PremiumColors.textSecondary, 13,
                    weight: FontWeight.w700)),
            const SizedBox(height: 5),
            Text('Ative para definir\nhorários de\natendimento.',
                textAlign: TextAlign.center,
                style: _bodyStyle(PremiumColors.textMuted, 11, height: 1.35)),
            const SizedBox(height: 12),
            OutlinedButton(
                onPressed: () => _toggleDay(_schedule.day(weekday)),
                child: Text('Ativar dia',
                    style: _bodyStyle(const Color(0xFF79B3D7), 11)))
          ])));

  Widget _buildRangeBlock(int weekday, ScheduleRange range) {
    final start = timeToMinutes(range.start);
    final height = math.max(27.0, durationMinutes(range) / 60 * _hourHeight);
    final isMorning = start < 12 * 60;
    final color = isMorning ? const Color(0xFF65B97A) : const Color(0xFF5F9DD1);
    final background =
        isMorning ? const Color(0xFF173723) : const Color(0xFF183144);
    return Positioned(
        top: (start - dayStartMinutes) / 60 * _hourHeight + 3,
        left: 7,
        right: 7,
        height: height - 6,
        child: GestureDetector(
            onTap: () => _openRangeEditor(weekday, range: range),
            onPanStart: (_) => _beginGesture(weekday, range, 'move'),
            onPanUpdate: (details) => _updateGesture(details.delta.dy),
            onPanEnd: (_) => _endGesture(),
            child: Container(
                decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: color.withValues(alpha: .9)),
                    gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [background, color.withValues(alpha: .10)])),
                child: Stack(children: [
                  GestureDetector(
                      onPanStart: (_) => _beginGesture(weekday, range, 'start'),
                      onPanUpdate: (details) =>
                          _updateGesture(details.delta.dy),
                      onPanEnd: (_) => _endGesture(),
                      child: Align(
                          alignment: Alignment.topCenter,
                          child: Container(
                              height: 10, color: Colors.transparent))),
                  Padding(
                      padding: const EdgeInsets.fromLTRB(9, 8, 4, 5),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(
                                  isMorning
                                      ? Icons.wb_sunny_outlined
                                      : Icons.nightlight_outlined,
                                  color: color,
                                  size: 16),
                              const SizedBox(width: 5),
                              Expanded(
                                  child: Text('${range.start} - ${range.end}',
                                      overflow: TextOverflow.ellipsis,
                                      style: _bodyStyle(
                                          PremiumColors.textPrimary, 11,
                                          weight: FontWeight.w700))),
                              SizedBox(
                                  width: 19,
                                  height: 20,
                                  child: PopupMenuButton<String>(
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(Icons.more_horiz,
                                          color: PremiumColors.textPrimary,
                                          size: 17),
                                      color: PremiumColors.surfaceSecondary,
                                      onSelected: (value) {
                                        if (value == 'edit')
                                          _openRangeEditor(weekday,
                                              range: range);
                                        if (value == 'delete')
                                          _deleteRange(weekday, range);
                                      },
                                      itemBuilder: (_) => const [
                                            PopupMenuItem(
                                                value: 'edit',
                                                child: Text('Editar')),
                                            PopupMenuItem(
                                                value: 'delete',
                                                child: Text('Excluir'))
                                          ]))
                            ]),
                            if (height > 50) ...[
                              const SizedBox(height: 4),
                              Text(isMorning ? 'Manhã' : 'Tarde',
                                  style: _bodyStyle(
                                      PremiumColors.textSecondary, 10))
                            ]
                          ])),
                  GestureDetector(
                      onPanStart: (_) => _beginGesture(weekday, range, 'end'),
                      onPanUpdate: (details) =>
                          _updateGesture(details.delta.dy),
                      onPanEnd: (_) => _endGesture(),
                      child: Align(
                          alignment: Alignment.bottomCenter,
                          child:
                              Container(height: 10, color: Colors.transparent)))
                ]))));
  }

  Widget _buildBreakBlock(ScheduleRange range) {
    final start = timeToMinutes(range.start);
    final height = math.max(24.0, durationMinutes(range) / 60 * _hourHeight);
    return Positioned(
        top: (start - dayStartMinutes) / 60 * _hourHeight + 3,
        left: 7,
        right: 7,
        height: height - 6,
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
                color: const Color(0xFF292A2A).withValues(alpha: .9),
                border: Border.all(color: const Color(0xFF777A7C)),
                borderRadius: BorderRadius.circular(7)),
            child: Row(children: [
              const Icon(Icons.coffee_outlined,
                  color: PremiumColors.textSecondary, size: 15),
              const SizedBox(width: 5),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    Text('${range.start} - ${range.end}',
                        style: _bodyStyle(PremiumColors.textPrimary, 10,
                            weight: FontWeight.w700)),
                    if (height > 42)
                      Text('Pausa',
                          style: _bodyStyle(PremiumColors.textSecondary, 9))
                  ]))
            ])));
  }

  Widget _buildSidebar() =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _buildBreakToggle(),
        const SizedBox(height: 14),
        _buildSummaryCard(),
        const SizedBox(height: 14),
        _buildQuickActions(),
        const SizedBox(height: 14),
        _buildTemplates()
      ]);
  Widget _buildBreakToggle() => Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: _panelDecoration(),
      child: Row(children: [
        Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: const Color(0xFF365D6B).withValues(alpha: .28),
                borderRadius: BorderRadius.circular(9)),
            child: const Icon(Icons.water_drop_outlined,
                color: Color(0xFF8FC4D8), size: 21)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Exibir pausas', style: _sectionTitleStyle),
          const SizedBox(height: 3),
          Text('Mostra os intervalos na agenda',
              style: _bodyStyle(PremiumColors.textSecondary, 11))
        ])),
        Switch(
            value: _showBreaks,
            onChanged: (value) => setState(() => _showBreaks = value),
            activeColor: Colors.white,
            activeTrackColor: const Color(0xFF6CA7D0),
            inactiveThumbColor: PremiumColors.textMuted,
            inactiveTrackColor: PremiumColors.surfaceSecondary)
      ]));

  Widget _buildSummaryCard() {
    final activeDays = _schedule.days.where((day) => day.enabled).length;
    final total = calculateWeeklyMinutes(_schedule);
    final average = calculateAverageMinutes(_schedule);
    return _sidebarCard(
        icon: Icons.bar_chart_outlined,
        title: 'Resumo da semana',
        subtitle: 'Visão geral dos seus horários de atendimento.',
        child: Column(children: [
          _statRow(
              Icons.calendar_month_outlined, 'Dias ativos', '$activeDays de 7'),
          _divider(),
          _statRow(Icons.schedule_outlined, 'Total de horas semanais',
              formatMinutes(total)),
          _divider(),
          _statRow(Icons.people_outline, 'Média por dia útil',
              formatMinutes(average))
        ]));
  }

  Widget _statRow(IconData icon, String label, String value) => Row(children: [
        Icon(icon, color: const Color(0xFF73B2D8), size: 19),
        const SizedBox(width: 12),
        Expanded(
            child: Text(label,
                style: _bodyStyle(PremiumColors.textSecondary, 12))),
        Text(value,
            style: _bodyStyle(PremiumColors.textPrimary, 14,
                weight: FontWeight.w700))
      ]);
  Widget _divider() => Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Divider(
          color: PremiumColors.border.withValues(alpha: .8), height: 1));
  Widget _buildQuickActions() => _sidebarCard(
      icon: Icons.bolt_outlined,
      title: 'Ações rápidas',
      subtitle: 'Aplique horários em múltiplos dias rapidamente.',
      child: Column(children: [
        _quickAction(
            Icons.content_copy_outlined,
            'Aplicar a todos os dias úteis',
            'Replica os horários de segunda a sexta',
            () => _openCopyDialog(weekdaysOnly: true)),
        const SizedBox(height: 10),
        _quickAction(Icons.calendar_month_outlined, 'Copiar de um dia',
            'Escolha um dia e aplique em outros', () => _openCopyDialog()),
        const SizedBox(height: 10),
        _quickAction(Icons.event_busy_outlined, 'Inativar dia',
            'Selecione um dia sem atendimento', _openDisableDayDialog),
        const SizedBox(height: 10),
        _quickAction(Icons.block_outlined, 'Bloquear horário',
            'Reserve um período sem novos agendamentos', _openBlockDialog)
      ]));

  Future<void> _openBlockDialog() async {
    final colaboradorId = _colaboradorId;
    if (colaboradorId == null) {
      AppToast.show(
          context, 'Selecione um profissional antes de bloquear um horário.',
          type: AppToastType.info);
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 520,
            maxHeight: MediaQuery.of(context).size.height * .9,
          ),
          child: BloquearHorarioScreen(
            embedded: true,
            colaboradorId: colaboradorId,
          ),
        ),
      ),
    );
  }

  Widget _quickAction(
      IconData icon, String title, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: PremiumColors.surfaceSecondary.withValues(alpha: .6),
          border: Border.all(color: const Color(0xFF37576C)),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF76AFD2), size: 21),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: _bodyStyle(PremiumColors.textPrimary, 12,
                          weight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: _bodyStyle(PremiumColors.textSecondary, 10)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF77A9C7), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplates() => Container(
      key: _templatesKey,
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: const Color(0xFF35566A).withValues(alpha: .28),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.business_center_outlined,
                  color: Color(0xFF75AFD1), size: 18)),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Modelos de agenda', style: _sectionTitleStyle),
                const SizedBox(height: 3),
                Text('Aplique um modelo padrão para configurar os horários.',
                    style: _bodyStyle(PremiumColors.textSecondary, 10))
              ]))
        ]),
        const SizedBox(height: 12),
        ..._templates.map(_templateCard)
      ]));
  Widget _templateCard(ScheduleTemplate template) {
    final selected = _selectedTemplateId == template.id;
    return InkWell(
        onTap: () => setState(() => _selectedTemplateId = template.id),
        borderRadius: BorderRadius.circular(9),
        child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF1B2932)
                    : PremiumColors.surfaceSecondary.withValues(alpha: .5),
                border: Border.all(
                    color: selected
                        ? const Color(0xFF4A8CB4)
                        : PremiumColors.border,
                    width: selected ? 1.2 : 1),
                borderRadius: BorderRadius.circular(9)),
            child: Row(children: [
              Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: const Color(0xFF375C70).withValues(alpha: .26),
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(
                      template.id == 'commercial'
                          ? Icons.business_center_outlined
                          : template.id == 'extended'
                              ? Icons.wb_sunny_outlined
                              : Icons.schedule_outlined,
                      color: const Color(0xFF7BB2D2),
                      size: 19)),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(template.name,
                        style: _bodyStyle(PremiumColors.textPrimary, 12,
                            weight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(template.description,
                        maxLines: 2,
                        style: _bodyStyle(PremiumColors.textSecondary, 10,
                            height: 1.3))
                  ])),
              Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected
                      ? const Color(0xFF72B1D9)
                      : PremiumColors.textMuted,
                  size: 19)
            ])));
  }

  Widget _sidebarCard(
          {required IconData icon,
          required String title,
          required String subtitle,
          required Widget child}) =>
      Container(
          padding: const EdgeInsets.all(16),
          decoration: _panelDecoration(),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, color: PremiumColors.gold, size: 23),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title, style: _sectionTitleStyle),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: _bodyStyle(PremiumColors.textSecondary, 10))
                  ]))
            ]),
            const SizedBox(height: 16),
            child
          ]));
  Widget _buildErrorState() => Container(
      padding: const EdgeInsets.all(20),
      decoration: _panelDecoration(),
      child: Row(children: [
        const Icon(Icons.error_outline, color: PremiumColors.error, size: 24),
        const SizedBox(width: 12),
        Expanded(
            child: Text(_error ?? 'Não foi possível carregar os horários.',
                style: _bodyStyle(PremiumColors.textPrimary, 13))),
        OutlinedButton(
            onPressed: _colaboradorId == null
                ? null
                : () => _carregarHorarios(_colaboradorId!),
            child: const Text('Tentar novamente'))
      ]));

  BoxDecoration _panelDecoration({Color? color}) => BoxDecoration(
      color: color ?? PremiumColors.surface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: PremiumColors.border));
  TextStyle get _eyebrowStyle => GoogleFonts.inter(
      color: PremiumColors.textMuted,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.1);
  TextStyle _headingStyle(bool compact) => GoogleFonts.inter(
      color: PremiumColors.textPrimary,
      fontSize: compact ? 28 : 32,
      fontWeight: FontWeight.w700,
      height: 1.1);
  TextStyle get _subtitleStyle =>
      GoogleFonts.inter(color: PremiumColors.textSecondary, fontSize: 14);
  TextStyle get _sectionTitleStyle => GoogleFonts.inter(
      color: PremiumColors.textPrimary,
      fontSize: 16,
      fontWeight: FontWeight.w700);
  TextStyle _bodyStyle(Color color, double size,
          {FontWeight weight = FontWeight.w400, double height = 1.2}) =>
      GoogleFonts.inter(
          color: color, fontSize: size, fontWeight: weight, height: height);
}

class _RangeDialogResult {
  final String? start;
  final String? end;
  final bool deleted;

  const _RangeDialogResult({this.start, this.end, this.deleted = false});
}

class _RangeDialog extends StatefulWidget {
  final ScheduleRange? range;
  const _RangeDialog({this.range});

  @override
  State<_RangeDialog> createState() => _RangeDialogState();
}

class _RangeDialogState extends State<_RangeDialog> {
  late String _start = widget.range?.start ?? '08:00';
  late String _end = widget.range?.end ?? '12:00';
  String? _error;

  List<String> get _options => [
        for (var minutes = dayStartMinutes;
            minutes <= dayEndMinutes;
            minutes += snapMinutes)
          minutesToTime(minutes)
      ];

  @override
  Widget build(BuildContext context) => AlertDialog(
          backgroundColor: PremiumColors.surfaceSecondary,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          title: Text(
              widget.range == null ? 'Adicionar horário' : 'Editar horário',
              style: GoogleFonts.inter(
                  color: PremiumColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 18)),
          content: SizedBox(
              width: 390,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Expanded(
                      child: _timeField('Início', _start,
                          (value) => setState(() => _start = value!))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _timeField('Fim', _end,
                          (value) => setState(() => _end = value!)))
                ]),
                if (_error != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(_error!,
                              style: const TextStyle(
                                  color: PremiumColors.error, fontSize: 12))))
              ])),
          actions: [
            if (widget.range != null)
              TextButton(
                  onPressed: () => Navigator.pop(
                      context, const _RangeDialogResult(deleted: true)),
                  child: const Text('Excluir',
                      style: TextStyle(color: PremiumColors.error))),
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () {
                  final range =
                      ScheduleRange(id: 'dialog', start: _start, end: _end);
                  if (!validateRange(range)) {
                    setState(() => _error =
                        'O horário final deve ser posterior ao inicial.');
                    return;
                  }
                  Navigator.pop(
                      context, _RangeDialogResult(start: _start, end: _end));
                },
                child: const Text('Salvar'))
          ]);

  Widget _timeField(
          String label, String value, ValueChanged<String?> onChanged) =>
      DropdownButtonFormField<String>(
          value: value,
          dropdownColor: PremiumColors.surfaceSecondary,
          style: const TextStyle(color: PremiumColors.textPrimary),
          decoration: InputDecoration(
              labelText: label,
              labelStyle: const TextStyle(color: PremiumColors.textSecondary),
              filled: true,
              fillColor: PremiumColors.surface,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: PremiumColors.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: PremiumColors.border))),
          items: _options
              .map((option) =>
                  DropdownMenuItem(value: option, child: Text(option)))
              .toList(),
          onChanged: onChanged);
}

class _CopyDialogResult {
  final int source;
  final Set<int> targets;
  const _CopyDialogResult({required this.source, required this.targets});
}

class _CopyDialog extends StatefulWidget {
  final bool weekdaysOnly;
  const _CopyDialog({required this.weekdaysOnly});

  @override
  State<_CopyDialog> createState() => _CopyDialogState();
}

class _CopyDialogState extends State<_CopyDialog> {
  int _source = 1;
  Set<int> _targets = {2, 3, 4, 5};
  static const labels = {
    0: 'Domingo',
    1: 'Segunda',
    2: 'Terça',
    3: 'Quarta',
    4: 'Quinta',
    5: 'Sexta',
    6: 'Sábado'
  };

  @override
  Widget build(BuildContext context) {
    final availableTargets = [1, 2, 3, 4, 5, 6, 0]
        .where((day) =>
            day != _source && (!widget.weekdaysOnly || day >= 1 && day <= 5))
        .toList();
    return AlertDialog(
      backgroundColor: PremiumColors.surfaceSecondary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      title: Text(
          widget.weekdaysOnly ? 'Aplicar aos dias úteis' : 'Copiar de um dia',
          style: GoogleFonts.inter(
              color: PremiumColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 18)),
      content: SizedBox(
        width: 390,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dia de origem',
                style: TextStyle(
                    color: PremiumColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 5),
            DropdownButtonFormField<int>(
              value: _source,
              dropdownColor: PremiumColors.surfaceSecondary,
              style: const TextStyle(color: PremiumColors.textPrimary),
              decoration: _inputDecoration(),
              items: labels.entries
                  .where((entry) =>
                      !widget.weekdaysOnly || entry.key >= 1 && entry.key <= 5)
                  .map((entry) => DropdownMenuItem(
                      value: entry.key, child: Text(entry.value)))
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _source = value;
                  _targets.remove(value);
                  if (widget.weekdaysOnly)
                    _targets = {
                      ...availableTargets.where((day) => day != value)
                    };
                });
              },
            ),
            const SizedBox(height: 16),
            const Text('Aplicar em',
                style: TextStyle(
                    color: PremiumColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            ...availableTargets.map((day) => CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: _targets.contains(day),
                  activeColor: PremiumColors.gold,
                  checkColor: Colors.black,
                  title: Text(labels[day]!,
                      style: const TextStyle(
                          color: PremiumColors.textPrimary, fontSize: 13)),
                  onChanged: (selected) => setState(() {
                    if (selected == true) {
                      _targets.add(day);
                    } else {
                      _targets.remove(day);
                    }
                  }),
                )),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(
            onPressed: _targets.isEmpty
                ? null
                : () => Navigator.pop(context,
                    _CopyDialogResult(source: _source, targets: _targets)),
            child: const Text('Aplicar')),
      ],
    );
  }

  InputDecoration _inputDecoration() => InputDecoration(
      filled: true,
      fillColor: PremiumColors.surface,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: PremiumColors.border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: PremiumColors.border)));
}

class _ConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  const _ConfirmationDialog(
      {required this.title, required this.message, required this.confirmLabel});

  @override
  Widget build(BuildContext context) => AlertDialog(
          backgroundColor: PremiumColors.surfaceSecondary,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          title: Text(title,
              style: GoogleFonts.inter(
                  color: PremiumColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 18)),
          content: Text(message,
              style: GoogleFonts.inter(
                  color: PremiumColors.textSecondary,
                  fontSize: 13,
                  height: 1.45)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(confirmLabel))
          ]);
}

class _DaySelectionDialog extends StatefulWidget {
  final String title;
  final String description;
  final List<DaySchedule> days;
  final Map<int, String> labels;
  final String confirmLabel;

  const _DaySelectionDialog({
    required this.title,
    required this.description,
    required this.days,
    required this.labels,
    required this.confirmLabel,
  });

  @override
  State<_DaySelectionDialog> createState() => _DaySelectionDialogState();
}

class _DaySelectionDialogState extends State<_DaySelectionDialog> {
  late int _selectedDay = widget.days.first.weekday;

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: PremiumColors.surfaceSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Text(
          widget.title,
          style: GoogleFonts.inter(
              color: PremiumColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 18),
        ),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.description,
                style: GoogleFonts.inter(
                    color: PremiumColors.textSecondary,
                    fontSize: 13,
                    height: 1.45),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _selectedDay,
                dropdownColor: PremiumColors.surfaceSecondary,
                style: const TextStyle(color: PremiumColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Dia',
                  labelStyle:
                      const TextStyle(color: PremiumColors.textSecondary),
                  filled: true,
                  fillColor: PremiumColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: PremiumColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: PremiumColors.border),
                  ),
                ),
                items: widget.days
                    .map((day) => DropdownMenuItem<int>(
                          value: day.weekday,
                          child: Text(widget.labels[day.weekday]!),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedDay = value);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, _selectedDay),
              child: Text(widget.confirmLabel)),
        ],
      );
}
