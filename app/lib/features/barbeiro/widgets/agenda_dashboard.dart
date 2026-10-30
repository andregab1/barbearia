import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/premium_ui.dart';

class AgendaErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const AgendaErrorState(
      {super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.cloud_off_outlined,
              color: PremiumColors.error, size: 40),
          SizedBox(height: 12),
          Text(message,
              style: GoogleFonts.inter(color: PremiumColors.textSecondary)),
          SizedBox(height: 12),
          OutlinedButton(
              onPressed: onRetry, child: Text('Tentar novamente')),
        ]),
      );
}

class AgendaDashboard extends StatelessWidget {
  final List<Map<String, dynamic>> appointments;
  final Map<String, dynamic> summary;
  final Map<String, dynamic> occupancy;
  final Map<String, dynamic>? nextAppointment;
  final Future<void> Function(Map<String, dynamic>) onComplete;
  final Future<void> Function(Map<String, dynamic>) onCancel;
  final Future<void> Function(Map<String, dynamic>) onArrive;
  final Future<void> Function(Map<String, dynamic>) onStart;
  final Future<void> Function(Map<String, dynamic>) onNoShow;

  const AgendaDashboard({
    super.key,
    required this.appointments,
    required this.summary,
    required this.occupancy,
    required this.nextAppointment,
    required this.onComplete,
    required this.onCancel,
    required this.onArrive,
    required this.onStart,
    required this.onNoShow,
  });

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 1120;
    final main = Column(children: [
      _Metrics(summary: summary),
      SizedBox(height: 20),
      PremiumSurface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _Heading('Proximos atendimentos',
              'Agenda operacional dos proximos 30 dias'),
          SizedBox(height: 16),
          if (appointments.isEmpty)
            SizedBox(
              height: 250,
              child: PremiumEmptyState(
                icon: Icons.event_available_outlined,
                title: 'Nenhum atendimento agendado',
                subtitle: 'Sua agenda esta livre por enquanto.',
              ),
            )
          else
            ...appointments.map((item) => Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: _AppointmentCard(
                    item: item,
                    onComplete: () => onComplete(item),
                    onCancel: () => onCancel(item),
                    onArrive: () => onArrive(item),
                    onStart: () => onStart(item),
                    onNoShow: () => onNoShow(item),
                  ),
                )),
        ]),
      ),
    ]);
    final side = _DayOverview(
        next: nextAppointment,
        occupancy: occupancy,
        appointments: appointments);
    return SingleChildScrollView(
      child: desktop
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: main),
              SizedBox(width: 24),
              SizedBox(width: 360, child: side),
            ])
          : Column(children: [main, SizedBox(height: 16), side]),
    );
  }
}

class _Metrics extends StatelessWidget {
  final Map<String, dynamic> summary;
  const _Metrics({required this.summary});

  @override
  Widget build(BuildContext context) {
    final data = [
      ('Hoje', summary['today'] ?? 0, 'atendimentos', Icons.today_outlined),
      (
        'Proximos',
        summary['upcoming'] ?? 0,
        'agendados',
        Icons.calendar_month_outlined
      ),
      (
        'Total',
        summary['total'] ?? 0,
        'atendimentos',
        Icons.analytics_outlined
      ),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final cards = data
          .map((item) => PremiumSurface(
                padding: EdgeInsets.all(16),
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: PremiumColors.gold.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(item.$4, color: PremiumColors.gold, size: 19),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(item.$1,
                            style: GoogleFonts.inter(
                                color: PremiumColors.textSecondary,
                                fontSize: 12)),
                        Text('${item.$2}',
                            style: GoogleFonts.inter(
                                color: PremiumColors.textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.w600)),
                        Text(item.$3,
                            style: GoogleFonts.inter(
                                color: PremiumColors.textMuted, fontSize: 11)),
                      ])),
                ]),
              ))
          .toList();
      if (constraints.maxWidth < 560) {
        return Column(children: [
          for (final card in cards) ...[card, SizedBox(height: 10)]
        ]);
      }
      return Row(children: [
        for (var i = 0; i < cards.length; i++) ...[
          Expanded(child: cards[i]),
          if (i < cards.length - 1) SizedBox(width: 12)
        ]
      ]);
    });
  }
}

