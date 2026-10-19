import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/premium_ui.dart';
import '../controllers/financial_controller.dart';
import 'commission_rule_wizard_screen.dart';

class CommissionDashboardScreen extends StatefulWidget {
  const CommissionDashboardScreen({super.key});

  @override
  State<CommissionDashboardScreen> createState() =>
      _CommissionDashboardScreenState();
}

class _CommissionDashboardScreenState extends State<CommissionDashboardScreen> {
  final _currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final Set<int> _selected = <int>{};
  Timer? _debounce;
  int _tab = 0;
  String? _status;
  bool _loadingDetails = false;

  FinancialController get _state => context.read<FinancialController>();

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0;
  }

  int _int(dynamic value) => int.tryParse(value.toString()) ?? 0;

  String _money(dynamic value) => _currency.format(_number(value));

  List<Map<String, dynamic>> _items(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<FinancialController>();
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 760;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _header(state, compact),
        const SizedBox(height: 16),
        _tabs(state),
        const SizedBox(height: 14),
        if (_tab == 0) ...[
          _summary(state, compact),
          const SizedBox(height: 14),
          _filters(state, compact),
          const SizedBox(height: 14),
          Expanded(child: _professionals(state, compact)),
        ] else ...[
          _historyFilters(state),
          const SizedBox(height: 14),
          Expanded(child: _history(state)),
        ],
        if (_tab == 0 && _selected.isNotEmpty) _selectionBar(state, compact),
      ]);
    });
  }

  Widget _header(FinancialController state, bool compact) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Comissões',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
              SizedBox(height: 5),
              Text('Acompanhe a liberação, compensação e pagamento da equipe.',
                  style: TextStyle(
                      color: PremiumColors.textSecondary, fontSize: 13)),
            ]),
          ),
          if (!compact) ...[
            OutlinedButton.icon(
              onPressed: () => _openRules(context, state),
              icon: const Icon(Icons.rule_outlined, size: 18),
              label: const Text('Regras de comissão'),
            ),
            const SizedBox(width: 8),
          ],
          IconButton(
            tooltip: 'Atualizar comissões',
            onPressed: state.loading ? null : state.loadCurrent,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      );

  Widget _tabs(FinancialController state) => Row(children: [
        _tabButton('A pagar', 0),
        const SizedBox(width: 8),
        _tabButton('Histórico', 1),
        const Spacer(),
        if (MediaQuery.sizeOf(context).width < 760)
          IconButton(
            tooltip: 'Regras de comissão',
            onPressed: () => _openRules(context, state),
            icon: const Icon(Icons.rule_outlined),
          ),
      ]);

  Widget _tabButton(String label, int value) => TextButton(
        onPressed: () async {
          setState(() => _tab = value);
          if (value == 1) {
            final state = _state;
            await state.loadCommissionHistory();
            if (mounted) setState(() {});
          }
        },
        style: TextButton.styleFrom(
          foregroundColor:
              _tab == value ? PremiumColors.gold : PremiumColors.textSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        ),
        child: Text(label,
            style: TextStyle(
                fontWeight: _tab == value ? FontWeight.w700 : FontWeight.w500)),
      );

  Widget _summary(FinancialController state, bool compact) {
    final totals = state.commissionBoardTotals;
    final cards = [
      _summaryCard(
          'Disponível para pagar',
          _money(totals['availableCents'] == null
              ? 0
              : _number(totals['availableCents']) / 100),
          Icons.account_balance_wallet_outlined,
          PremiumColors.success,
          'Saldo aprovado e ainda não liquidado.'),
      _summaryCard(
          'Aguardando liberação',
          _money(((_number(totals['pendingReleaseCents']) +
                  _number(totals['pendingApprovalCents'])) /
              100)),
          Icons.hourglass_top_outlined,
          PremiumColors.gold,
          'Inclui recebimento pendente e aprovação manual.'),
      _summaryCard(
          'Pago no período',
          _money(_number(totals['paidPeriodCents']) / 100),
          Icons.check_circle_outline,
          PremiumColors.success,
          'Data considerada: pagamento confirmado.'),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1000
          ? 3
          : constraints.maxWidth >= 560
              ? 2
              : 1;
      final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
      return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: cards
              .map((card) => SizedBox(
                  width: columns == 1 ? double.infinity : width, child: card))
              .toList());
    });
  }

  Widget _summaryCard(String title, String value, IconData icon, Color color,
          String hint) =>
      PremiumSurface(
          padding: const EdgeInsets.all(15),
          child: Row(children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(
                          color: PremiumColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 19, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(hint,
                      style: const TextStyle(
                          color: PremiumColors.textMuted, fontSize: 11)),
                ])),
          ]));

  Widget _filters(FinancialController state, bool compact) => PremiumSurface(
        padding: const EdgeInsets.all(12),
        child: Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                  width: compact ? double.infinity : 260,
                  child: TextField(
                    controller: _search,
                    focusNode: _searchFocus,
                    onChanged: (_) {
                      _debounce?.cancel();
                      _debounce = Timer(const Duration(milliseconds: 300), () {
                        state.loadCommissionBoard(
                            search: _search.text, status: _status);
                      });
                      setState(() {});
                    },
                    decoration: InputDecoration(
                      labelText: 'Buscar profissional',
                      prefixIcon: const Icon(Icons.search, size: 19),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _search.clear();
                                state.loadCommissionBoard(status: _status);
                                setState(() {});
                              },
                              icon: const Icon(Icons.clear, size: 18)),
                    ),
                  )),
              _periodButton(state),
              FilterChip(
                label:
                    Text(_status == null ? 'Situação' : _statusLabel(_status!)),
                selected: _status != null,
                onSelected: (_) => _chooseStatus(state),
              ),
              if (_status != null)
                TextButton(
                    onPressed: () {
                      setState(() => _status = null);
                      state.loadCommissionBoard(search: _search.text);
                    },
                    child: const Text('Limpar filtros')),
            ]),
      );

  Widget _periodButton(FinancialController state) => OutlinedButton.icon(
        onPressed: () async {
          final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
              initialDateRange:
                  DateTimeRange(start: state.from, end: state.to));
          if (picked != null) await state.setPeriod(picked.start, picked.end);
        },
        icon: const Icon(Icons.date_range_outlined, size: 18),
        label: Text(
            '${DateFormat('dd/MM/yyyy').format(state.from)} – ${DateFormat('dd/MM/yyyy').format(state.to)}'),
      );

  String _statusLabel(String value) => switch (value) {
        'available' => 'Disponível',
        'awaiting_approval' => 'Aguardando aprovação',
        'pending_release' => 'A liberar',
        _ => value
      };

  Future<void> _chooseStatus(FinancialController state) async {
    final value = await showModalBottomSheet<String?>(
        context: context,
        builder: (context) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                  title: const Text('Todas as situações'),
                  onTap: () => Navigator.pop(context)),
              for (final item in const [
                'available',
                'awaiting_approval',
                'pending_release'
              ])
                ListTile(
                    title: Text(_statusLabel(item)),
                    onTap: () => Navigator.pop(context, item)),
            ])));
    if (!mounted) return;
    setState(() => _status = value);
    await state.loadCommissionBoard(search: _search.text, status: _status);
  }

  Widget _professionals(FinancialController state, bool compact) {
    if (state.loading)
      return const PremiumLoadingState(label: 'Carregando comissões');
    if (state.error != null)
      return PremiumEmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Não foi possível carregar',
          subtitle: state.error!);
    final rows = state.commissionProfessionals;
    if (rows.isEmpty)
      return const PremiumEmptyState(
          icon: Icons.payments_outlined,
          title: 'Nenhuma comissão encontrada',
          subtitle:
              'Ajuste o período ou conclua um atendimento com recebimento confirmado.');
    final eligible = rows
        .where(_isSelectable)
        .map((row) => _int(row['professional_id']))
        .toSet();
    final allSelected =
        eligible.isNotEmpty && eligible.every(_selected.contains);
    return PremiumSurface(
        padding: EdgeInsets.zero,
        child: Column(children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Row(children: [
                Checkbox(
                    value: allSelected
                        ? true
                        : _selected.isEmpty
                            ? false
                            : null,
                    tristate: true,
                    onChanged: eligible.isEmpty
                        ? null
                        : (_) {
                            setState(() {
                              if (allSelected) {
                                _selected.removeAll(eligible);
                              } else {
                                _selected.addAll(eligible);
                              }
                            });
                          }),
                const SizedBox(width: 4),
                const Expanded(
                    child: Text('Profissional',
                        style: TextStyle(fontWeight: FontWeight.w700))),
                if (!compact) ...const [
                  SizedBox(width: 85, child: Text('A liberar')),
                  SizedBox(width: 85, child: Text('Disponível')),
                  SizedBox(width: 95, child: Text('Adiantamentos')),
                  SizedBox(width: 90, child: Text('A pagar'))
                ],
                const SizedBox(width: 40),
              ])),
          const Divider(height: 1),
          Expanded(
              child: ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) =>
                      _professionalRow(state, rows[index], compact))),
          Padding(
              padding: const EdgeInsets.all(12),
              child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                      'Totais do resultado: ${state.commissionPagination['totalItems'] ?? rows.length} profissional(is)',
                      style: const TextStyle(
                          color: PremiumColors.textSecondary, fontSize: 12)))),
        ]));
  }

  bool _isSelectable(Map<String, dynamic> row) => _number(row['available']) > 0;

  Widget _professionalRow(
      FinancialController state, Map<String, dynamic> row, bool compact) {
    final id = _int(row['professional_id']);
    final selectable = _isSelectable(row);
    return InkWell(
        onTap: () => _openDetails(state, row),
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Checkbox(
                  value: _selected.contains(id),
                  onChanged: !selectable
                      ? null
                      : (_) {
                          setState(() {
                            if (_selected.contains(id))
                              _selected.remove(id);
                            else
                              _selected.add(id);
                          });
                        }),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(row['professional_name']?.toString() ?? 'Profissional',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(
                        '${row['commission_count'] ?? 0} lançamento(s) · ${_statusLabel(row['status']?.toString() ?? '')}',
                        style: const TextStyle(
                            color: PremiumColors.textSecondary, fontSize: 12))
                  ])),
              if (!compact) ...[
                SizedBox(
                    width: 85,
                    child: Text(_money(row['pending_release']),
                        textAlign: TextAlign.right)),
                SizedBox(
                    width: 85,
                    child: Text(_money(row['available']),
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: PremiumColors.success))),
                SizedBox(
                    width: 95,
                    child: Text(_money(row['advance_balance']),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            color: PremiumColors.textSecondary))),
                SizedBox(
                    width: 90,
                    child: Text(_money(row['payable']),
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.w700))),
              ] else
                Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('A pagar',
                              style: TextStyle(
                                  color: PremiumColors.textSecondary,
                                  fontSize: 11)),
                          Text(_money(row['payable']),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 16))
                        ])),
              IconButton(
                  tooltip: 'Ver detalhes',
                  onPressed: () => _openDetails(state, row),
                  icon: const Icon(Icons.chevron_right_rounded)),
            ])));
  }

  Widget _selectionBar(FinancialController state, bool compact) => Material(
      color: PremiumColors.gold.withValues(alpha: .12),
      child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                Text('${_selected.length} profissional(is) selecionado(s)',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                TextButton(
                    onPressed: () => setState(_selected.clear),
                    child: const Text('Limpar')),
                FilledButton.icon(
                    onPressed:
                        state.submitting ? null : () => _reviewPayment(state),
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('Revisar pagamentos')),
              ])));

  Future<void> _openDetails(
      FinancialController state, Map<String, dynamic> row) async {
    if (_loadingDetails) return;
    setState(() => _loadingDetails = true);
    final details = await state
        .loadCommissionProfessionalDetails(_int(row['professional_id']));
    if (mounted) setState(() => _loadingDetails = false);
    if (!mounted || details == null) return;
    await showDialog<void>(
        context: context,
        builder: (context) => _DetailsDialog(
            data: details,
            money: _money,
            onApprove: (ids) async {
              final error = await state.approveCommissions(ids);
              if (context.mounted) Navigator.pop(context);
              if (error != null && mounted)
                AppToast.show(this.context, error, type: AppToastType.error);
            }));
  }

  Future<void> _reviewPayment(FinancialController state) async {
    final preview = await state.createCommissionPaymentPreview({
      'professionalIds': _selected.toList(),
      'filters': {'dateFrom': _date(state.from), 'dateTo': _date(state.to)}
    });
    if (!mounted || preview == null) return;
    final result = await showDialog<bool>(
        context: context,
        builder: (context) => _PaymentReviewDialog(
            preview: preview,
            accounts: _items(state.metadata['accounts']),
            money: _money,
            onConfirm: (payload, key) async {
              final response =
                  await state.payCommissionBatch(payload, idempotencyKey: key);
              if (context.mounted) Navigator.pop(context, response != null);
            }));
    if (result == true && mounted) {
      setState(_selected.clear);
      AppToast.show(context, 'Pagamento registrado e comissão atualizada.',
          type: AppToastType.success);
    }
  }

  Widget _historyFilters(FinancialController state) =>
      Align(alignment: Alignment.centerRight, child: _periodButton(state));

  Widget _history(FinancialController state) {
    if (state.loading) {
      return const PremiumLoadingState(label: 'Carregando histórico');
    }
    if (state.error != null) {
      return PremiumEmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Não foi possível carregar',
        subtitle: state.error!,
      );
    }
    if (state.commissionHistory.isEmpty) {
      return const PremiumEmptyState(
        icon: Icons.history,
        title: 'Nenhum registro no período',
        subtitle: 'Pagamentos e adiantamentos confirmados aparecerão aqui.',
      );
    }
    return PremiumSurface(
      padding: EdgeInsets.zero,
      child: ListView.separated(
        itemCount: state.commissionHistory.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = state.commissionHistory[index];
          final advance = item['type'] == 'advance';
          return ListTile(
            leading: Icon(
              advance ? Icons.payments_outlined : Icons.check_circle_outline,
              color: advance ? PremiumColors.error : PremiumColors.success,
            ),
            title: Text(
              advance
                  ? 'Adiantamento · ${_money(item['amount'])}'
                  : 'Pagamento · ${_money(item['amount'])}',
            ),
            subtitle: Text(
              '${item['professional_name'] ?? 'Profissional'} · ${item['event_date'] ?? item['created_at'] ?? ''}',
            ),
            trailing: Text(item['status']?.toString() ?? 'confirmado'),
          );
        },
      ),
    );
  }

  Future<void> _openRules(
      BuildContext context, FinancialController state) async {
    await showDialog<void>(
        context: context, builder: (context) => _RulesDialog(state: state));
  }
}

