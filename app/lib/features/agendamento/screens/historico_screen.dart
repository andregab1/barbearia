// ==========================================
// TELA: Histórico de Atendimentos
// RF10 - Concluídos e cancelados, SEM total investido
// ==========================================
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/barbearia_theme_service.dart';
import '../controllers/agendamento_controller.dart';

class HistoricoScreen extends StatefulWidget {
  const HistoricoScreen({super.key});

  @override
  State<HistoricoScreen> createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends State<HistoricoScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AgendamentoController>().carregarHistorico();
    });
  }

  Color _corStatus(String status) =>
      status == 'concluido' ? AppTheme.corSucesso : AppTheme.corErro;

  IconData _iconeStatus(String status) =>
      status == 'concluido' ? Icons.check_circle_outline : Icons.cancel_outlined;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AgendamentoController>();
    context.watch<BarbeariaThemeService>(); // garante rebuild ao mudar tema
    final cor  = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Histórico')),
      body: ctrl.carregandoAgendamentos
          ? Center(child: CircularProgressIndicator(color: cor))
          : ctrl.historico.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_outlined,
                          color: cor.withOpacity(0.4), size: 64),
                      const SizedBox(height: 16),
                      Text('Nenhum serviço no histórico.',
                          style: TextStyle(color: AppTheme.corTextoSecundario)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: cor,
                  onRefresh: () => ctrl.carregarHistorico(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: ctrl.historico.length,
                    itemBuilder: (context, i) {
                      final h      = ctrl.historico[i];
                      final data   = DateTime.parse(h['data_hora']);
                      final status = h['status'] as String;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.corCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border(
                            left: BorderSide(
                                color: _corStatus(status), width: 4),
                          ),
                        ),
                        child: Row(children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: _corStatus(status).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(_iconeStatus(status),
                                color: _corStatus(status), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(h['servico'] ?? '',
                                    style: TextStyle(
                                        color: AppTheme.corTexto,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(h['barbeiro'] ?? '',
                                    style: TextStyle(
                                        color: AppTheme.corTextoSecundario,
                                        fontSize: 12)),
                                Text(
                                  DateFormat('dd/MM/yyyy · HH:mm').format(data),
                                  style: TextStyle(
                                      color: AppTheme.corTextoSecundario,
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _corStatus(status).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  status == 'concluido' ? 'Concluído' : 'Cancelado',
                                  style: TextStyle(
                                    color: _corStatus(status),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ]),
                      );
                    },
                  ),
                ),
    );
  }
}