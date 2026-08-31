import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/premium_ui.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/api_service.dart';
import '../../../shared/widgets/app_toast.dart';

class HorariosScreen extends StatefulWidget {
  const HorariosScreen({super.key});

  @override
  State<HorariosScreen> createState() => _HorariosScreenState();
}

class _HorariosScreenState extends State<HorariosScreen> {
  final List<String> _dias = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];

  List<Map<String, dynamic>> _colaboradores = [];
  Map<String, dynamic>? _colaboradorSel;
  int? _colaboradorId;

  final Map<int, bool> _ativo = {};
  final Map<int, String> _horaInicio = {};
  final Map<int, String> _horaFim = {};

  bool _carregando = true;
  bool _carregandoHorarios = false;
  bool _salvando = false;
  bool _selecionandoBarbeiro = true;
  String _role = '';
  int _horariosRequestId = 0;

  @override
  void dispose() {
    _horariosRequestId++;
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    for (int i = 0; i <= 6; i++) {
      _ativo[i] = i != 0;
      _horaInicio[i] = '09:00';
      _horaFim[i] = '18:00';
    }
    _inicializar();
  }

  Future<void> _inicializar() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    _role = prefs.getString(AppConstants.keyUsuarioRole) ?? '';
    final usuarioId = prefs.getInt(AppConstants.keyUsuarioId) ?? 0;

    if (_role == AppConstants.roleAdmin) {
      await _carregarColaboradores();
    } else {
      final colab = await ApiService.get('/colaboradores/usuario/$usuarioId');
      if (!mounted) return;
      if (!colab.containsKey('erro') && colab['id'] != null) {
        _colaboradorId = colab['id'];
        setState(() => _selecionandoBarbeiro = false);
        await _carregarHorarios(_colaboradorId!);
      }
    }

    if (!mounted) return;
    setState(() => _carregando = false);
  }

  Future<void> _carregarColaboradores() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final barbeariaId = prefs.getInt(AppConstants.keyBarbeariaId) ?? 1;
    final result = await ApiService.get('/colaboradores/$barbeariaId');
    if (!mounted) return;
    if (!result.containsKey('erro')) {
      List<Map<String, dynamic>> lista = [];
      if (result['data'] != null) {
        lista = (result['data'] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else if (result is List) {
        lista =
            (result as List).map((e) => Map<String, dynamic>.from(e)).toList();
      }
      setState(() => _colaboradores = lista);
    }
  }

  Future<void> _selecionarBarbeiro(Map<String, dynamic> colab) async {
    setState(() {
      _colaboradorSel = colab;
      _colaboradorId = colab['id'];
      _selecionandoBarbeiro = false;
      _carregandoHorarios = true;
    });
    await _carregarHorarios(colab['id']);
    if (!mounted || _colaboradorId != colab['id']) return;
    setState(() => _carregandoHorarios = false);
  }

  Future<void> _carregarHorarios(int colaboradorId) async {
    final requestId = ++_horariosRequestId;
    final result = await ApiService.get('/horarios/$colaboradorId');
    if (!mounted || requestId != _horariosRequestId) return;
    if (!result.containsKey('erro')) {
      final novosAtivos = <int, bool>{};
      final novosInicios = <int, String>{};
      final novosFins = <int, String>{};
      for (int i = 0; i <= 6; i++) {
        final dia = result[i.toString()];
        if (dia != null) {
          novosAtivos[i] = dia['ativo'] == true;
          novosInicios[i] = dia['hora_inicio'] ?? '09:00';
          novosFins[i] = dia['hora_fim'] ?? '18:00';
        }
      }
      setState(() {
        _ativo.addAll(novosAtivos);
        _horaInicio.addAll(novosInicios);
        _horaFim.addAll(novosFins);
      });
    }
  }

  Future<void> _selecionarHora(int dia, bool isInicio) async {
    final atual = isInicio ? _horaInicio[dia]! : _horaFim[dia]!;
    final partes = atual.split(':');
    final cor = Theme.of(context).colorScheme.primary;

    final hora = await showTimePicker(
      context: context,
      initialTime:
          TimeOfDay(hour: int.parse(partes[0]), minute: int.parse(partes[1])),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme:
              ColorScheme.dark(primary: cor, surface: AppTheme.surfaceElev),
        ),
        child: child!,
      ),
    );

    if (!mounted) return;
    if (hora != null) {
      final f =
          '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';
      setState(() => isInicio ? _horaInicio[dia] = f : _horaFim[dia] = f);
    }
  }

  Future<void> _salvar() async {
    if (_colaboradorId == null) return;
    setState(() => _salvando = true);

    final horarios = <String, dynamic>{};
    for (int i = 0; i <= 6; i++) {
      horarios[i.toString()] = {
        'ativo': _ativo[i],
        'hora_inicio': _horaInicio[i],
        'hora_fim': _horaFim[i],
      };
    }

    final result = await ApiService.post(
        '/horarios/$_colaboradorId', {'horarios': horarios});
    if (!mounted) return;
    setState(() => _salvando = false);

    final erro = result.containsKey('erro');
    AppToast.show(context, erro ? result['erro'] : 'Horários salvos!',
        type: erro ? AppToastType.error : AppToastType.success);
  }

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.primary;

    if (_carregando) {
      return const PremiumPage(
        title: 'Horários de atendimento',
        subtitle: 'Configure sua disponibilidade semanal.',
        child: PremiumLoadingState(label: 'Carregando horários'),
      );
    }

    if (_selecionandoBarbeiro && _role == AppConstants.roleAdmin) {
      return PremiumPage(
        title: 'Horários de atendimento',
        subtitle: 'Selecione o profissional que deseja configurar.',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Selecione o profissional',
                  style: GoogleFonts.playfairDisplay(
                      color: cor,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.4)),
              const SizedBox(height: 4),
              Text('Escolha para quem deseja configurar os horários',
                  style: GoogleFonts.inter(
                      color: AppTheme.corTextoSecundario, fontSize: 13)),
            ]),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _colaboradores.isEmpty
                ? Center(
                    child: Text('Nenhum barbeiro cadastrado.',
                        style: GoogleFonts.inter(
                            color: AppTheme.corTextoSecundario)))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: _colaboradores.length,
                    itemBuilder: (context, i) {
                      final c = _colaboradores[i];
                      return GestureDetector(
                        onTap: () => _selecionarBarbeiro(c),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceElev,
                            borderRadius: BorderRadius.circular(14),
                            border:
                                Border.all(color: cor.withValues(alpha: 0.15)),
                          ),
                          child: Row(children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: cor.withValues(alpha: 0.2),
                              child: Text(
                                c['nome'][0].toUpperCase(),
                                style: GoogleFonts.playfairDisplay(
                                    color: cor,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(c['nome'],
                                      style: GoogleFonts.inter(
                                          color: AppTheme.corTexto,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16)),
                                  if (c['telefone'] != null &&
                                      c['telefone'] != '')
                                    Text(c['telefone'],
                                        style: GoogleFonts.inter(
                                            color: AppTheme.corTextoSecundario,
                                            fontSize: 13)),
                                ])),
                            Icon(Icons.schedule, color: cor),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_forward_ios, color: cor, size: 16),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
        ]),
      );
    }

    return PremiumPage(
      title: _colaboradorSel != null
          ? 'Horários — ${_colaboradorSel!['nome'].toString().split(' ').first}'
          : 'Meus horários',
      subtitle: 'Defina os dias e períodos disponíveis para atendimento.',
      actions: _role == AppConstants.roleAdmin
          ? [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios),
                tooltip: 'Escolher outro profissional',
                onPressed: () => setState(() {
                  _horariosRequestId++;
                  _selecionandoBarbeiro = true;
                  _colaboradorSel = null;
                  _colaboradorId = null;
                }),
              )
            ]
          : const [],
      child: _carregandoHorarios
          ? Center(child: CircularProgressIndicator(color: cor))
          : Column(children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: 7,
                  itemBuilder: (context, i) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceElev,
                        borderRadius: BorderRadius.circular(14),
                        border: _ativo[i] == true
                            ? Border.all(color: cor.withValues(alpha: 0.4))
                            : null,
                      ),
                      child: Column(children: [
                        SwitchListTile(
                          title: Text(_dias[i],
                              style: GoogleFonts.inter(
                                color: _ativo[i] == true
                                    ? AppTheme.corTexto
                                    : AppTheme.corTextoSecundario,
                                fontWeight: FontWeight.w600,
                              )),
                          value: _ativo[i] ?? false,
                          activeThumbColor: cor,
                          onChanged: (v) => setState(() => _ativo[i] = v),
                        ),
                        if (_ativo[i] == true) ...[
                          Divider(
                              color: AppTheme.border.withValues(alpha: 0.3),
                              height: 1),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            child: Row(children: [
                              Expanded(
                                  child: _timeBox('Início', _horaInicio[i]!,
                                      cor, () => _selecionarHora(i, true))),
                              Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  child: Text('até',
                                      style: GoogleFonts.inter(
                                          color: cor,
                                          fontWeight: FontWeight.w500))),
                              Expanded(
                                  child: _timeBox('Fim', _horaFim[i]!, cor,
                                      () => _selecionarHora(i, false))),
                            ]),
                          ),
                          Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: _PreviewHorarios(
                                  inicio: _horaInicio[i]!,
                                  fim: _horaFim[i]!,
                                  cor: cor)),
                        ],
                      ]),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ElevatedButton(
                    onPressed: _salvando ? null : _salvar,
                    child: _salvando
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                color: AppTheme.blackPure, strokeWidth: 2))
                        : const Text('Salvar Horários'),
                  ),
                ),
              ),
            ]),
    );
  }

  Widget _timeBox(String label, String hora, Color cor, VoidCallback onTap) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: GoogleFonts.inter(
              color: AppTheme.corTextoSecundario, fontSize: 12)),
      const SizedBox(height: 6),
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceElev,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cor.withValues(alpha: 0.3)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.access_time, color: cor, size: 16),
            const SizedBox(width: 6),
            Text(hora,
                style: GoogleFonts.inter(
                    color: cor, fontWeight: FontWeight.w700, fontSize: 16)),
          ]),
        ),
      ),
    ]);
  }
}