class _DetailsDialog extends StatelessWidget {
  final Map<String, dynamic> data;
  final String Function(dynamic) money;
  final Future<void> Function(List<int>) onApprove;
  const _DetailsDialog(
      {required this.data, required this.money, required this.onApprove});

  int _int(dynamic value) => int.tryParse(value.toString()) ?? 0;
  @override
  Widget build(BuildContext context) {
    final items = data['items'] is List
        ? data['items'].map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];
    final pending = items
        .where((item) =>
            item['eligible'] == true && item['approval_status'] == 'pending')
        .toList();
    return AlertDialog(
      title:
          Text(data['professionalName']?.toString() ?? 'Detalhes da comissão'),
      content: SizedBox(
          width: 680,
          height: 500,
          child: items.isEmpty
              ? const Center(child: Text('Nenhum lançamento no período.'))
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final rule = item['rule'] is Map
                        ? Map<String, dynamic>.from(item['rule'])
                        : <String, dynamic>{};
                    return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Expanded(
                                    child: Text(
                                        item['service_name']?.toString() ??
                                            'Serviço',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700))),
                                Text(item['completed_at']?.toString() ?? '',
                                    style: const TextStyle(
                                        color: PremiumColors.textSecondary,
                                        fontSize: 12))
                              ]),
                              const SizedBox(height: 5),
                              Wrap(spacing: 14, runSpacing: 4, children: [
                                Text(
                                    'Base ${money(item['base_amount'] ?? item['original_net_amount'])}'),
                                Text(
                                    'Gerada ${money(item['total_commission'])}'),
                                Text(
                                    'Liberada ${money(item['released_amount'])}'),
                                Text(
                                    'Restante ${money(item['remaining_amount'])}')
                              ]),
                              const SizedBox(height: 5),
                              Text(
                                  rule.isEmpty
                                      ? (item['reason']?.toString() ??
                                          'Regra não encontrada')
                                      : 'Regra: ${rule['type'] == 'fixed' ? 'fixa' : '${rule['value'] ?? rule['value_bps'] ?? ''}%'} · ${rule['base'] ?? 'por unidade'}',
                                  style: const TextStyle(
                                      color: PremiumColors.textSecondary,
                                      fontSize: 12)),
                              if (item['approval_status'] != null)
                                Text(
                                    'Situação: ${item['approval_status'] == 'approved' ? 'Aprovada' : 'Aguardando aprovação'}',
                                    style: TextStyle(
                                        color: item['approval_status'] ==
                                                'approved'
                                            ? PremiumColors.success
                                            : PremiumColors.gold,
                                        fontSize: 12))
                            ]));
                  })),
      actions: [
        if (pending.isNotEmpty)
          OutlinedButton.icon(
              onPressed: () => onApprove(
                  pending.map((item) => _int(item['commission_id'])).toList()),
              icon: const Icon(Icons.verified_outlined),
              label: Text('Aprovar ${pending.length}')),
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar')),
      ],
    );
  }
}

