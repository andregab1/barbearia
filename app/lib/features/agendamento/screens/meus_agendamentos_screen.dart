// ==========================================
// TELA: Agenda do Cliente (apenas confirmados)
// RF06 - Próximos agendamentos confirmados
// ==========================================
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/agendamento_controller.dart';

class MeusAgendamentosScreen extends StatefulWidget {
  const MeusAgendamentosScreen({super.key});
  @override
  State<MeusAgendamentosScreen> createState() => _MeusAgendamentosScreenState();
}

class _MeusAgendamentosScreenState extends State<MeusAgendamentosScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AgendamentoController>().carregarMeusAgendamentos();
    });
  }

  Future<void> _cancelar(int id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.corFundoSecundario,
        title: Text('Cancelar agendamento?', style: TextStyle(color: AppTheme.corTexto)),
        content: Text(
          'Cancelamentos com menos de 1 hora de antecedência não são permitidos.',
          style: TextStyle(color: AppTheme.corTextoSecundario),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text('Voltar', style: TextStyle(color: AppTheme.corTextoSecundario))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Cancelar agendamento', style: TextStyle(color: AppTheme.corErro))),
        ],
      ),
    );
    if (confirmar == true && mounted) {
      final ctrl = context.read<AgendamentoController>();
      final ok   = await ctrl.cancelar(id);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ctrl.erro), backgroundColor: AppTheme.corErro),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AgendamentoController>();
    final cor  = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Minha Agenda')),
      body: ctrl.carregandoAgendamentos
          ? Center(child: CircularProgressIndicator(color: cor))
          : ctrl.meusAgendamentos.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.calendar_month_outlined, color: cor.withOpacity(0.4), size: 64),
                  const SizedBox(height: 16),
                  Text('Nenhum agendamento confirmado.',
                      style: TextStyle(color: AppTheme.corTextoSecundario)),
                ]))
              : RefreshIndicator(
                  color: cor,
                  onRefresh: () => ctrl.carregarMeusAgendamentos(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: ctrl.meusAgendamentos.length,
                    itemBuilder: (context, i) {
                      final ag   = ctrl.meusAgendamentos[i];
                      final data = DateTime.parse(ag['data_hora']);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.corCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border(left: BorderSide(color: cor, width: 4)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(DateFormat('dd/MM/yyyy · HH:mm').format(data),
                                style: TextStyle(color: cor, fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 6),
                            Text(ag['servico'], style: TextStyle(
                                color: AppTheme.corTexto, fontWeight: FontWeight.w600, fontSize: 15)),
                            const SizedBox(height: 4),
                            Row(children: [
                              Icon(Icons.person_outline, color: AppTheme.corTextoSecundario, size: 14),
                              const SizedBox(width: 4),
                              Text(ag['barbeiro'], style: TextStyle(
                                  color: AppTheme.corTextoSecundario, fontSize: 13)),
                              const SizedBox(width: 12),
                              Icon(Icons.attach_money, color: cor, size: 16),
                              Text('R\$ ${double.parse(ag['valor_cobrado'].toString()).toStringAsFixed(2)}',
                                  style: TextStyle(color: cor, fontWeight: FontWeight.bold)),
                            ]),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => _cancelar(ag['id']),
                              icon: const Icon(Icons.cancel_outlined, color: AppTheme.corErro, size: 18),
                              label: const Text('Cancelar', style: TextStyle(color: AppTheme.corErro)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppTheme.corErro),
                                minimumSize: const Size(double.infinity, 40),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}