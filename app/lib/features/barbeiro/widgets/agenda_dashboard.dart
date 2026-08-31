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
          const Icon(Icons.cloud_off_outlined,
              color: PremiumColors.error, size: 40),
          const SizedBox(height: 12),
          Text(message,
              style: GoogleFonts.inter(color: PremiumColors.textSecondary)),
          const SizedBox(height: 12),
          OutlinedButton(
              onPressed: onRetry, child: const Text('Tentar novamente')),
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

  const AgendaDashboard({
    super.key,
    required this.appointments,
    required this.summary,
    required this.occupancy,
    required this.nextAppointment,
    required this.onComplete,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 1120;
    final main = Column(children: [
      _Metrics(summary: summary),
      const SizedBox(height: 20),
      PremiumSurface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _Heading('Proximos atendimentos',
              'Agenda operacional dos proximos 30 dias'),
          const SizedBox(height: 16),
          if (appointments.isEmpty)
            const SizedBox(
              height: 250,
              child: PremiumEmptyState(
                icon: Icons.event_available_outlined,
                title: 'Nenhum atendimento agendado',
                subtitle: 'Sua agenda esta livre por enquanto.',
              ),
            )
          else
            ...appointments.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _AppointmentCard(
                    item: item,
                    onComplete: () => onComplete(item),
                    onCancel: () => onCancel(item),
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
              const SizedBox(width: 24),
              SizedBox(width: 360, child: side),
            ])
          : Column(children: [main, const SizedBox(height: 16), side]),
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
                padding: const EdgeInsets.all(16),
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
                  const SizedBox(width: 12),
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
          for (final card in cards) ...[card, const SizedBox(height: 10)]
        ]);
      }
      return Row(children: [
        for (var i = 0; i < cards.length; i++) ...[
          Expanded(child: cards[i]),
          if (i < cards.length - 1) const SizedBox(width: 12)
        ]
      ]);
    });
  }
}

class _AppointmentCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onComplete;
  final VoidCallback onCancel;
  const _AppointmentCard(
      {required this.item, required this.onComplete, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(item['data_hora'].toString());
    final canComplete = DateUtils.isSameDay(date, DateTime.now());
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: PremiumColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PremiumColors.border)),
      child: LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final time = SizedBox(
          width: compact ? double.infinity : 112,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(DateFormat('HH:mm').format(date),
                style: GoogleFonts.inter(
                    color: PremiumColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w600)),
            Text('${item['duracao_min']} min',
                style: GoogleFonts.inter(
                    color: PremiumColors.textMuted, fontSize: 12)),
            Text(DateFormat('dd/MM').format(date),
                style: GoogleFonts.inter(
                    color: PremiumColors.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ]),
        );
        final details =
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item['servico'] ?? '',
              style: GoogleFonts.inter(
                  color: PremiumColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 5),
          Text(item['cliente'] ?? '',
              style: GoogleFonts.inter(
                  color: PremiumColors.textSecondary, fontSize: 13)),
          if ((item['cliente_telefone'] ?? '').toString().isNotEmpty)
            Text(item['cliente_telefone'],
                style: GoogleFonts.inter(
                    color: PremiumColors.textMuted, fontSize: 12)),
          const SizedBox(height: 8),
          Text(premiumCurrency(item['valor_cobrado']),
              style: GoogleFonts.inter(
                  color: PremiumColors.gold,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          if ((item['observacao'] ?? '').toString().trim().isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(item['observacao'],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    color: PremiumColors.textMuted, fontSize: 12)),
          ],
        ]);
        final actions = Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              PremiumStatusBadge(
                  label: item['status'] ?? 'confirmado',
                  color: PremiumColors.success),
              Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Cancelar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: PremiumColors.error,
                        minimumSize: const Size(108, 42),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: canComplete ? onComplete : null,
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Concluir'),
                      style: FilledButton.styleFrom(
                        backgroundColor: PremiumColors.gold,
                        foregroundColor: PremiumColors.background,
                        minimumSize: const Size(108, 42),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ]),
            ]);
        if (compact) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                time,
                const Divider(height: 24),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: details),
                  SizedBox(width: 238, height: 124, child: actions)
                ])
              ]);
        }
        return SizedBox(
            height: 138,
            child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  time,
                  const VerticalDivider(width: 28),
                  Expanded(child: details),
                  actions
                ]));
      }),
    );
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
        const SizedBox(height: 22),
        const _MetaLabel('PROXIMO ATENDIMENTO'),
        const SizedBox(height: 10),
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
        const Divider(height: 38),
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
        const SizedBox(height: 10),
        LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 6,
            borderRadius: BorderRadius.circular(4)),
        const SizedBox(height: 7),
        Text(
            '${occupancy['bookedMinutes'] ?? 0} min agendados de ${occupancy['availableMinutes'] ?? 0} min disponiveis',
            style: GoogleFonts.inter(
                color: PremiumColors.textMuted, fontSize: 11)),
        const Divider(height: 38),
        const _MetaLabel('AGENDA DE HOJE'),
        const SizedBox(height: 10),
        if (today.isEmpty)
          Text('Seu dia esta livre.',
              style: GoogleFonts.inter(
                  color: PremiumColors.textSecondary, fontSize: 13))
        else
          ...today.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
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
        const SizedBox(height: 3),
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