class _PreviewHorarios extends StatelessWidget {
  final String inicio;
  final String fim;
  final Color cor;
  const _PreviewHorarios(
      {required this.inicio, required this.fim, required this.cor});

  List<String> _gerarSlots() {
    final slots = <String>[];
    final parIni = inicio.split(':');
    final parFim = fim.split(':');
    var hAtual = int.parse(parIni[0]);
    var mAtual = int.parse(parIni[1]);
    final hFim = int.parse(parFim[0]);
    final mFim = int.parse(parFim[1]);

    while (hAtual < hFim || (hAtual == hFim && mAtual < mFim)) {
      slots.add(
          '${hAtual.toString().padLeft(2, '0')}:${mAtual.toString().padLeft(2, '0')}');
      mAtual += 60;
      if (mAtual >= 60) {
        hAtual++;
        mAtual -= 60;
      }
    }
    return slots;
  }

  @override
  Widget build(BuildContext context) {
    final slots = _gerarSlots();
    if (slots.isEmpty) return const SizedBox();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${slots.length} horários disponíveis:',
          style: GoogleFonts.inter(
              color: AppTheme.corTextoSecundario, fontSize: 11)),
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: slots
            .map((s) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: cor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: cor.withValues(alpha: 0.3)),
                  ),
                  child: Text(s,
                      style: GoogleFonts.inter(
                          color: cor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ))
            .toList(),
      ),
    ]);
  }
}
