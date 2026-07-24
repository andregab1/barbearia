// ==========================================
// TELA: Configurar Horários de Funcionamento
// RF03 - Selecionar barbeiro e definir horários
// ==========================================
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/api_service.dart';

class HorariosScreen extends StatefulWidget {
  const HorariosScreen({super.key});

  @override
  State<HorariosScreen> createState() => _HorariosScreenState();
}

class _HorariosScreenState extends State<HorariosScreen> {
  final List<String> _dias = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];

  List<Map<String, dynamic>> _colaboradores      = [];
  Map<String, dynamic>?      _colaboradorSel;
  int?                       _colaboradorId;

  final Map<int, bool>   _ativo      = {};
  final Map<int, String> _horaInicio = {};
  final Map<int, String> _horaFim    = {};

  bool   _carregando         = true;
  bool   _carregandoHorarios = false;
  bool   _salvando           = false;
  bool   _selecionandoBarbeiro = true;
  String _role               = '';

  @override
  void initState() {
    super.initState();
    for (int i = 0; i <= 6; i++) {
      _ativo[i]      = i != 0;
      _horaInicio[i] = '09:00';
      _horaFim[i]    = '18:00';
    }
    _inicializar();
  }

  Future<void> _inicializar() async {
    final prefs     = await SharedPreferences.getInstance();
    _role           = prefs.getString(AppConstants.keyUsuarioRole) ?? '';
    final usuarioId = prefs.getInt(AppConstants.keyUsuarioId) ?? 0;

    if (_role == AppConstants.roleAdmin) {
      await _carregarColaboradores();
    } else {
      // Barbeiro: busca seu próprio colaborador_id
      final colab = await ApiService.get('/colaboradores/usuario/$usuarioId');
      if (!colab.containsKey('erro') && colab['id'] != null) {
        _colaboradorId = colab['id'];
        // Barbeiro vai direto para a tela de horários
        setState(() => _selecionandoBarbeiro = false);
        await _carregarHorarios(_colaboradorId!);
      }
    }

    setState(() => _carregando = false);
  }

  Future<void> _carregarColaboradores() async {
    final result = await ApiService.get('/colaboradores/1');
    if (!result.containsKey('erro')) {
      List<Map<String, dynamic>> lista = [];
      if (result['data'] != null) {
        lista = (result['data'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
      } else if (result is List) {
        lista = (result as List).map((e) => Map<String, dynamic>.from(e)).toList();
      }
      setState(() => _colaboradores = lista);
    }
  }

  Future<void> _selecionarBarbeiro(Map<String, dynamic> colab) async {
    setState(() {
      _colaboradorSel      = colab;
      _colaboradorId       = colab['id'];
      _selecionandoBarbeiro = false;
      _carregandoHorarios  = true;
    });
    await _carregarHorarios(colab['id']);
    setState(() => _carregandoHorarios = false);
  }

  Future<void> _carregarHorarios(int colaboradorId) async {
    final result = await ApiService.get('/horarios/$colaboradorId');
    if (!result.containsKey('erro')) {
      for (int i = 0; i <= 6; i++) {
        final dia = result[i.toString()];
        if (dia != null) {
          setState(() {
            _ativo[i]      = dia['ativo'] == true;
            _horaInicio[i] = dia['hora_inicio'] ?? '09:00';
            _horaFim[i]    = dia['hora_fim']    ?? '18:00';
          });
        }
      }
    }
  }

  Future<void> _selecionarHora(int dia, bool isInicio) async {
    final atual  = isInicio ? _horaInicio[dia]! : _horaFim[dia]!;
    final partes = atual.split(':');
    final cor    = Theme.of(context).colorScheme.primary;

    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour:   int.parse(partes[0]),
        minute: int.parse(partes[1]),
      ),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: cor, surface: AppTheme.corFundoSecundario),
        ),
        child: child!,
      ),
    );

    if (hora != null) {
      final f = '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';
      setState(() => isInicio ? _horaInicio[dia] = f : _horaFim[dia] = f);
    }
  }

  Future<void> _salvar() async {
    if (_colaboradorId == null) return;
    setState(() => _salvando = true);

    final horarios = <String, dynamic>{};
    for (int i = 0; i <= 6; i++) {
      horarios[i.toString()] = {
        'ativo':       _ativo[i],
        'hora_inicio': _horaInicio[i],
        'hora_fim':    _horaFim[i],
      };
    }

    final result = await ApiService.post(
      '/horarios/$_colaboradorId', {'horarios': horarios});
    setState(() => _salvando = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result.containsKey('erro') ? result['erro'] : 'Horários salvos!'),
      backgroundColor: result.containsKey('erro') ? AppTheme.corErro : AppTheme.corSucesso,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.primary;

    if (_carregando) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(title: Text('Horários de Atendimento')),
        body: Center(child: CircularProgressIndicator(color: cor)),
      );
    }

    // ==========================================
    // Tela de seleção de barbeiro (admin)
    // ==========================================
    if (_selecionandoBarbeiro && _role == AppConstants.roleAdmin) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(title: Text('Horários de Atendimento')),
        body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Selecione o profissional',
                  style: TextStyle(color: cor, fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('Escolha para quem deseja configurar os horários',
                  style: TextStyle(color: AppTheme.corTextoSecundario, fontSize: 13)),
            ]),
          ),
          SizedBox(height: 8),
          Expanded(
            child: _colaboradores.isEmpty
                ? Center(child: Text('Nenhum barbeiro cadastrado.',
                    style: TextStyle(color: AppTheme.corTextoSecundario)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _colaboradores.length,
                    itemBuilder: (context, i) {
                      final c = _colaboradores[i];
                      return GestureDetector(
                        onTap: () => _selecionarBarbeiro(c),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: AppTheme.corCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: cor.withOpacity(0.2)),
                          ),
                          child: Row(children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: cor.withOpacity(0.2),
                              child: Text(
                                c['nome'][0].toUpperCase(),
                                style: TextStyle(
                                  color: cor,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c['nome'],
                                    style: TextStyle(
                                      color: AppTheme.corTexto,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    )),
                                if (c['telefone'] != null && c['telefone'] != '')
                                  Text(c['telefone'],
                                      style: TextStyle(
                                        color: AppTheme.corTextoSecundario,
                                        fontSize: 13,
                                      )),
                              ],
                            )),
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

    // ==========================================
    // Tela de configuração de horários
    // ==========================================
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_colaboradorSel != null
            ? 'Horários — ${_colaboradorSel!['nome'].toString().split(' ').first}'
            : 'Meus Horários'),
        leading: _role == AppConstants.roleAdmin
            ? IconButton(
                icon: Icon(Icons.arrow_back_ios),
                onPressed: () => setState(() {
                  _selecionandoBarbeiro = true;
                  _colaboradorSel       = null;
                  _colaboradorId        = null;
                }),
              )
            : null,
      ),
      body: _carregandoHorarios
          ? Center(child: CircularProgressIndicator(color: cor))
          : Column(children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: 7,
                  itemBuilder: (context, i) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.corCard,
                        borderRadius: BorderRadius.circular(14),
                        border: _ativo[i] == true
                            ? Border.all(color: cor.withOpacity(0.4))
                            : null,
                      ),
                      child: Column(children: [
                        ListTile(
                          title: Text(_dias[i], style: TextStyle(
                            color: _ativo[i] == true
                                ? AppTheme.corTexto
                                : AppTheme.corTextoSecundario,
                            fontWeight: FontWeight.w600,
                          )),
                          trailing: Switch(
                            value: _ativo[i] ?? false,
                            activeColor: cor,
                            onChanged: (v) => setState(() => _ativo[i] = v),
                          ),
                        ),

                        if (_ativo[i] == true) ...[
                          Divider(color: AppTheme.corCard, height: 1),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            child: Row(children: [
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Início', style: TextStyle(
                                      color: AppTheme.corTextoSecundario, fontSize: 12)),
                                  const SizedBox(height: 6),
                                  GestureDetector(
                                    onTap: () => _selecionarHora(i, true),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: AppTheme.corCard,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: cor.withOpacity(0.3)),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.access_time, color: cor, size: 16),
                                          const SizedBox(width: 6),
                                          Text(_horaInicio[i]!, style: TextStyle(
                                              color: cor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              )),

                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text('até', style: TextStyle(
                                    color: cor, fontWeight: FontWeight.w500)),
                              ),

                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Fim', style: TextStyle(
                                      color: AppTheme.corTextoSecundario, fontSize: 12)),
                                  const SizedBox(height: 6),
                                  GestureDetector(
                                    onTap: () => _selecionarHora(i, false),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: AppTheme.corCard,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: cor.withOpacity(0.3)),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.access_time, color: cor, size: 16),
                                          const SizedBox(width: 6),
                                          Text(_horaFim[i]!, style: TextStyle(
                                              color: cor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              )),
                            ]),
                          ),

                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: _PreviewHorarios(
                              inicio: _horaInicio[i]!,
                              fim:    _horaFim[i]!,
                              cor:    cor,
                            ),
                          ),
                        ],
                      ]),
                    );
                  },
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: _salvando ? null : _salvar,
                  child: _salvando
                      ? SizedBox(height: 20, width: 20,
                          child: CircularProgressIndicator(
                              color: AppTheme.corFundo, strokeWidth: 2))
                      : Text('Salvar Horários'),
                ),
              ),
            ]),
    );
  }
}