class _PaymentReviewDialog extends StatefulWidget {
  final Map<String, dynamic> preview;
  final List<Map<String, dynamic>> accounts;
  final String Function(dynamic) money;
  final Future<void> Function(Map<String, dynamic>, String) onConfirm;
  const _PaymentReviewDialog(
      {required this.preview,
      required this.accounts,
      required this.money,
      required this.onConfirm});

  @override
  State<_PaymentReviewDialog> createState() => _PaymentReviewDialogState();
}

class _PaymentReviewDialogState extends State<_PaymentReviewDialog> {
  int? accountId;
  String method = 'pix';
  bool sending = false;
  late final String idempotencyKey;
  final note = TextEditingController();

  @override
  void initState() {
    super.initState();
    idempotencyKey =
        'commission-batch-${DateTime.now().microsecondsSinceEpoch}';
  }

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total =
        (widget.preview['totalPayableCents'] as num?)?.toDouble() ?? 0;
    final items = widget.preview['items'] is List
        ? widget.preview['items']
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];
    return AlertDialog(
      title: const Text('Revisar pagamentos'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Confira os valores antes de confirmar. A confirmação registra o pagamento realizado; não faz transferência bancária.',
              ),
              const SizedBox(height: 14),
              ...items.map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                      item['professionalName']?.toString() ?? 'Profissional'),
                  subtitle: Text(
                    'Comissão ${widget.money((item['commissionCents'] as num? ?? 0) / 100)} · Compensação ${widget.money((item['advanceCompensationCents'] as num? ?? 0) / 100)}',
                  ),
                  trailing: Text(
                    widget.money((item['payableCents'] as num? ?? 0) / 100),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const Divider(),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Total líquido: ${widget.money(total / 100)}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 14),
              if (total > 0)
                DropdownButtonFormField<int>(
                  decoration:
                      const InputDecoration(labelText: 'Conta de saída *'),
                  items: widget.accounts
                      .map(
                        (account) => DropdownMenuItem(
                          value: int.tryParse(account['id'].toString()),
                          child: Text(account['name']?.toString() ?? 'Conta'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => accountId = value),
                ),
              if (total > 0) const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: method,
                decoration:
                    const InputDecoration(labelText: 'Forma de pagamento'),
                items: const [
                  DropdownMenuItem(value: 'pix', child: Text('PIX')),
                  DropdownMenuItem(value: 'cash', child: Text('Dinheiro')),
                  DropdownMenuItem(
                      value: 'bank_transfer', child: Text('Transferência')),
                  DropdownMenuItem(value: 'other', child: Text('Outro')),
                ],
                onChanged: (value) => setState(() => method = value ?? method),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                maxLines: 2,
                decoration:
                    const InputDecoration(labelText: 'Observação (opcional)'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: sending ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: sending || (total > 0 && accountId == null)
              ? null
              : () async {
                  setState(() => sending = true);
                  await widget.onConfirm(
                    {
                      'previewId': widget.preview['previewId'],
                      'paymentDate':
                          DateFormat('yyyy-MM-dd').format(DateTime.now()),
                      'paymentMethod': method,
                      'financialAccountId': accountId,
                      'note': note.text.trim(),
                    },
                    idempotencyKey,
                  );
                  if (mounted) setState(() => sending = false);
                },
          child:
              Text(total > 0 ? 'Confirmar pagamento' : 'Confirmar compensação'),
        ),
      ],
    );
  }
}