class _AppointmentCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onComplete;
  final VoidCallback onCancel;
  final VoidCallback onArrive;
  final VoidCallback onStart;
  final VoidCallback onNoShow;

  const _AppointmentCard({required this.item, required this.onComplete, required this.onCancel, required this.onArrive, required this.onStart, required this.onNoShow});

  Future<void> _confirmNoShow(BuildContext context) async {
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(backgroundColor: PremiumColors.surfaceSecondary, title: Text('Marcar como não compareceu?'), content: Text('O atendimento será mantido no histórico com esse status.'), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text('Confirmar'))]));
    if (confirmed == true) onNoShow();
  }

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(item['data_hora'].toString());
    final status = item['status']?.toString() ?? 'confirmado';
    final compact = MediaQuery.sizeOf(context).width < 620;
    final statusLabel = {'pendente': 'PENDENTE', 'confirmado': 'CONFIRMADO', 'cliente_chegou': 'CLIENTE CHEGOU', 'em_atendimento': 'EM ATENDIMENTO', 'concluido': 'CONCLUÃDO', 'cancelado': 'CANCELADO', 'nao_compareceu': 'NÃO COMPARECEU'}[status] ?? status.toUpperCase();
    final statusColor = status == 'cancelado' || status == 'nao_compareceu' ? PremiumColors.error : status == 'concluido' ? PremiumColors.success : PremiumColors.gold;
    final details = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item['servico'] ?? '', style: GoogleFonts.inter(color: PremiumColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)), SizedBox(height: 5), Text(item['cliente'] ?? '', style: GoogleFonts.inter(color: PremiumColors.textSecondary, fontSize: 13)), if ((item['cliente_telefone'] ?? '').toString().isNotEmpty) Text(item['cliente_telefone'], style: GoogleFonts.inter(color: PremiumColors.textMuted, fontSize: 12)), SizedBox(height: 8), Text(premiumCurrency(item['valor_cobrado']), style: GoogleFonts.inter(color: PremiumColors.gold, fontSize: 13, fontWeight: FontWeight.w600)), if ((item['observacao'] ?? '').toString().trim().isNotEmpty) ...[SizedBox(height: 7), Text(item['observacao'], maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(color: PremiumColors.textMuted, fontSize: 12))]]);
    Widget actions() {
      if (status == 'confirmado' || status == 'pendente') return Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.end, children: [OutlinedButton.icon(onPressed: onCancel, icon: Icon(Icons.close_rounded, size: 16), label: Text('Cancelar'), style: OutlinedButton.styleFrom(foregroundColor: PremiumColors.error, minimumSize: const Size(108, 42))), OutlinedButton.icon(onPressed: () => _confirmNoShow(context), icon: Icon(Icons.person_off_outlined, size: 16), label: Text('Mais'), style: OutlinedButton.styleFrom(foregroundColor: PremiumColors.textSecondary, minimumSize: const Size(92, 42))), FilledButton.icon(onPressed: onArrive, icon: Icon(Icons.how_to_reg_outlined, size: 16), label: Text('Chegou'), style: FilledButton.styleFrom(backgroundColor: PremiumColors.gold, foregroundColor: PremiumColors.background, minimumSize: const Size(108, 42))) ]);
      if (status == 'cliente_chegou') return FilledButton.icon(onPressed: onStart, icon: Icon(Icons.play_arrow_rounded, size: 16), label: Text('Iniciar atendimento'), style: FilledButton.styleFrom(backgroundColor: PremiumColors.gold, foregroundColor: PremiumColors.background, minimumSize: const Size(190, 42)));
      if (status == 'em_atendimento') return FilledButton.icon(onPressed: onComplete, icon: Icon(Icons.check_rounded, size: 16), label: Text('Concluir'), style: FilledButton.styleFrom(backgroundColor: PremiumColors.gold, foregroundColor: PremiumColors.background, minimumSize: const Size(124, 42)));
      return SizedBox.shrink();
    }
    return Container(padding: EdgeInsets.all(16), decoration: BoxDecoration(color: PremiumColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: PremiumColors.border)), child: LayoutBuilder(builder: (context, constraints) {
      final time = SizedBox(width: compact ? double.infinity : 112, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(DateFormat('HH:mm').format(date), style: GoogleFonts.inter(color: PremiumColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w600)), Text(item['duracao_min'].toString() + ' min', style: GoogleFonts.inter(color: PremiumColors.textMuted, fontSize: 12)), Text(DateFormat('dd/MM').format(date), style: GoogleFonts.inter(color: PremiumColors.gold, fontSize: 12, fontWeight: FontWeight.w600))]));
      final actionArea = Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [PremiumStatusBadge(label: statusLabel, color: statusColor), actions()]);
      if (compact) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [time, Divider(height: 24), details, SizedBox(height: 14), Align(alignment: Alignment.centerRight, child: actionArea)]);
      return SizedBox(height: 138, child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [time, const VerticalDivider(width: 28), Expanded(child: details), actionArea]));
    }));
  }
}

