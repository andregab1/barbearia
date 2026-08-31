import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/premium_ui.dart';
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
        backgroundColor: PremiumColors.surface,
        title: Text(
          'Cancelar agendamento?',
          style: GoogleFonts.playfairDisplay(
            color: PremiumColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Cancelamentos com menos de 1 hora de antecedência não são permitidos.',
          style: GoogleFonts.inter(color: PremiumColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Voltar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: PremiumColors.error),
            child: const Text('Cancelar agendamento'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    final ctrl = context.read<AgendamentoController>();
    final ok = await ctrl.cancelar(id);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ctrl.erro),
        backgroundColor: AppTheme.erro,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AgendamentoController>();
    return PremiumPage(
      title: 'Minha agenda',
      subtitle: 'Acompanhe seus próximos atendimentos confirmados.',
      actions: [
        IconButton(
          onPressed: ctrl.carregandoAgendamentos
              ? null
              : ctrl.carregarMeusAgendamentos,
          tooltip: 'Atualizar agenda',
          icon: const Icon(Icons.refresh_rounded),
          color: PremiumColors.textSecondary,
        ),
      ],
      child: ctrl.carregandoAgendamentos
          ? const PremiumLoadingState(label: 'Carregando agenda')
          : ctrl.meusAgendamentos.isEmpty
              ? const PremiumSurface(
                  child: PremiumEmptyState(
                    icon: Icons.calendar_month_outlined,
                    title: 'Sua agenda está livre',
                    subtitle: 'Seus próximos agendamentos aparecerão aqui.',
                  ),
                )
              : RefreshIndicator(
                  color: PremiumColors.gold,
                  onRefresh: ctrl.carregarMeusAgendamentos,
                  child: LayoutBuilder(builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 850 ? 2 : 1;
                    const gap = 12.0;
                    final width =
                        (constraints.maxWidth - gap * (columns - 1)) / columns;
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: ctrl.meusAgendamentos.map((appointment) {
                          return SizedBox(
                            width: width,
                            child: _AppointmentCard(
                              appointment: appointment,
                              onCancel: () => _cancelar(appointment['id']),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  }),
                ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final VoidCallback onCancel;
  const _AppointmentCard({required this.appointment, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(appointment['data_hora']);
    return PremiumSurface(
      padding: const EdgeInsets.all(18),
      color: PremiumColors.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: PremiumColors.gold.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.content_cut_rounded,
                  color: PremiumColors.gold,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment['servico']?.toString() ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: PremiumColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      DateFormat('dd/MM/yyyy • HH:mm').format(date),
                      style: GoogleFonts.inter(
                        color: PremiumColors.gold,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const PremiumStatusBadge(
                label: 'Confirmado',
                color: PremiumColors.success,
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, color: PremiumColors.border),
          ),
          Row(
            children: [
              const Icon(
                Icons.person_outline_rounded,
                color: PremiumColors.textMuted,
                size: 17,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  appointment['barbeiro']?.toString() ?? '',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: PremiumColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                premiumCurrency(appointment['valor_cobrado']),
                style: GoogleFonts.inter(
                  color: PremiumColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onCancel,
              icon: const Icon(Icons.close_rounded, size: 17),
              label: const Text('Cancelar'),
              style: TextButton.styleFrom(
                foregroundColor: PremiumColors.error,
                minimumSize: const Size(104, 44),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
