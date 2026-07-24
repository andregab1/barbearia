// ==========================================
// TELA: Agendar Serviço
// RF06 - Agendamento com múltiplos serviços
// ==========================================
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/agendamento_controller.dart';

class AgendarScreen extends StatefulWidget {
  final Map<String, dynamic>? servico;
  final Map<String, dynamic>? colaborador;

  const AgendarScreen({super.key, this.servico, this.colaborador});

  @override
  State<AgendarScreen> createState() => _AgendarScreenState();
}

class _AgendarScreenState extends State<AgendarScreen> {
  List<Map<String, dynamic>> _servicosSel   = [];
  Map<String, dynamic>?      _colaboradorSel;
  DateTime?                  _dataSel;
  String?                    _horaSel;

  int    get _duracaoTotal => _servicosSel.fold(0,
      (acc, s) => acc + (s['duracao_min'] as int));
  double get _valorTotal   => _servicosSel.fold(0.0,
      (acc, s) => acc + double.parse(s['preco'].toString()));

  @override
  void initState() {
    super.initState();
    if (widget.servico    != null) _servicosSel    = [widget.servico!];
    if (widget.colaborador != null) _colaboradorSel = widget.colaborador;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctrl = context.read<AgendamentoController>();
      if (ctrl.servicos.isEmpty)      ctrl.carregarServicos();
      if (ctrl.colaboradores.isEmpty) ctrl.carregarColaboradores();
    });
  }

  Future<void> _selecionarData() async {
    if (_colaboradorSel == null || _servicosSel.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Selecione o profissional e ao menos um serviço.'),
        backgroundColor: AppTheme.corErro,
      ));
      return;
    }

    final cor  = Theme.of(context).colorScheme.primary;
    final data = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      builder: (_, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(primary: cor, surface: AppTheme.corFundoSecundario),
        ),
        child: child!,
      ),
    );

    if (data != null) {
      setState(() { _dataSel = data; _horaSel = null; });
      await context.read<AgendamentoController>().carregarHorarios(
        _colaboradorSel!['id'],
        DateFormat('yyyy-MM-dd').format(data),
        duracaoTotal: _duracaoTotal,
      );
    }
  }

  void _toggleServico(Map<String, dynamic> servico) {
    setState(() {
      final idx = _servicosSel.indexWhere((s) => s['id'] == servico['id']);
      if (idx >= 0) {
        _servicosSel.removeAt(idx);
      } else {
        _servicosSel.add(servico);
      }
      _dataSel  = null;
      _horaSel  = null;
    });
  }

  Future<void> _confirmar() async {
    if (_servicosSel.isEmpty || _colaboradorSel == null || _dataSel == null || _horaSel == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Preencha todos os campos.'),
        backgroundColor: AppTheme.corErro,
      ));
      return;
    }

    final nomesServicos = _servicosSel.length > 1
        ? _servicosSel.map((s) => s['nome']).join(' + ')
        : null;

    final dataHora = '${DateFormat('yyyy-MM-dd').format(_dataSel!)} $_horaSel:00';
    final ok = await context.read<AgendamentoController>().agendar(
      colaboradorId: _colaboradorSel!['id'],
      servicoId:     _servicosSel.first['id'],
      dataHora:      dataHora,
      duracaoTotal:  _duracaoTotal,
      valorTotal:    _valorTotal,
      observacao:    nomesServicos,
    );

    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Agendamento confirmado!'),
        backgroundColor: AppTheme.corSucesso,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AgendamentoController>();
    final cor  = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text('Agendar')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ==========================================
          // Serviços (múltipla seleção)
          // ==========================================
          Text('Serviços', style: TextStyle(color: AppTheme.corTextoSecundario, fontSize: 13)),
          const SizedBox(height: 8),

          if (_servicosSel.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cor.withOpacity(0.3)),
              ),
              child: Column(children: [
                ..._servicosSel.map((s) => Row(children: [
                  Icon(Icons.content_cut, color: cor, size: 16),
                  SizedBox(width: 8),
                  Expanded(child: Text(s['nome'],
                      style: TextStyle(color: AppTheme.corTexto, fontWeight: FontWeight.w500))),
                  Text('${s['duracao_min']}min',
                      style: TextStyle(color: cor, fontSize: 12)),
                  const SizedBox(width: 8),
                  Text('R\$${double.parse(s['preco'].toString()).toStringAsFixed(2)}',
                      style: TextStyle(color: cor, fontSize: 12)),
                  SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _toggleServico(s),
                    child: Icon(Icons.close, color: AppTheme.corErro, size: 16),
                  ),
                ])).toList(),
                if (_servicosSel.length > 1) ...[
                  Divider(color: AppTheme.corFundoSecundario),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Total: $_duracaoTotal min',
                        style: TextStyle(color: cor, fontWeight: FontWeight.bold)),
                    Text('R\$ ${_valorTotal.toStringAsFixed(2)}',
                        style: TextStyle(color: cor, fontWeight: FontWeight.bold)),
                  ]),
                ],
              ]),
            ),
            const SizedBox(height: 8),
            Text('Adicionar mais serviços:',
                style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
          ],

          ctrl.carregandoServicos
              ? Center(child: CircularProgressIndicator(color: cor))
              : Wrap(
                  spacing: 8, runSpacing: 8,
                  children: ctrl.servicos.where((s) =>
                      !_servicosSel.any((sel) => sel['id'] == s['id'])).map((s) {
                    return GestureDetector(
                      onTap: () => _toggleServico(s),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.corCard,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: cor.withOpacity(0.3)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.add, color: cor, size: 14),
                          SizedBox(width: 4),
                          Text(s['nome'],
                              style: TextStyle(color: AppTheme.corTexto, fontSize: 13)),
                          const SizedBox(width: 4),
                          Text('${s['duracao_min']}min',
                              style: TextStyle(color: cor, fontSize: 11)),
                        ]),
                      ),
                    );
                  }).toList(),
                ),
          SizedBox(height: 20),

          // ==========================================
          // Profissional
          // ==========================================
          Text('Profissional', style: TextStyle(color: AppTheme.corTextoSecundario, fontSize: 13)),
          const SizedBox(height: 8),
          if (_colaboradorSel != null)
            _CardSelecionado(
              icone: Icons.person_outline, cor: cor,
              titulo: _colaboradorSel!['nome'],
              subtitulo: 'Profissional selecionado',
              onTrocar: () => setState(() { _colaboradorSel = null; _dataSel = null; _horaSel = null; }),
            )
          else
            ctrl.carregandoColaboradores
                ? Center(child: CircularProgressIndicator(color: cor))
                : Column(children: ctrl.colaboradores.map((c) => GestureDetector(
                    onTap: () => setState(() { _colaboradorSel = c; _dataSel = null; _horaSel = null; }),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: AppTheme.corCard, borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        CircleAvatar(radius: 18, backgroundColor: cor.withOpacity(0.2),
                            child: Text(c['nome'][0].toUpperCase(), style: TextStyle(color: cor, fontWeight: FontWeight.bold))),
                        SizedBox(width: 12),
                        Expanded(child: Text(c['nome'], style: TextStyle(color: AppTheme.corTexto, fontWeight: FontWeight.w600))),
                        Icon(Icons.arrow_forward_ios, color: cor, size: 14),
                      ]),
                    ),
                  )).toList()),
          SizedBox(height: 20),

          // ==========================================
          // Data
          // ==========================================
          Text('Data', style: TextStyle(color: AppTheme.corTextoSecundario, fontSize: 13)),
          SizedBox(height: 8),
          GestureDetector(
            onTap: _selecionarData,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _dataSel != null ? cor.withOpacity(0.08) : AppTheme.corCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _dataSel != null ? cor.withOpacity(0.4) : Colors.transparent),
              ),
              child: Row(children: [
                Icon(Icons.calendar_today, color: cor),
                SizedBox(width: 12),
                Text(
                  _dataSel != null ? DateFormat('dd/MM/yyyy').format(_dataSel!) : 'Selecionar data',
                  style: TextStyle(
                    color: _dataSel != null ? AppTheme.corTexto : AppTheme.corTextoSecundario,
                    fontWeight: _dataSel != null ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ]),
            ),
          ),
          SizedBox(height: 20),

          // ==========================================
          // Horários disponíveis
          // ==========================================
          if (_dataSel != null) ...[
            Text('Horários disponíveis (duração: $_duracaoTotal min)',
                style: TextStyle(color: AppTheme.corTextoSecundario, fontSize: 13)),
            SizedBox(height: 8),
            if (ctrl.carregandoHorarios)
              Center(child: CircularProgressIndicator(color: cor))
            else if (ctrl.horariosDisp.isEmpty)
              Text('Nenhum horário disponível nesta data.',
                  style: TextStyle(color: AppTheme.corTextoSecundario))
            else
              Wrap(
                spacing: 8, runSpacing: 8,
                children: ctrl.horariosDisp.map((h) {
                  final sel = _horaSel == h['hora'];
                  return GestureDetector(
                    onTap: () => setState(() => _horaSel = h['hora']),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: sel ? cor : AppTheme.corCard,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(h['hora'], style: TextStyle(
                        color: sel ? AppTheme.corFundo : AppTheme.corTexto,
                        fontWeight: FontWeight.w600,
                      )),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 20),
          ],

          if (ctrl.erro.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.corErro.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(ctrl.erro, style: TextStyle(color: AppTheme.corErro)),
            ),

          // Resumo + Confirmar
          if (_servicosSel.isNotEmpty && _colaboradorSel != null && _horaSel != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Total', style: TextStyle(color: AppTheme.corTextoSecundario)),
                  Text('R\$ ${_valorTotal.toStringAsFixed(2)}',
                      style: TextStyle(color: cor, fontWeight: FontWeight.bold, fontSize: 16)),
                ]),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Duração', style: TextStyle(color: AppTheme.corTextoSecundario)),
                  Text('$_duracaoTotal minutos',
                      style: TextStyle(color: AppTheme.corTexto)),
                ]),
              ]),
            ),
            SizedBox(height: 12),
          ],

          ElevatedButton(
            onPressed: ctrl.salvando ? null : _confirmar,
            child: ctrl.salvando
                ? SizedBox(height: 20, width: 20,
                    child: CircularProgressIndicator(color: AppTheme.corFundo, strokeWidth: 2))
                : Text('Confirmar Agendamento'),
          ),
        ]),
      ),
    );
  }
}

class _CardSelecionado extends StatelessWidget {
  final IconData icone; final String titulo; final String subtitulo;
  final Color cor; final VoidCallback onTrocar;
  const _CardSelecionado({required this.icone, required this.titulo,
      required this.subtitulo, required this.cor, required this.onTrocar});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.corCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor.withOpacity(0.5)),
      ),
      child: Row(children: [
        Icon(icone, color: cor),
        SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo, style: TextStyle(color: AppTheme.corTexto, fontWeight: FontWeight.w600)),
          Text(subtitulo, style: TextStyle(color: cor, fontSize: 12)),
        ])),
        TextButton(onPressed: onTrocar, child: Text('Trocar', style: TextStyle(color: cor, fontSize: 12))),
      ]),
    );
  }
}