class _DayOverview extends StatelessWidget {
  final Map<String, dynamic>? next;
  final Map<String, dynamic> occupancy;
  final List<Map<String, dynamic>> appointments;
  const _DayOverview(
      {required this.next,
      required this.occupancy,
      required this.appointments});

  @override
  Widget build(BuildContext context) {
    final percentage = (occupancy['percentage'] as num?)?.toDouble() ?? 0;
    final today = appointments
        .where((item) => DateUtils.isSameDay(
            DateTime.parse(item['data_hora'].toString()), DateTime.now()))
        .take(4);
    return PremiumSurface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _Heading('Visao do dia', 'Resumo operacional de hoje'),
        SizedBox(height: 22),
        const _MetaLabel('PROXIMO ATENDIMENTO'),
        SizedBox(height: 10),
        if (next == null)
          Text('Nenhum atendimento futuro.',
              style: GoogleFonts.inter(
                  color: PremiumColors.textSecondary, fontSize: 13))
        else ...[
          Text(
              DateFormat('HH:mm')
                  .format(DateTime.parse(next!['data_hora'].toString())),
              style: GoogleFonts.inter(
                  color: PremiumColors.gold,
                  fontSize: 28,
                  fontWeight: FontWeight.w600)),
          Text(next!['servico'] ?? '',
              style: GoogleFonts.inter(
                  color: PremiumColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          Text(next!['cliente'] ?? '',
              style: GoogleFonts.inter(
                  color: PremiumColors.textSecondary, fontSize: 13)),
        ],
        Divider(height: 38),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Ocupacao do dia',
              style: GoogleFonts.inter(
                  color: PremiumColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          Text('${percentage.round()}%',
              style: GoogleFonts.inter(
                  color: PremiumColors.gold, fontWeight: FontWeight.w600)),
        ]),
        SizedBox(height: 10),
        LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 6,
            borderRadius: BorderRadius.circular(4)),
        SizedBox(height: 7),
        Text(
            '${occupancy['bookedMinutes'] ?? 0} min agendados de ${occupancy['availableMinutes'] ?? 0} min disponiveis',
            style: GoogleFonts.inter(
                color: PremiumColors.textMuted, fontSize: 11)),
        Divider(height: 38),
        const _MetaLabel('AGENDA DE HOJE'),
        SizedBox(height: 10),
        if (today.isEmpty)
          Text('Seu dia esta livre.',
              style: GoogleFonts.inter(
                  color: PremiumColors.textSecondary, fontSize: 13))
        else
          ...today.map((item) => Padding(
                padding: EdgeInsets.symmetric(vertical: 7),
                child: Row(children: [
                  SizedBox(
                      width: 48,
                      child: Text(
                          DateFormat('HH:mm').format(
                              DateTime.parse(item['data_hora'].toString())),
                          style: GoogleFonts.inter(
                              color: PremiumColors.gold,
                              fontSize: 12,
                              fontWeight: FontWeight.w600))),
                  Expanded(
                      child: Text(item['servico'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              color: PremiumColors.textSecondary,
                              fontSize: 12))),
                ]),
              )),
      ]),
    );
  }
}

class _Heading extends StatelessWidget {
  final String title;
  final String subtitle;
  const _Heading(this.title, this.subtitle);
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: GoogleFonts.inter(
                color: PremiumColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
        SizedBox(height: 3),
        Text(subtitle,
            style: GoogleFonts.inter(
                color: PremiumColors.textMuted, fontSize: 12)),
      ]);
}

class _MetaLabel extends StatelessWidget {
  final String label;
  const _MetaLabel(this.label);
  @override
  Widget build(BuildContext context) => Text(label,
      style: GoogleFonts.inter(
          color: PremiumColors.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1));
}