class _RulesDialog extends StatefulWidget {
  final FinancialController state;
  const _RulesDialog({required this.state});

  @override
  State<_RulesDialog> createState() => _RulesDialogState();
}

class _RulesDialogState extends State<_RulesDialog> {
  late bool automatic;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    automatic =
        widget.state.commissionApprovalSettings['approvalMode'] == 'automatic';
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('Regras de comissão'),
          content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                    'As regras de cálculo preservam o snapshot de cada comissão. A aprovação controla apenas a disponibilidade para pagamento.'),
                const SizedBox(height: 16),
                SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: automatic,
                    onChanged: saving
                        ? null
                        : (value) => setState(() => automatic = value),
                    title: const Text('Aprovar comissões automaticamente'),
                    subtitle: Text(automatic
                        ? 'A aprovação será automática. O pagamento continuará sendo registrado separadamente.'
                        : 'As comissões elegíveis precisarão ser aprovadas por um administrador antes do pagamento.')),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const CommissionRuleWizardScreen()));
                    },
                    icon: const Icon(Icons.tune_outlined),
                    label: const Text('Editar regras de cálculo'))
              ]),
          actions: [
            TextButton(
                onPressed: saving ? null : () => Navigator.pop(context),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        setState(() => saving = true);
                        final error = await widget.state
                            .saveCommissionApprovalSettings(
                                automatic ? 'automatic' : 'manual');
                        if (!context.mounted) return;
                        if (error != null) {
                          setState(() => saving = false);
                          AppToast.show(context, error,
                              type: AppToastType.error);
                          return;
                        }
                        Navigator.pop(context);
                        AppToast.show(
                            context, 'Configuração de aprovação salva.',
                            type: AppToastType.success);
                      },
                child: Text(saving ? 'Salvando...' : 'Salvar alterações'))
          ]);
}