// ==========================================
// WIDGET: Preview dos slots gerados
// ==========================================
class _PreviewHorarios extends StatelessWidget {
  final String inicio;
  final String fim;
  final Color  cor;

  const _PreviewHorarios({
    required this.inicio,
    required this.fim,
    required this.cor,
  });

  List<String> _gerarSlots() {
    final slots  = <String>[];
    final parIni = inicio.split(':');
    final parFim = fim.split(':');
    var   hAtual = int.parse(parIni[0]);
    var   mAtual = int.parse(parIni[1]);
    final hFim   = int.parse(parFim[0]);
    final mFim   = int.parse(parFim[1]);

    while (hAtual < hFim || (hAtual == hFim && mAtual < mFim)) {
      slots.add('${hAtual.toString().padLeft(2, '0')}:${mAtual.toString().padLeft(2, '0')}');
      mAtual += 60;
      if (mAtual >= 60) { hAtual++; mAtual -= 60; }
    }
    return slots;
  }

  @override
  Widget build(BuildContext context) {
    final slots = _gerarSlots();
    if (slots.isEmpty) return SizedBox();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${slots.length} horários disponíveis:',
          style: TextStyle(
              color: AppTheme.corTextoSecundario, fontSize: 11)),
      const SizedBox(height: 6),
      Wrap(
        spacing: 6, runSpacing: 6,
        children: slots.map((s) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: cor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: cor.withOpacity(0.3)),
          ),
          child: Text(s, style: TextStyle(
              color: cor, fontSize: 11, fontWeight: FontWeight.w600)),
        )).toList(),
      ),
    ]);
  }
}