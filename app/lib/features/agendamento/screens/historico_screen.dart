import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/premium_ui.dart';
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

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AgendamentoController>();
    return PremiumPage(
      title: 'Histórico',
      subtitle: 'Consulte os atendimentos concluídos e cancelados.',
      actions: [
        IconButton(
          onPressed:
              ctrl.carregandoAgendamentos ? null : ctrl.carregarHistorico,
          tooltip: 'Atualizar histórico',
          icon: const Icon(Icons.refresh_rounded),
          color: PremiumColors.textSecondary,
        ),
      ],
      child: ctrl.carregandoAgendamentos
          ? const PremiumLoadingState(label: 'Carregando histórico')
          : ctrl.historico.isEmpty
              ? const PremiumSurface(
                  child: PremiumEmptyState(
                    icon: Icons.history_rounded,
                    title: 'Nenhum atendimento no histórico',
                    subtitle: 'Atendimentos finalizados aparecerão nesta área.',
                  ),
                )
              : RefreshIndicator(
                  color: PremiumColors.gold,
                  onRefresh: ctrl.carregarHistorico,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: ctrl.historico.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, index) =>
                        _HistoryRow(item: ctrl.historico[index]),
                  ),
                ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final Map<String, dynamic> item;
  const _HistoryRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(item['data_hora']);
    final completed = item['status'] == 'concluido';
    final statusColor = completed ? PremiumColors.success : PremiumColors.error;
    return PremiumSurface(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      color: PremiumColors.card,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              completed ? Icons.check_rounded : Icons.close_rounded,
              color: statusColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['servico']?.toString() ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: PremiumColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item['barbearia'] ?? 'Barbearia'} • ${item['barbeiro'] ?? ''}\n${DateFormat('dd/MM/yyyy • HH:mm').format(date)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: PremiumColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          PremiumStatusBadge(
            label: completed ? 'Concluído' : 'Cancelado',
            color: statusColor,
          ),
        ],
      ),
    );
  }
}
