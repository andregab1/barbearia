import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/premium_ui.dart';
import '../controllers/financial_controller.dart';
import 'commission_rule_wizard_screen.dart';
import 'report_download_stub.dart'
    if (dart.library.html) 'report_download_web.dart';
import 'service_receipt_pdf_svg.dart';

class FinanceiroScreen extends StatefulWidget {
  const FinanceiroScreen({super.key});
  @override
  State<FinanceiroScreen> createState() => _FinanceiroScreenState();
}

class _FinanceiroScreenState extends State<FinanceiroScreen> {
  final money = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final Set<int> _selectedReceivables = <int>{};
  final Set<int> _selectedExpenses = <int>{};
  final Set<int> _issuingReceipts = <int>{};
  bool _expenseSelectionMode = false;
  int _commissionTab = 0;
  final ScrollController _commissionScrollController = ScrollController();
  final GlobalKey _commissionRulesCardKey = GlobalKey();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<FinancialController>().initialize());
  }

  @override
  void dispose() {
    _commissionScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<FinancialController>();
    return PremiumPage(
      title: 'Financeiro',
      subtitle: 'Acompanhe o desempenho financeiro da sua barbearia.',
      actions: [
        IconButton(
            tooltip: 'Atualizar',
            onPressed: state.loading ? null : state.loadCurrent,
            icon: const Icon(Icons.refresh_rounded)),
        if (state.area == FinancialArea.overview ||
            state.area == FinancialArea.expenses) ...[
          const SizedBox(width: 10),
          FilledButton.icon(
              onPressed:
                  state.submitting ? null : () => _expenseDialogStable(state),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nova despesa')),
        ],
      ],
      child: Column(children: [
        Expanded(
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(width: 220, child: _navigation(state)),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                _filters(state),
                const SizedBox(height: 14),
                Expanded(
                    child: state.loading
                        ? const PremiumLoadingState(
                            label: 'Carregando financeiro')
                        : state.error != null
                            ? PremiumEmptyState(
                                icon: Icons.cloud_off_outlined,
                                title: 'Nao foi possivel carregar',
                                subtitle: state.error!)
                            : switch (state.area) {
                                FinancialArea.serviceReceipts =>
                                  _serviceReceipts(state),
                                FinancialArea.overview => _overview(state),
                                FinancialArea.movements => _movements(state),
                                FinancialArea.expenses => _expenses(state),
                                FinancialArea.receivables =>
                                  _receivables(state),
                                FinancialArea.commissions =>
                                  _commissions(state),
                                FinancialArea.categories => _categories(state),
                              }),
              ])),
        ])),
      ]),
    );
  }

  Widget _navigation(FinancialController state) => PremiumSurface(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Text('Financeiro',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(10, 0, 10, 14),
            child: Text('Gestao financeira',
                style: TextStyle(
                    color: PremiumColors.textSecondary, fontSize: 11)),
          ),
          _financeNavItem(state, FinancialArea.serviceReceipts,
              Icons.receipt_long_outlined, 'Notas de serviço'),
          const SizedBox(height: 14),
          _financeNavSection('OPERACAO', [
            _financeNavItem(state, FinancialArea.overview,
                Icons.dashboard_outlined, 'Visao geral'),
            _financeNavItem(state, FinancialArea.movements,
                Icons.swap_vert_rounded, 'Movimentacoes'),
          ]),
          const SizedBox(height: 14),
          _financeNavSection('CONTROLE', [
            _financeNavItem(state, FinancialArea.receivables,
                Icons.pending_actions_outlined, 'Contas a receber'),
            _financeNavItem(state, FinancialArea.expenses,
                Icons.receipt_long_outlined, 'Contas a pagar'),
          ]),
          const SizedBox(height: 14),
          _financeNavSection('EQUIPE', [
            _financeNavItem(state, FinancialArea.commissions,
                Icons.groups_2_outlined, 'Comissoes'),
          ]),
          const SizedBox(height: 14),
          _financeNavSection('CONFIGURACAO', [
            _financeNavItem(state, FinancialArea.categories,
                Icons.sell_outlined, 'Categorias'),
          ]),
        ]),
      );

  Widget _financeNavSection(String title, List<Widget> items) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
            child: Text(title,
                style: const TextStyle(
                    color: PremiumColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .8))),
        ...items,
      ]);

  Widget _financeNavItem(FinancialController state, FinancialArea area,
      IconData icon, String label) {
    final selected = state.area == area;
    return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: state.loading
                  ? null
                  : () {
                      if (area != FinancialArea.expenses) {
                        _clearExpenseSelection();
                      }
                      state.setArea(area);
                    },
              child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? PremiumColors.gold.withValues(alpha: .10)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: selected
                            ? PremiumColors.gold.withValues(alpha: .28)
                            : Colors.transparent),
                  ),
                  child: Row(children: [
                    AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 3,
                        height: 22,
                        decoration: BoxDecoration(
                            color: selected
                                ? PremiumColors.gold
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 8),
                    Icon(icon,
                        size: 18,
                        color: selected
                            ? PremiumColors.gold
                            : PremiumColors.textSecondary),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(label,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: selected
                                    ? PremiumColors.gold
                                    : PremiumColors.textPrimary,
                                fontSize: 12,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500))),
                  ])),
            )));
  }

  Widget _commissions(FinancialController state) => PremiumSurface(
        padding: const EdgeInsets.all(16),
        child: CustomScrollView(
          controller: _commissionScrollController,
          slivers: [
            SliverToBoxAdapter(child: _commissionHeader(state)),
            const SliverToBoxAdapter(child: SizedBox(height: 14)),
            SliverToBoxAdapter(child: _commissionTabs()),
            const SliverToBoxAdapter(child: SizedBox(height: 14)),
            SliverToBoxAdapter(child: _commissionKpis(state)),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 8),
              sliver: SliverList(
                delegate: SliverChildListDelegate(_commissionSections(state)),
              ),
            ),
          ],
        ),
      );

  Widget _commissionHeader(FinancialController state) => LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 820;
          final actions = _commissionActions(state);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (compact) ...[
                const Text('Comissoes',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerLeft, child: actions),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                        child: Text('Comissoes',
                            style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w800))),
                    const SizedBox(width: 16),
                    Flexible(
                        child: Align(
                            alignment: Alignment.topRight, child: actions)),
                  ],
                ),
              const SizedBox(height: 8),
              const Text(
                  'Disponível após concluir o atendimento e confirmar o recebimento. Cada item preserva sua regra e memória de cálculo.',
                  style: TextStyle(
                      color: PremiumColors.textSecondary, fontSize: 12)),
            ],
          );
        },
      );

  Widget _commissionActions(FinancialController state) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
              onPressed: state.submitting
                  ? null
                  : () => _commissionAdvanceDialog(state),
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Adiantamento')),
          OutlinedButton.icon(
              onPressed: state.submitting
                  ? null
                  : () => _commissionSettlementDialog(state),
              icon: const Icon(Icons.lock_clock_outlined),
              label: const Text('Fechar período')),
          OutlinedButton.icon(
              onPressed: state.submitting
                  ? null
                  : () => _commissionSimulationDialog(state),
              icon: const Icon(Icons.calculate_outlined),
              label: const Text('Simular')),
          OutlinedButton.icon(
              onPressed: state.submitting ? null : _showCommissionRules,
              icon: const Icon(Icons.rule_outlined),
              label: const Text('Ver regras')),
          FilledButton.icon(
              onPressed:
                  state.submitting ? null : () => _openCommissionWizard(state),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nova regra')),
        ],
      );

  Widget _commissionKpis(FinancialController state) => LayoutBuilder(
        builder: (context, constraints) {
          final width =
              constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
          final columns = width >= 1120
              ? 4
              : width >= 560
                  ? 2
                  : 1;
          const gap = 12.0;
          final cardWidth =
              columns == 1 ? width : (width - (gap * (columns - 1))) / columns;
          final cards = [
            _Kpi(
                label: 'A liberar',
                value:
                    money.format(_num(state.commissionOverview['to_release'])),
                hint:
                    'Calculado, mas aguardando recebimento ou outra condição de liberação.',
                icon: Icons.hourglass_top_outlined,
                color: PremiumColors.gold),
            _Kpi(
                label: 'Disponível para pagamento',
                value:
                    money.format(_num(state.commissionOverview['available'])),
                hint:
                    'Comissão liberada menos pagamentos e adiantamentos a compensar.',
                icon: Icons.account_balance_wallet_outlined,
                color: PremiumColors.success),
            _Kpi(
                label: 'Pago no período',
                value:
                    money.format(_num(state.commissionOverview['paid_period'])),
                hint:
                    'Pagamentos efetivamente registrados no período selecionado.',
                icon: Icons.check_circle_outline,
                color: PremiumColors.success),
            _Kpi(
                label: 'Adiantamentos a compensar',
                value: money.format(
                    _num(state.commissionOverview['advances_to_compensate'])),
                hint:
                    'Valores antecipados que ainda serão abatidos em um acerto.',
                icon: Icons.payments_outlined,
                color: PremiumColors.error),
          ];
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: cards
                .map((card) => SizedBox(width: cardWidth, child: card))
                .toList(),
          );
        },
      );

  Widget _commissionTabs() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _commissionTabButton(0, Icons.groups_2_outlined, 'Por profissional'),
          _commissionTabButton(1, Icons.receipt_long_outlined, 'Lançamentos'),
          _commissionTabButton(2, Icons.lock_clock_outlined, 'Fechamentos'),
          _commissionTabButton(3, Icons.rule_outlined, 'Regras'),
        ]),
      );

  Widget _commissionTabButton(int index, IconData icon, String label) {
    final selected = _commissionTab == index;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected
            ? PremiumColors.gold.withValues(alpha: .14)
            : PremiumColors.card,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _commissionTab = index),
          child: Container(
            constraints: const BoxConstraints(minHeight: 46),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color:
                        selected ? PremiumColors.gold : PremiumColors.border)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon,
                  size: 18,
                  color: selected
                      ? PremiumColors.gold
                      : PremiumColors.textSecondary),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      color: selected
                          ? PremiumColors.gold
                          : PremiumColors.textPrimary,
                      fontWeight:
                          selected ? FontWeight.w800 : FontWeight.w600)),
            ]),
          ),
        ),
      ),
    );
  }

  List<Widget> _commissionSections(FinancialController state) {
    return switch (_commissionTab) {
      0 => <Widget>[_commissionProfessionalsCard(state)],
      1 => <Widget>[_commissionStatementCard(state)],
      2 => <Widget>[
          _commissionSettlementsCard(state),
          const SizedBox(height: 14),
          _commissionPaymentsCard(state),
          const SizedBox(height: 14),
          _commissionAdvancesCard(state),
        ],
      _ => <Widget>[_commissionRulesCard(state)],
    };
  }

  Widget _commissionProfessionalsCard(FinancialController state) =>
      PremiumSurface(
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Por profissional',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          const Text(
              'Saldo disponível agora e pendências do período selecionado.',
              style:
                  TextStyle(color: PremiumColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 12),
          if (state.commissionOverview['professionals'] is! List ||
              (state.commissionOverview['professionals'] as List).isEmpty)
            const Text('Nenhum profissional com comissão calculada no período.')
          else
            ...(state.commissionOverview['professionals'] as List)
                .map((raw) => Map<String, dynamic>.from(raw as Map))
                .map((professional) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.person_outline,
                          color: PremiumColors.gold),
                      title: Text(
                          professional['professional_name']?.toString() ??
                              'Profissional'),
                      subtitle: Text('A liberar ' +
                          money.format(_num(professional['to_release'])) +
                          ' · Pago ' +
                          money.format(_num(professional['paid_period']))),
                      trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(money.format(_num(professional['available'])),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: PremiumColors.success)),
                            const Text('Disponível agora',
                                style: TextStyle(
                                    color: PremiumColors.textSecondary,
                                    fontSize: 11)),
                          ]),
                    )),
        ]),
      );

  Widget _commissionStatementCard(FinancialController state) => PremiumSurface(
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Expanded(
                child: Text('Extrato detalhado',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
            Text('${state.commissionStatementItems.length} itens',
                style: const TextStyle(color: PremiumColors.textSecondary)),
          ]),
          const SizedBox(height: 5),
          Text(
              'Saldo inicial ' +
                  money.format(
                      _num(state.commissionOverview['opening_balance'])) +
                  ' · saldo disponível agora ' +
                  money.format(_num(state.commissionOverview['available'])),
              style: const TextStyle(
                  color: PremiumColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          const Text('Clique em um item para ver a conta completa.',
              style:
                  TextStyle(color: PremiumColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 12),
          if (state.commissionStatementItems.isEmpty)
            const Padding(
                padding: EdgeInsets.all(20),
                child: Text('Nenhuma comissão calculada no período.'))
          else
            ...state.commissionStatementItems.map((item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () => _commissionDetailDialog(state, item),
                  leading: const Icon(Icons.receipt_long_outlined,
                      color: PremiumColors.gold),
                  title: Text(
                      '${item['professional_name'] ?? 'Profissional'} · ${item['service_name'] ?? 'Serviço'}'),
                  subtitle: Text(
                      'Atendimento #${item['appointment_id']} · ${item['completed_at'] ?? ''}'),
                  trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(money.format(_num(item['total_commission'])),
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        Text(
                            'Pendente ${money.format(_num(item['pending_amount']))}',
                            style: TextStyle(
                                color: _num(item['pending_amount']) > 0
                                    ? PremiumColors.gold
                                    : PremiumColors.success,
                                fontSize: 11)),
                      ]),
                )),
        ]),
      );

  void _showCommissionRules() {
    setState(() => _commissionTab = 3);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final rulesContext = _commissionRulesCardKey.currentContext;
      if (!mounted || rulesContext == null) return;
      Scrollable.ensureVisible(
        rulesContext,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        alignment: 0.06,
      );
    });
  }

  Widget _commissionRulesCard(FinancialController state) => PremiumSurface(
        key: _commissionRulesCardKey,
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Regras vigentes e histórico',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          const Text(
              'A regra usada fica congelada no lançamento; alterar uma regra não muda o passado.',
              style:
                  TextStyle(color: PremiumColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 12),
          if (state.commissionRules.isEmpty)
            const Text('Nenhuma regra cadastrada.')
          else
            ...state.commissionRules.map((rule) {
              final fixed = rule['type'] == 'fixed';
              final scope = [rule['professional_name'], rule['service_name']]
                  .where((value) => value != null && '$value'.isNotEmpty)
                  .join(' · ');
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(fixed ? Icons.attach_money : Icons.percent,
                    color: PremiumColors.gold),
                title: Text(fixed
                    ? '${money.format(_num(rule['value']))} por unidade'
                    : '${_num(rule['value']).toStringAsFixed(2)}% · ${rule['base'] == 'gross' ? 'base bruta' : 'base líquida após desconto'}'),
                subtitle: Text(
                    '${scope.isEmpty ? 'Regra padrão da barbearia' : scope} · versão ${rule['version'] ?? '-'}\nVigência: ${_ruleValidityLabel(rule)}'),
                isThreeLine: true,
                trailing: Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _statusChip(_ruleLifecycle(rule)),
                    IconButton(
                      tooltip: 'Editar regra',
                      onPressed: state.submitting
                          ? null
                          : () => _editCommissionRule(state, rule),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ],
                ),
              );
            }),
        ]),
      );

  Future<void> _editCommissionRule(
      FinancialController state, Map<String, dynamic> rule) async {
    final ruleId = int.tryParse('${rule['id']}') ?? 0;
    if (ruleId <= 0) return;

    final draft = await state.createCommissionRuleVersionDraft(ruleId);
    if (!mounted) return;
    if (draft == null) {
      AppToast.show(
        context,
        'Não foi possível abrir a edição desta regra.',
        type: AppToastType.error,
      );
      return;
    }

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CommissionRuleWizardScreen(
          draftId: int.tryParse('${draft['id']}'),
        ),
      ),
    );
    if (saved == true && mounted) await state.loadCurrent();
  }

  Widget _commissionSettlementsCard(FinancialController state) =>
      PremiumSurface(
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Fechamentos e pagamentos',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          const Text(
              'Fechar o período consolida o acerto; pagar é uma etapa separada e pode ser parcial.',
              style:
                  TextStyle(color: PremiumColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 12),
          if (state.commissionSettlements.isEmpty)
            const Text('Nenhum período fechado.')
          else
            ...state.commissionSettlements.map((settlement) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lock_clock_outlined,
                      color: PremiumColors.gold),
                  title: Text(
                      '${settlement['professional_name'] ?? 'Profissional'} · ${settlement['status']}'),
                  subtitle: Text(
                      '${settlement['from_date'] ?? ''} até ${settlement['to_date'] ?? ''} · Pago ${money.format(_num(settlement['paid']))}'),
                  trailing: FilledButton.tonal(
                      onPressed: state.submitting ||
                              _num(settlement['balance']) <= 0
                          ? null
                          : () => _commissionPaymentDialog(state, settlement),
                      child: Text(_num(settlement['balance']) > 0
                          ? 'Pagar'
                          : 'Quitado')),
                )),
        ]),
      );

  Widget _commissionPaymentsCard(FinancialController state) => PremiumSurface(
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Pagamentos registrados',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          const Text('Saídas efetivamente registradas e reversões autorizadas.',
              style:
                  TextStyle(color: PremiumColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 12),
          if (state.commissionPayments.isEmpty)
            const Text('Nenhum pagamento registrado.')
          else
            ...state.commissionPayments.map((payment) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                      payment['status'] == 'confirmed'
                          ? Icons.payments_outlined
                          : Icons.undo_outlined,
                      color: payment['status'] == 'confirmed'
                          ? PremiumColors.success
                          : PremiumColors.textMuted),
                  title: Text(money.format(_num(payment['amount']))),
                  subtitle: Text('Acerto #' +
                      payment['settlement_id'].toString() +
                      ' · ' +
                      (payment['paid_at']?.toString() ?? '') +
                      ' · ' +
                      (payment['account_name']?.toString() ?? '')),
                  trailing: payment['status'] == 'confirmed'
                      ? IconButton(
                          tooltip: 'Reverter pagamento',
                          onPressed: state.submitting
                              ? null
                              : () => _reverseCommissionPaymentDialog(
                                  state, payment),
                          icon: const Icon(Icons.undo_outlined,
                              color: PremiumColors.error))
                      : const Text('Revertido',
                          style: TextStyle(color: PremiumColors.textMuted)),
                )),
        ]),
      );

  Widget _commissionAdvancesCard(FinancialController state) => PremiumSurface(
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Adiantamentos',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          const Text(
              'Cada adiantamento é compensado uma única vez em fechamentos futuros.',
              style:
                  TextStyle(color: PremiumColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 12),
          if (state.commissionAdvances.isEmpty)
            const Text('Nenhum adiantamento registrado.')
          else
            ...state.commissionAdvances.map((advance) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.payments_outlined,
                      color: PremiumColors.error),
                  title: Text(
                      '${advance['professional_id'] ?? 'Profissional'} · ${money.format(_num(advance['amount']))}'),
                  subtitle: Text(
                      '${advance['paid_at'] ?? ''} · Disponível para compensar ${money.format(_num(advance['available']))}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('${advance['method'] ?? ''}'),
                    if (advance['status'] == 'confirmed')
                      IconButton(
                          tooltip: 'Reverter adiantamento',
                          onPressed: state.submitting
                              ? null
                              : () => _reverseCommissionAdvanceDialog(
                                  state, advance),
                          icon: const Icon(Icons.undo_outlined,
                              color: PremiumColors.error))
                  ]),
                )),
        ]),
      );

  Future<void> _commissionDetailDialog(
      FinancialController state, Map<String, dynamic> item) async {
    final rule = item['rule'] is Map
        ? Map<String, dynamic>.from(item['rule'])
        : <String, dynamic>{};
    final base = _num(item['base_amount']);
    final discount = _num(item['discount_amount']);
    final gross = _num(item['gross_amount']);
    final total = _num(item['total_commission']);
    await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: const Text('Como a comissão foi calculada'),
              content: SizedBox(
                  width: 480,
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            '${item['professional_name'] ?? 'Profissional'} · ${item['service_name'] ?? 'Serviço'}'),
                        const SizedBox(height: 14),
                        Text('Valor bruto: ${money.format(gross)}'),
                        Text('Desconto: ${money.format(discount)}'),
                        Text('Base de cálculo: ${money.format(base)}'),
                        const Divider(height: 22),
                        Text(rule['type'] == 'fixed'
                            ? 'Regra: valor fixo de ${money.format(_num(rule['value']))} por unidade'
                            : 'Regra: ${_num(rule['value']).toStringAsFixed(2)}% sobre ${rule['base'] == 'gross' ? 'o bruto' : 'o líquido após desconto'}'),
                        const SizedBox(height: 8),
                        Text('Comissão total: ${money.format(total)}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                        Text(
                            'Liberado: ${money.format(_num(item['released_amount']))}'),
                        Text(
                            'Ainda a liberar: ${money.format(_num(item['pending_amount']))}'),
                        if (item['snapshot'] is Map &&
                            (item['snapshot'] as Map)['rule'] != null) ...[
                          const SizedBox(height: 12),
                          const Text(
                              'A regra acima é um snapshot do momento do atendimento.',
                              style: TextStyle(
                                  color: PremiumColors.textSecondary,
                                  fontSize: 12)),
                        ],
                      ])),
              actions: [
                OutlinedButton.icon(
                    onPressed: () => _commissionAdjustmentDialog(state, item),
                    icon: const Icon(Icons.edit_note_outlined),
                    label: const Text('Ajuste manual')),
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Fechar'))
              ],
            ));
  }

  Future<void> _commissionAdjustmentDialog(
      FinancialController state, Map<String, dynamic> item) async {
    final amount = TextEditingController();
    final reason = TextEditingController();
    String? error;
    final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
                    title: const Text('Ajuste manual de comissão'),
                    content: SizedBox(
                        width: 440,
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                  'Use valor positivo para acrescentar e negativo para descontar. O lançamento original será preservado.'),
                              const SizedBox(height: 14),
                              TextField(
                                  controller: amount,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true, signed: true),
                                  decoration: const InputDecoration(
                                      labelText: 'Valor do ajuste *',
                                      prefixText: 'R\$ ')),
                              const SizedBox(height: 12),
                              TextField(
                                  controller: reason,
                                  maxLength: 240,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                      labelText: 'Motivo *',
                                      hintText:
                                          'Explique por que o ajuste foi feito.')),
                              if (error != null)
                                Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(error!,
                                        style: const TextStyle(
                                            color: PremiumColors.error)))
                            ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Cancelar')),
                      FilledButton(
                          onPressed: () async {
                            final rawAmount = amount.text.trim();
                            final note = reason.text.trim();
                            final parsed =
                                double.tryParse(rawAmount.replaceAll(',', '.'));
                            if (parsed == null ||
                                parsed == 0 ||
                                note.length < 3) {
                              setDialogState(() => error =
                                  'Informe um valor diferente de zero e um motivo com pelo menos 3 caracteres.');
                              return;
                            }
                            final failure = await state
                                .createCommissionAdjustment(
                                    _int(item['entitlement_id']),
                                    {'amount': rawAmount, 'reason': note});
                            if (!context.mounted) return;
                            if (failure != null) {
                              setDialogState(() => error = failure);
                              return;
                            }
                            Navigator.pop(dialogContext, true);
                          },
                          child: const Text('Registrar ajuste'))
                    ])));
    amount.dispose();
    reason.dispose();
    if (result == true && mounted) {
      AppToast.show(context, 'Ajuste manual registrado.',
          type: AppToastType.success);
    }
  }

  Future<void> _reverseCommissionPaymentDialog(
      FinancialController state, Map<String, dynamic> payment) async {
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: const Text('Reverter pagamento'),
              content: SizedBox(
                  width: 420,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('Valor: ' + money.format(_num(payment['amount']))),
                    const SizedBox(height: 12),
                    TextField(
                        controller: reason,
                        maxLength: 240,
                        maxLines: 3,
                        decoration: const InputDecoration(
                            labelText: 'Motivo obrigatório'))
                  ])),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancelar')),
                FilledButton(
                    onPressed: () async {
                      final note = reason.text.trim();
                      if (note.length < 3) return;
                      final failure = await state.reverseCommissionPayment(
                          _int(payment['id']), note);
                      if (!context.mounted) return;
                      if (failure != null) {
                        AppToast.show(context, failure,
                            type: AppToastType.error);
                        return;
                      }
                      Navigator.pop(dialogContext, true);
                    },
                    child: const Text('Confirmar reversão'))
              ],
            ));
    reason.dispose();
    if (confirmed == true && mounted) {
      AppToast.show(context, 'Pagamento revertido.',
          type: AppToastType.success);
    }
  }

  Future<void> _reverseCommissionAdvanceDialog(
      FinancialController state, Map<String, dynamic> advance) async {
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: const Text('Reverter adiantamento'),
              content: SizedBox(
                  width: 420,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('Valor: ' + money.format(_num(advance['amount']))),
                    const SizedBox(height: 12),
                    TextField(
                        controller: reason,
                        maxLength: 240,
                        maxLines: 3,
                        decoration: const InputDecoration(
                            labelText: 'Motivo obrigatório'))
                  ])),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancelar')),
                FilledButton(
                    onPressed: () async {
                      final note = reason.text.trim();
                      if (note.length < 3) return;
                      final failure = await state.reverseCommissionAdvance(
                          _int(advance['id']), note);
                      if (!context.mounted) return;
                      if (failure != null) {
                        AppToast.show(context, failure,
                            type: AppToastType.error);
                        return;
                      }
                      Navigator.pop(dialogContext, true);
                    },
                    child: const Text('Confirmar reversão'))
              ],
            ));
    reason.dispose();
    if (confirmed == true && mounted) {
      AppToast.show(context, 'Adiantamento revertido.',
          type: AppToastType.success);
    }
  }

  Future<void> _commissionPaymentDialog(
      FinancialController state, Map<String, dynamic> settlement) async {
    final amountController = TextEditingController(
        text: _num(settlement['balance']).toStringAsFixed(2));
    int? accountId;
    var method = 'pix';
    String? error;
    final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
              builder: (context, setDialogState) => AlertDialog(
                title: const Text('Registrar pagamento de comissão'),
                content: SizedBox(
                    width: 430,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(
                          'Saldo do acerto: ${money.format(_num(settlement['balance']))}'),
                      const SizedBox(height: 12),
                      TextField(
                          controller: amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'Valor a pagar', prefixText: 'R\$ ')),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                          decoration: const InputDecoration(
                              labelText: 'Conta de saída *'),
                          items: _items(state.metadata['accounts'])
                              .map((e) => DropdownMenuItem(
                                  value: _int(e['id']),
                                  child: Text('${e['name']}')))
                              .toList(),
                          onChanged: (value) =>
                              setDialogState(() => accountId = value)),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                          initialValue: method,
                          decoration: const InputDecoration(
                              labelText: 'Forma de pagamento'),
                          items: const [
                            DropdownMenuItem(
                                value: 'cash', child: Text('Dinheiro')),
                            DropdownMenuItem(value: 'pix', child: Text('PIX')),
                            DropdownMenuItem(
                                value: 'bank_transfer',
                                child: Text('Transferência')),
                            DropdownMenuItem(
                                value: 'other', child: Text('Outro'))
                          ],
                          onChanged: (value) =>
                              setDialogState(() => method = value ?? method)),
                      if (error != null)
                        Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(error!,
                                style: const TextStyle(
                                    color: PremiumColors.error))),
                    ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: accountId == null
                          ? null
                          : () async {
                              final failure = await state
                                  .payCommissionSettlement(
                                      _int(settlement['id']), {
                                'amount': amountController.text.trim(),
                                'account_id': accountId,
                                'method': method,
                                'paid_at': DateFormat("yyyy-MM-dd'T'HH:mm:ss")
                                    .format(DateTime.now())
                              });
                              if (!context.mounted) return;
                              if (failure != null) {
                                setDialogState(() => error = failure);
                                return;
                              }
                              Navigator.pop(dialogContext, true);
                            },
                      child: const Text('Registrar pagamento'))
                ],
              ),
            ));
    amountController.dispose();
    if (result == true && mounted)
      AppToast.show(context, 'Pagamento de comissão registrado.',
          type: AppToastType.success);
  }

  Future<void> _commissionSettlementDialog(FinancialController state) async {
    final professionals = _items(state.metadata['professionals']);
    int? professionalId = state.professionalId;
    String? error;
    final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
                  title: const Text('Fechar período de comissão'),
                  content: SizedBox(
                      width: 430,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        DropdownButtonFormField<int?>(
                            initialValue: professionalId,
                            decoration: const InputDecoration(
                                labelText: 'Profissional *'),
                            items: professionals
                                .map((e) => DropdownMenuItem<int?>(
                                    value: _int(e['id']),
                                    child: Text(e['name'].toString())))
                                .toList(),
                            onChanged: (value) =>
                                setDialogState(() => professionalId = value)),
                        const SizedBox(height: 12),
                        Text('Período selecionado: ' +
                            DateFormat('dd/MM/yyyy').format(state.from) +
                            ' até ' +
                            DateFormat('dd/MM/yyyy').format(state.to)),
                        if (error != null)
                          Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(error!,
                                  style: const TextStyle(
                                      color: PremiumColors.error))),
                      ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Cancelar')),
                    FilledButton(
                        onPressed: () async {
                          if (professionalId == null) {
                            setDialogState(
                                () => error = 'Selecione um profissional.');
                            return;
                          }
                          final failure =
                              await state.createCommissionSettlement({
                            'professional_id': professionalId,
                            'from': DateFormat("yyyy-MM-dd'T'00:00:00")
                                .format(state.from),
                            'to': DateFormat("yyyy-MM-dd'T'00:00:00")
                                .format(state.to.add(const Duration(days: 1)))
                          });
                          if (!context.mounted) return;
                          if (failure != null) {
                            setDialogState(() => error = failure);
                            return;
                          }
                          Navigator.pop(dialogContext, true);
                        },
                        child: const Text('Confirmar fechamento'))
                  ],
                )));
    if (result == true && mounted)
      AppToast.show(context,
          'Fechamento criado e adiantamentos elegíveis foram compensados.',
          type: AppToastType.success);
  }

  Future<void> _commissionAdvanceDialog(FinancialController state) async {
    final professionals = _items(state.metadata['professionals']);
    final amountController = TextEditingController();
    int? professionalId = state.professionalId;
    int? accountId;
    String method = 'cash';
    String? error;
    final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
                  title: const Text('Registrar adiantamento'),
                  content: SizedBox(
                      width: 430,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        DropdownButtonFormField<int?>(
                            initialValue: professionalId,
                            decoration: const InputDecoration(
                                labelText: 'Profissional *'),
                            items: professionals
                                .map((e) => DropdownMenuItem<int?>(
                                    value: _int(e['id']),
                                    child: Text(e['name'].toString())))
                                .toList(),
                            onChanged: (value) =>
                                setDialogState(() => professionalId = value)),
                        const SizedBox(height: 12),
                        TextField(
                            controller: amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                                labelText: 'Valor *', prefixText: 'R\$ ')),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int?>(
                            initialValue: accountId,
                            decoration: const InputDecoration(
                                labelText: 'Conta financeira *'),
                            items: _items(state.metadata['accounts'])
                                .map((e) => DropdownMenuItem<int?>(
                                    value: _int(e['id']),
                                    child: Text(e['name'].toString())))
                                .toList(),
                            onChanged: (value) =>
                                setDialogState(() => accountId = value)),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                            initialValue: method,
                            decoration: const InputDecoration(
                                labelText: 'Forma de pagamento'),
                            items: const [
                              DropdownMenuItem(
                                  value: 'cash', child: Text('Dinheiro')),
                              DropdownMenuItem(
                                  value: 'pix', child: Text('PIX')),
                              DropdownMenuItem(
                                  value: 'bank_transfer',
                                  child: Text('Transferência')),
                              DropdownMenuItem(
                                  value: 'other', child: Text('Outro'))
                            ],
                            onChanged: (value) =>
                                setDialogState(() => method = value ?? method)),
                        if (error != null)
                          Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(error!,
                                  style: const TextStyle(
                                      color: PremiumColors.error))),
                      ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Cancelar')),
                    FilledButton(
                        onPressed: () async {
                          if (professionalId == null ||
                              accountId == null ||
                              amountController.text.trim().isEmpty) {
                            setDialogState(() => error =
                                'Preencha profissional, valor e conta.');
                            return;
                          }
                          final failure = await state.createCommissionAdvance({
                            'professional_id': professionalId,
                            'amount': amountController.text.trim(),
                            'account_id': accountId,
                            'method': method,
                            'paid_at': DateFormat("yyyy-MM-dd'T'HH:mm:ss")
                                .format(DateTime.now()),
                            'notes': 'Adiantamento registrado no Financeiro'
                          });
                          if (!context.mounted) return;
                          if (failure != null) {
                            setDialogState(() => error = failure);
                            return;
                          }
                          Navigator.pop(dialogContext, true);
                        },
                        child: const Text('Registrar'))
                  ],
                )));
    amountController.dispose();
    if (result == true && mounted)
      AppToast.show(context, 'Adiantamento registrado no financeiro.',
          type: AppToastType.success);
  }

  Future<void> _commissionSimulationDialog(FinancialController state) async {
    final gross = TextEditingController(text: '100.00');
    final discount = TextEditingController(text: '10.00');
    final received = TextEditingController(text: '100.00');
    final quantity = TextEditingController(text: '1');
    int? professionalId;
    int? serviceId;
    Map<String, dynamic>? result;
    String? failure;
    final professionals = _items(state.metadata['professionals']);
    final services = _items(state.metadata['services']);
    await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
                  title: const Text('Simular comissão'),
                  content: SizedBox(
                      width: 500,
                      child: SingleChildScrollView(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                        DropdownButtonFormField<int>(
                            decoration: const InputDecoration(
                                labelText: 'Profissional *'),
                            items: professionals
                                .map((e) => DropdownMenuItem(
                                    value: _int(e['id']),
                                    child: Text(e['name'].toString())))
                                .toList(),
                            onChanged: (value) =>
                                setDialogState(() => professionalId = value)),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                            decoration:
                                const InputDecoration(labelText: 'Serviço *'),
                            items: services
                                .map((e) => DropdownMenuItem(
                                    value: _int(e['id']),
                                    child: Text(e['name'].toString())))
                                .toList(),
                            onChanged: (value) =>
                                setDialogState(() => serviceId = value)),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                              child: TextField(
                                  controller: gross,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration: const InputDecoration(
                                      labelText: 'Preço bruto'))),
                          const SizedBox(width: 10),
                          Expanded(
                              child: TextField(
                                  controller: discount,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration: const InputDecoration(
                                      labelText: 'Desconto')))
                        ]),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                              child: TextField(
                                  controller: received,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration: const InputDecoration(
                                      labelText: 'Recebido'))),
                          const SizedBox(width: 10),
                          SizedBox(
                              width: 100,
                              child: TextField(
                                  controller: quantity,
                                  keyboardType: TextInputType.number,
                                  decoration:
                                      const InputDecoration(labelText: 'Qtd.')))
                        ]),
                        if (failure != null)
                          Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(failure!,
                                  style: const TextStyle(
                                      color: PremiumColors.error))),
                        if (result != null) ...[
                          const Divider(height: 24),
                          Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                  result!['status_code'] == 'NO_APPLICABLE_RULE'
                                      ? 'Nenhuma regra aplicável.'
                                      : 'Memória de cálculo',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800))),
                          if (result!['rule'] is Map)
                            Align(
                                alignment: Alignment.centerLeft,
                                child: Text('Regra vencedora: ' +
                                    (result!['rule']['selection_reason']
                                            ?.toString() ??
                                        '') +
                                    ' · versão ' +
                                    (result!['rule']['version']?.toString() ??
                                        '-'))),
                          if (result!['memory'] is Map)
                            Align(
                                alignment: Alignment.centerLeft,
                                child: Text('Base: ' +
                                    money.format(_num(
                                        result!['memory']['base_amount'])) +
                                    ' · Comissão: ' +
                                    money.format(_num(result!['memory']
                                        ['total_commission'])) +
                                    ' · Liberado: ' +
                                    money.format(_num(
                                        result!['memory']['released_amount']))))
                        ]
                      ]))),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Fechar')),
                    FilledButton(
                        onPressed: () async {
                          if (professionalId == null || serviceId == null) {
                            setDialogState(() =>
                                failure = 'Selecione profissional e serviço.');
                            return;
                          }
                          final data = await state.simulateCommission({
                            'professional_id': professionalId,
                            'service_id': serviceId,
                            'effective_at': DateTime.now().toIso8601String(),
                            'gross_amount': gross.text.trim(),
                            'discount_amount': discount.text.trim(),
                            'received_amount': received.text.trim(),
                            'quantity': int.tryParse(quantity.text.trim()) ?? 1,
                          });
                          if (!context.mounted) return;
                          setDialogState(() {
                            result = data;
                            failure = data == null
                                ? state.error ?? 'Não foi possível simular.'
                                : null;
                          });
                        },
                        child: const Text('Calcular'))
                  ],
                )));
    gross.dispose();
    discount.dispose();
    received.dispose();
    quantity.dispose();
  }

  Future<void> _commissionRuleDialog(FinancialController state) async {
    final valueController = TextEditingController(text: '40');
    var type = 'percentage';
    var base = 'net_after_discount';
    int? professionalId;
    int? serviceId;
    final professionals = _items(state.metadata['professionals']);
    final services = _items(state.metadata['services']);
    final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
                    title: const Text('Nova regra de comissao'),
                    content: SizedBox(
                        width: 430,
                        child: SingleChildScrollView(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                              TextField(
                                  controller: valueController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration: const InputDecoration(
                                      labelText: 'Valor',
                                      helperText:
                                          'Percentual de 0 a 100 ou valor fixo por unidade.')),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                  initialValue: type,
                                  decoration:
                                      const InputDecoration(labelText: 'Tipo'),
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'percentage',
                                        child: Text('Percentual')),
                                    DropdownMenuItem(
                                        value: 'fixed',
                                        child: Text('Fixo por unidade'))
                                  ],
                                  onChanged: (value) => setDialogState(
                                      () => type = value ?? type)),
                              if (type == 'percentage') ...[
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                    initialValue: base,
                                    decoration: const InputDecoration(
                                        labelText: 'Base'),
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'net_after_discount',
                                          child: Text('Liquido apos desconto')),
                                      DropdownMenuItem(
                                          value: 'gross', child: Text('Bruto'))
                                    ],
                                    onChanged: (value) => setDialogState(
                                        () => base = value ?? base))
                              ],
                              const SizedBox(height: 12),
                              DropdownButtonFormField<int?>(
                                  initialValue: professionalId,
                                  decoration: const InputDecoration(
                                      labelText: 'Profissional (opcional)'),
                                  items: [
                                    const DropdownMenuItem<int?>(
                                        value: null,
                                        child: Text('Todos os profissionais')),
                                    ...professionals.map((e) =>
                                        DropdownMenuItem<int?>(
                                            value: _int(e['id']),
                                            child: Text('${e['name']}')))
                                  ],
                                  onChanged: (value) => setDialogState(
                                      () => professionalId = value)),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<int?>(
                                  initialValue: serviceId,
                                  decoration: const InputDecoration(
                                      labelText: 'Servico (opcional)'),
                                  items: [
                                    const DropdownMenuItem<int?>(
                                        value: null,
                                        child: Text('Todos os servicos')),
                                    ...services.map((e) =>
                                        DropdownMenuItem<int?>(
                                            value: _int(e['id']),
                                            child: Text('${e['name']}')))
                                  ],
                                  onChanged: (value) =>
                                      setDialogState(() => serviceId = value)),
                            ]))),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Cancelar')),
                      FilledButton(
                          onPressed: () async {
                            final error = await state.createCommissionRule({
                              'value': valueController.text,
                              'type': type,
                              'base': type == 'percentage' ? base : null,
                              'professionalId': professionalId,
                              'serviceId': serviceId
                            });
                            if (!context.mounted) return;
                            if (error != null) {
                              AppToast.show(context, error,
                                  type: AppToastType.error);
                              return;
                            }
                            Navigator.pop(dialogContext, true);
                          },
                          child: const Text('Salvar'))
                    ])));
    valueController.dispose();
    if (result == true && mounted)
      AppToast.show(context, 'Regra criada e versionada.',
          type: AppToastType.success);
  }

  Widget _categories(FinancialController state) => PremiumSurface(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Expanded(
                child: Text('Categorias financeiras',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
            FilledButton.icon(
                onPressed:
                    state.submitting ? null : () => _categoryDialog(state),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nova categoria')),
          ]),
          const SizedBox(height: 6),
          const Text(
              'Organize receitas e despesas sem apagar categorias já usadas no histórico.',
              style:
                  TextStyle(color: PremiumColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 16),
          Expanded(
              child: state.categories.isEmpty
                  ? const PremiumEmptyState(
                      icon: Icons.sell_outlined,
                      title: 'Nenhuma categoria encontrada',
                      subtitle:
                          'Crie a primeira categoria financeira da barbearia.')
                  : ListView.separated(
                      itemCount: state.categories.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, index) {
                        final item = state.categories[index];
                        final active = item['active'] == true ||
                            item['active'] == 1 ||
                            item['active']?.toString() == '1';
                        final income = item['type'] == 'income';
                        return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                                income
                                    ? Icons.trending_up_rounded
                                    : Icons.trending_down_rounded,
                                color: income
                                    ? PremiumColors.success
                                    : PremiumColors.error),
                            title: Text('${item['name']}'),
                            subtitle: Text(income ? 'Receita' : 'Despesa'),
                            trailing: Switch(
                                value: active,
                                onChanged: state.submitting
                                    ? null
                                    : (value) =>
                                        _toggleCategory(state, item, value)));
                      })),
        ]),
      );

  Future<void> _toggleCategory(
      FinancialController state, Map<String, dynamic> item, bool active) async {
    final error = await state.updateCategory(
        _int(item['id']), '${item['name']}', '${item['type']}', active);
    if (mounted)
      AppToast.show(context,
          error ?? (active ? 'Categoria ativada.' : 'Categoria desativada.'),
          type: error == null ? AppToastType.success : AppToastType.error);
  }

  Future<void> _categoryDialog(FinancialController state) async {
    final name = TextEditingController();
    var type = 'expense';
    final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
                    title: const Text('Nova categoria'),
                    content: SizedBox(
                        width: 380,
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          TextField(
                              controller: name,
                              autofocus: true,
                              decoration:
                                  const InputDecoration(labelText: 'Nome')),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                              initialValue: type,
                              decoration:
                                  const InputDecoration(labelText: 'Tipo'),
                              items: const [
                                DropdownMenuItem(
                                    value: 'income', child: Text('Receita')),
                                DropdownMenuItem(
                                    value: 'expense', child: Text('Despesa'))
                              ],
                              onChanged: (value) =>
                                  setDialogState(() => type = value ?? type))
                        ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Cancelar')),
                      FilledButton(
                          onPressed: () async {
                            final error =
                                await state.createCategory(name.text, type);
                            if (!context.mounted) return;
                            if (error != null) {
                              AppToast.show(context, error,
                                  type: AppToastType.error);
                              return;
                            }
                            Navigator.pop(dialogContext, true);
                          },
                          child: const Text('Criar'))
                    ])));
    name.dispose();
    if (result == true && mounted)
      AppToast.show(context, 'Categoria criada.', type: AppToastType.success);
  }

  Widget _filters(FinancialController state) {
    final professionals = _items(state.metadata['professionals']);
    final services = _items(state.metadata['services']);
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final selectedMonth = state.from.year == monthStart.year &&
        state.from.month == monthStart.month &&
        state.from.day == 1 &&
        state.to.year == now.year &&
        state.to.month == now.month &&
        state.to.day == now.day;
    return Wrap(spacing: 8, runSpacing: 10, children: [
      _PeriodButton(
          label: 'Hoje',
          selected: state.from.year == now.year &&
              state.from.month == now.month &&
              state.from.day == now.day &&
              state.to.day == now.day,
          onTap: () {
            _clearExpenseSelection();
            state.setPeriod(now, now);
          }),
      _PeriodButton(
          label: 'Esta semana',
          selected: state.from.year == weekStart.year &&
              state.from.month == weekStart.month &&
              state.from.day == weekStart.day,
          onTap: () {
            _clearExpenseSelection();
            state.setPeriod(weekStart, now);
          }),
      _PeriodButton(
          label: 'Este mes',
          selected: selectedMonth,
          onTap: () {
            _clearExpenseSelection();
            state.setPeriod(monthStart, now);
          }),
      OutlinedButton.icon(
          icon: const Icon(Icons.calendar_month_outlined),
          label: Text(
              '${DateFormat('dd/MM').format(state.from)} - ${DateFormat('dd/MM/yyyy').format(state.to)}'),
          onPressed: () async {
            final value = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                initialDateRange:
                    DateTimeRange(start: state.from, end: state.to));
            if (value != null && mounted) {
              _clearExpenseSelection();
              state.setPeriod(value.start, value.end);
            }
          }),
      SizedBox(
          width: 220,
          child: DropdownButtonFormField<int?>(
              initialValue: state.professionalId,
              decoration: const InputDecoration(
                  labelText: 'Profissional', isDense: true),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('Todos os profissionais')),
                ...professionals.map((e) => DropdownMenuItem(
                    value: _int(e['id']), child: Text('${e['name']}')))
              ],
              onChanged: (value) {
                _clearExpenseSelection();
                state.setProfessional(value);
              })),
      SizedBox(
          width: 205,
          child: DropdownButtonFormField<int?>(
              initialValue: state.serviceId,
              decoration:
                  const InputDecoration(labelText: 'Servico', isDense: true),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('Todos os servicos')),
                ...services.map((e) => DropdownMenuItem(
                    value: _int(e['id']), child: Text('${e['name']}')))
              ],
              onChanged: (value) {
                _clearExpenseSelection();
                state.setService(value);
              })),
    ]);
  }

  Widget _overview(FinancialController state) {
    final d = state.dashboard;
    final cards = [
      (
        'Receita prevista',
        d['forecast'],
        Icons.schedule_rounded,
        PremiumColors.gold,
        'Agendamentos pendentes e confirmados.'
      ),
      (
        'Receita realizada',
        d['realized'],
        Icons.trending_up_rounded,
        PremiumColors.success,
        'Atendimentos concluidos.'
      ),
      (
        'Entradas recebidas',
        d['received'],
        Icons.payments_outlined,
        PremiumColors.success,
        'Pagamentos confirmados no caixa.'
      ),
      (
        'Despesas pagas',
        d['expenses'],
        Icons.trending_down_rounded,
        PremiumColors.error,
        'Saidas reais de despesas.'
      ),
      (
        'A receber',
        d['receivable'],
        Icons.pending_actions_outlined,
        PremiumColors.gold,
        'Concluido menos pagamentos.'
      ),
      (
        'Saldo',
        d['balance'],
        Icons.account_balance_wallet_outlined,
        PremiumColors.gold,
        'Entradas menos saidas e estornos.'
      ),
    ];
    final professionals = _items(d['professionals']);
    final latest = _items(d['latestMovements']);
    final appointments = d['appointments'] is Map
        ? Map<String, dynamic>.from(d['appointments'])
        : <String, dynamic>{};
    final evolution = _items(d['evolution']);
    return SingleChildScrollView(
        child: Column(children: [
      LayoutBuilder(builder: (_, c) {
        final columns = c.maxWidth >= 980
            ? 3
            : c.maxWidth >= 620
                ? 2
                : 1;
        final width = (c.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
            spacing: 12,
            runSpacing: 10,
            children: cards
                .map((e) => SizedBox(
                    width: width,
                    child: _Kpi(
                        label: e.$1,
                        value: money.format(_num(e.$2)),
                        icon: e.$3,
                        color: e.$4,
                        hint: e.$5)))
                .toList());
      }),
      const SizedBox(height: 12),
      LayoutBuilder(builder: (_, c) {
        if (c.maxWidth < 1050)
          return Column(children: [
            _FinancialChart(rows: evolution, money: money),
            const SizedBox(height: 12),
            _latest(latest),
            const SizedBox(height: 12),
            _appointments(appointments),
            const SizedBox(height: 12),
            _professionals(professionals)
          ]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              flex: 9,
              child: Column(children: [
                _FinancialChart(rows: evolution, money: money),
                const SizedBox(height: 12),
                _professionals(professionals)
              ])),
          const SizedBox(width: 12),
          Expanded(
              flex: 3,
              child: Column(children: [
                _latest(latest),
                const SizedBox(height: 12),
                _appointments(appointments)
              ])),
        ]);
      }),
    ]));
  }

  Widget _appointments(Map<String, dynamic> a) => PremiumSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Atendimentos',
            style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        _metric('Confirmados', a['confirmed'], Icons.event_available_outlined,
            PremiumColors.success),
        _metric('Finalizados', a['completed'], Icons.content_cut_rounded,
            PremiumColors.gold),
        _metric('Cancelados', a['cancelled'], Icons.event_busy_outlined,
            PremiumColors.error)
      ]));
  Widget _metric(String label, dynamic value, IconData icon, Color color) =>
      Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
              color: PremiumColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: PremiumColors.border)),
          child: Row(children: [
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 18, color: color)),
            const SizedBox(width: 10),
            Expanded(
                child: Text(label,
                    style: const TextStyle(
                        color: PremiumColors.textSecondary, fontSize: 12))),
            Text('${_int(value)}',
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 18))
          ]));
  Widget _latest(List<Map<String, dynamic>> rows) => PremiumSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Ultimas movimentacoes',
            style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        if (rows.isEmpty)
          const Text('Nenhuma movimentacao no periodo.')
        else
          ...rows.map((e) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('${e['description']}'),
              subtitle: Text('${e['origin_type']} - ${e['status']}'),
              trailing: Text(
                  '${e['type'] == 'income' ? '+' : '-'} ${money.format(_num(e['amount']))}',
                  style: TextStyle(
                      color: e['type'] == 'income'
                          ? PremiumColors.success
                          : PremiumColors.error,
                      fontWeight: FontWeight.w700))))
      ]));
  Widget _professionals(List<Map<String, dynamic>> rows) => PremiumSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Desempenho por profissional',
            style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          const Text('Nenhum atendimento no periodo.')
        else
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Profissional')),
                    DataColumn(label: Text('Finalizados')),
                    DataColumn(label: Text('Realizado')),
                    DataColumn(label: Text('Recebido')),
                    DataColumn(label: Text('Ticket medio'))
                  ],
                  rows: rows
                      .map((e) => DataRow(cells: [
                            DataCell(Text('${e['professional']}')),
                            DataCell(Text('${e['completed']}')),
                            DataCell(Text(money.format(_num(e['realized'])))),
                            DataCell(Text(money.format(_num(e['received'])))),
                            DataCell(
                                Text(money.format(_num(e['average_ticket']))))
                          ]))
                      .toList()))
      ]));

  Widget _movements(FinancialController state) => PremiumSurface(
      child: state.movements.isEmpty
          ? const PremiumEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Nenhuma movimentacao encontrada',
              subtitle: 'Pagamentos e despesas pagas aparecerao aqui.')
          : ListView.separated(
              itemCount: state.movements.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (_, i) {
                final e = state.movements[i];
                final income = e['type'] == 'income';
                return ListTile(
                    leading: Icon(
                        income ? Icons.arrow_upward : Icons.arrow_downward,
                        color: income
                            ? PremiumColors.success
                            : PremiumColors.error),
                    title: Text('${e['description']}'),
                    subtitle: Text(
                        '${e['origin_type']} - ${e['client'] ?? e['category'] ?? ''} - ${e['account']}'),
                    trailing: Text(
                        '${income ? '+' : '-'} ${money.format(_num(e['amount']))}',
                        style: TextStyle(
                            color: income
                                ? PremiumColors.success
                                : PremiumColors.error,
                            fontWeight: FontWeight.w700)));
              }));

  Widget _expenses(FinancialController state) {
    final rows = state.expenses;
    final eligible = rows.where((e) => e['status'] == 'pending').toList();
    final eligibleIds = eligible.map((e) => _int(e['id'])).toSet();
    _selectedExpenses.removeWhere((id) => !eligibleIds.contains(id));
    final selectedRows =
        rows.where((e) => _selectedExpenses.contains(_int(e['id']))).toList();
    final selectedCount = selectedRows.length;
    final allSelected = eligible.isNotEmpty && selectedCount == eligible.length;
    final someSelected = selectedCount > 0 && !allSelected;
    final totalSelectedCents = _sumCents(selectedRows, 'amount');

    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 860;
      final cardWidth =
          compact ? constraints.maxWidth : (constraints.maxWidth - 12) / 2;
      return Column(children: [
        Wrap(spacing: 12, runSpacing: 12, children: [
          SizedBox(
              width: cardWidth,
              child: _Kpi(
                  label: 'Pagas',
                  value: money.format(_num(state.expenseSummary['paid'])),
                  icon: Icons.check_circle_outline,
                  color: PremiumColors.success,
                  hint: 'Despesas liquidadas.')),
          SizedBox(
              width: cardWidth,
              child: _Kpi(
                  label: 'Pendentes',
                  value: money.format(_num(state.expenseSummary['pending'])),
                  icon: Icons.schedule,
                  color: PremiumColors.gold,
                  hint: 'Ainda nao afetam o saldo.')),
        ]),
        const SizedBox(height: 14),
        Expanded(
            child: PremiumSurface(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                      child: Column(children: [
                        Row(children: [
                          const Expanded(
                              child: Text('Contas a pagar',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800))),
                          OutlinedButton.icon(
                              onPressed: () => setState(() {
                                    _expenseSelectionMode =
                                        !_expenseSelectionMode;
                                    if (!_expenseSelectionMode) {
                                      _selectedExpenses.clear();
                                    }
                                  }),
                              icon: Icon(_expenseSelectionMode
                                  ? Icons.remove_done
                                  : Icons.check_box_outlined),
                              label: Text(_expenseSelectionMode
                                  ? 'Cancelar selecao'
                                  : 'Selecionar'))
                        ]),
                        if (_expenseSelectionMode)
                          const Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                  padding: EdgeInsets.only(top: 6),
                                  child: Text('Selecionar todos desta pagina',
                                      style: TextStyle(
                                          color: PremiumColors.textSecondary,
                                          fontSize: 11)))),
                        if (_expenseSelectionMode && selectedCount > 0) ...[
                          const SizedBox(height: 12),
                          Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  color:
                                      PremiumColors.gold.withValues(alpha: .08),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: PremiumColors.gold
                                          .withValues(alpha: .35))),
                              child: Wrap(
                                  spacing: 12,
                                  runSpacing: 10,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                        '$selectedCount de ${eligible.length} selecionadas',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    Text(
                                        'Total selecionado: ${money.format(totalSelectedCents / 100)}'),
                                    FilledButton.icon(
                                        onPressed: state.submitting
                                            ? null
                                            : () => _paySelectedExpenses(
                                                state, selectedRows),
                                        icon: const Icon(Icons.check_rounded),
                                        label: const Text('Marcar como pagas')),
                                    OutlinedButton.icon(
                                        onPressed: state.submitting
                                            ? null
                                            : () => _cancelSelectedExpenses(
                                                state, selectedRows),
                                        icon: const Icon(Icons.delete_outline),
                                        label: const Text('Excluir'))
                                  ]))
                        ]
                      ])),
                  Expanded(
                      child: rows.isEmpty
                          ? const PremiumEmptyState(
                              icon: Icons.money_off,
                              title: 'Nenhuma conta a pagar',
                              subtitle:
                                  'Cadastre uma despesa ou ajuste o periodo selecionado.')
                          : compact
                              ? ListView.separated(
                                  padding:
                                      const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                  itemCount: rows.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (_, index) => _expenseCard(
                                      state, rows[index], eligibleIds),
                                )
                              : ListView.builder(
                                  padding:
                                      const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                  itemCount: rows.length + 1,
                                  itemBuilder: (_, index) {
                                    if (index == 0) {
                                      return _expenseTableHeader(
                                          state,
                                          allSelected,
                                          someSelected,
                                          eligible.isNotEmpty);
                                    }
                                    return _expenseTableRow(
                                        state, rows[index - 1], eligibleIds);
                                  }))
                ])))
      ]);
    });
  }

  Widget _expenseTableHeader(FinancialController state, bool allSelected,
      bool someSelected, bool hasEligible) {
    return Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: PremiumColors.border))),
        child: Row(children: [
          if (_expenseSelectionMode)
            SizedBox(
                width: 42,
                child: Checkbox(
                    value: allSelected
                        ? true
                        : someSelected
                            ? null
                            : false,
                    tristate: true,
                    onChanged: !hasEligible || state.submitting
                        ? null
                        : (_) => setState(() {
                              if (allSelected) {
                                _selectedExpenses.clear();
                              } else {
                                _selectedExpenses.addAll(state.expenses
                                    .where((e) => e['status'] == 'pending')
                                    .map((e) => _int(e['id'])));
                              }
                            }))),
          const Expanded(
              flex: 3,
              child: Text('Descricao',
                  style: TextStyle(fontWeight: FontWeight.w700))),
          const Expanded(
              flex: 2,
              child: Text('Categoria',
                  style: TextStyle(fontWeight: FontWeight.w700))),
          const Expanded(
              flex: 2,
              child: Text('Vencimento',
                  style: TextStyle(fontWeight: FontWeight.w700))),
          const Expanded(
              flex: 2,
              child: Text('Status',
                  style: TextStyle(fontWeight: FontWeight.w700))),
          const Expanded(
              flex: 2,
              child: Align(
                  alignment: Alignment.centerRight,
                  child: Text('Valor',
                      style: TextStyle(fontWeight: FontWeight.w700)))),
          const SizedBox(
              width: 96,
              child: Align(
                  alignment: Alignment.centerRight,
                  child: Text('Acoes',
                      style: TextStyle(fontWeight: FontWeight.w700))))
        ]));
  }

  Widget _expenseTableRow(FinancialController state,
      Map<String, dynamic> expense, Set<int> eligibleIds) {
    final id = _int(expense['id']);
    final pending = eligibleIds.contains(id);
    final selected = _selectedExpenses.contains(id);
    return Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
            color: selected
                ? PremiumColors.gold.withValues(alpha: .08)
                : Colors.transparent,
            border:
                const Border(bottom: BorderSide(color: PremiumColors.border))),
        child: Row(children: [
          if (_expenseSelectionMode)
            SizedBox(
                width: 42,
                child: Checkbox(
                    value: selected,
                    onChanged: !pending || state.submitting
                        ? null
                        : (value) => setState(() {
                              if (value == true) {
                                _selectedExpenses.add(id);
                              } else {
                                _selectedExpenses.remove(id);
                              }
                            }))),
          Expanded(flex: 3, child: Text('${expense['description']}')),
          Expanded(flex: 2, child: Text('${expense['category'] ?? 'Outros'}')),
          Expanded(
              flex: 2,
              child: Text(_dateLabel(expense['due_date']),
                  style: const TextStyle(color: PremiumColors.textSecondary))),
          Expanded(flex: 2, child: _expenseStatus(expense['status'])),
          Expanded(
              flex: 2,
              child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(money.format(_num(expense['amount'])),
                      style: const TextStyle(fontWeight: FontWeight.w700)))),
          SizedBox(width: 96, child: _expenseActions(state, expense))
        ]));
  }

  Widget _expenseCard(FinancialController state, Map<String, dynamic> expense,
      Set<int> eligibleIds) {
    final id = _int(expense['id']);
    final pending = eligibleIds.contains(id);
    final selected = _selectedExpenses.contains(id);
    return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: selected
                ? PremiumColors.gold.withValues(alpha: .08)
                : PremiumColors.surfaceSecondary,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: PremiumColors.border)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (_expenseSelectionMode)
              Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Checkbox(
                      value: selected,
                      onChanged: !pending || state.submitting
                          ? null
                          : (value) => setState(() {
                                if (value == true) {
                                  _selectedExpenses.add(id);
                                } else {
                                  _selectedExpenses.remove(id);
                                }
                              }))),
            Expanded(
                child: Text('${expense['description']}',
                    style: const TextStyle(fontWeight: FontWeight.w700))),
            Text(money.format(_num(expense['amount'])),
                style: const TextStyle(fontWeight: FontWeight.w800))
          ]),
          const SizedBox(height: 8),
          Text('${expense['category'] ?? 'Outros'}',
              style: const TextStyle(color: PremiumColors.textSecondary)),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(
                child: Text('Vencimento: ${_dateLabel(expense['due_date'])}')),
            _expenseStatus(expense['status'])
          ]),
          const SizedBox(height: 8),
          Align(
              alignment: Alignment.centerRight,
              child: _expenseActions(state, expense))
        ]));
  }

  Widget _expenseActions(
      FinancialController state, Map<String, dynamic> expense) {
    final pending = expense['status'] == 'pending';
    if (!pending) return const SizedBox.shrink();
    return Wrap(spacing: 8, children: [
      SizedBox(
          width: 40,
          height: 40,
          child: IconButton(
              tooltip: 'Marcar como paga',
              onPressed:
                  state.submitting ? null : () => _payExpense(state, expense),
              icon: const Icon(Icons.check_rounded, size: 19),
              color: PremiumColors.success)),
      SizedBox(
          width: 40,
          height: 40,
          child: IconButton(
              tooltip: 'Excluir conta',
              onPressed: state.submitting
                  ? null
                  : () => _cancelExpense(state, expense),
              icon: const Icon(Icons.delete_outline, size: 19),
              color: PremiumColors.error))
    ]);
  }

  Widget _expenseStatus(dynamic status) {
    final value = '$status';
    final paid = value == 'paid';
    final cancelled = value == 'cancelled';
    final color = paid
        ? PremiumColors.success
        : cancelled
            ? PremiumColors.textMuted
            : PremiumColors.gold;
    final label = paid
        ? 'Paga'
        : cancelled
            ? 'Cancelada'
            : 'Pendente';
    return Align(
        alignment: Alignment.centerLeft,
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: .35))),
            child: Text(label,
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w700))));
  }

  void _clearExpenseSelection() {
    if (_selectedExpenses.isEmpty && !_expenseSelectionMode) return;
    if (mounted) {
      setState(() {
        _selectedExpenses.clear();
        _expenseSelectionMode = false;
      });
    }
  }

  int _sumCents(List<Map<String, dynamic>> rows, String key) =>
      rows.fold(0, (total, row) => total + _toCents(row[key]));

  int _toCents(dynamic value) {
    var text = '$value'.replaceAll('R\$', '').replaceAll(' ', '');
    if (text.contains(',')) {
      text = text.replaceAll('.', '').replaceAll(',', '.');
    }
    final parts = text.split('.');
    final whole = int.tryParse(parts.first) ?? 0;
    final fraction =
        parts.length > 1 ? (parts[1] + '00').substring(0, 2) : '00';
    return whole * 100 + (int.tryParse(fraction) ?? 0);
  }

  String _dateLabel(dynamic value) {
    final parsed = DateTime.tryParse('${value ?? ''}');
    return parsed == null ? '-' : DateFormat('dd/MM/yyyy').format(parsed);
  }

  Future<void> _paySelectedExpenses(FinancialController state,
      List<Map<String, dynamic>> selectedRows) async {
    final account = await _accountDialog(state, 'Pagar despesas selecionadas');
    if (account == null || !mounted) return;
    final total = money.format(_sumCents(selectedRows, 'amount') / 100);
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Confirmar pagamento em lote'),
                content: Text(
                    'Serão pagas ${selectedRows.length} contas no valor total de $total, usando a mesma conta financeira e a data de hoje.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Confirmar pagamento'))
                ]));
    if (confirmed != true || !mounted) return;
    final error = await state.payExpenses(
        selectedRows.map((e) => _int(e['id'])).toList(),
        account,
        _iso(DateTime.now()));
    if (!mounted) return;
    if (error == null) {
      setState(() {
        _selectedExpenses.clear();
        _expenseSelectionMode = false;
      });
    }
    AppToast.show(context, error ?? 'Despesas pagas com sucesso.',
        type: error == null ? AppToastType.success : AppToastType.error);
  }

  Future<void> _cancelSelectedExpenses(FinancialController state,
      List<Map<String, dynamic>> selectedRows) async {
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Excluir contas selecionadas'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                      'As ${selectedRows.length} contas serão canceladas e sairão dos totais pendentes.'),
                  const SizedBox(height: 12),
                  TextField(
                      controller: reason,
                      decoration: const InputDecoration(
                          labelText: 'Motivo', hintText: 'Informe o motivo'))
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: () => reason.text.trim().length < 3
                          ? null
                          : Navigator.pop(ctx, true),
                      child: const Text('Excluir'))
                ]));
    final cleanReason = reason.text.trim();
    reason.dispose();
    if (confirmed != true || !mounted) return;
    final error = await state.cancelExpenses(
        selectedRows.map((e) => _int(e['id'])).toList(), cleanReason);
    if (!mounted) return;
    if (error == null) {
      setState(() {
        _selectedExpenses.clear();
        _expenseSelectionMode = false;
      });
    }
    AppToast.show(context, error ?? 'Contas excluidas com sucesso.',
        type: error == null ? AppToastType.success : AppToastType.error);
  }

  Widget _serviceReceipts(FinancialController state) {
    final rows = state.receivables;
    if (rows.isEmpty) {
      return const PremiumSurface(
          child: PremiumEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Nenhum atendimento disponível',
              subtitle:
                  'Atendimentos concluídos aparecerão aqui para emissão do comprovante.'));
    }
    return PremiumSurface(
        padding: EdgeInsets.zero,
        child: Column(children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Row(children: [
                const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Emitir nota de serviço',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800)),
                      SizedBox(height: 4),
                      Text(
                          'Selecione um atendimento para baixar o comprovante em PDF A4.',
                          style: TextStyle(
                              color: PremiumColors.textSecondary,
                              fontSize: 11)),
                    ])),
                Icon(Icons.receipt_long_outlined,
                    color: PremiumColors.gold, size: 24),
              ])),
          const Divider(height: 1),
          Expanded(
              child: ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final item = rows[index];
                    final id = _int(item['appointment_id']);
                    final canIssue = _canIssueReceipt(item);
                    return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        child: Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 16,
                            runSpacing: 10,
                            children: [
                              SizedBox(
                                  width: 420,
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            '#$id · ${item['client'] ?? 'Cliente'}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w800)),
                                        const SizedBox(height: 4),
                                        Text(
                                            '${item['service'] ?? 'Serviço'} · ${item['professional'] ?? 'Profissional'}',
                                            style: const TextStyle(
                                                color:
                                                    PremiumColors.textSecondary,
                                                fontSize: 12)),
                                        const SizedBox(height: 3),
                                        Text(
                                            '${_formatDate(item['service_date'])} · ${money.format(_num(item['total_amount']))}',
                                            style: const TextStyle(
                                                color: PremiumColors.textMuted,
                                                fontSize: 11)),
                                      ])),
                              if (canIssue)
                                OutlinedButton.icon(
                                    onPressed: state.submitting ||
                                            _issuingReceipts.contains(id)
                                        ? null
                                        : () => _issueServiceReceipt(item),
                                    icon: _issuingReceipts.contains(id)
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2))
                                        : const Icon(Icons.download_outlined),
                                    label: const Text('Emitir nota de serviço'))
                              else
                                const Text('Dados insuficientes',
                                    style: TextStyle(
                                        color: PremiumColors.textMuted,
                                        fontSize: 11)),
                            ]));
                  })),
        ]));
  }

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    return date == null
        ? 'Data não informada'
        : DateFormat('dd/MM/yyyy HH:mm').format(date.toLocal());
  }

  Widget _receivables(FinancialController state) {
    if (state.receivables.isEmpty) {
      _selectedReceivables.clear();
      return const PremiumSurface(
          child: PremiumEmptyState(
              icon: Icons.task_alt,
              title: 'Nenhum pagamento pendente',
              subtitle:
                  'Atendimentos concluidos e nao pagos aparecerao aqui.'));
    }
    final visibleIds =
        state.receivables.map((e) => _int(e['appointment_id'])).toSet();
    _selectedReceivables.removeWhere((id) => !visibleIds.contains(id));
    final allSelected = _selectedReceivables.length == visibleIds.length;
    return PremiumSurface(
        child: Column(children: [
      Row(children: [
        Checkbox(
            value: allSelected,
            tristate: true,
            onChanged: state.submitting
                ? null
                : (_) => setState(() {
                      if (allSelected) {
                        _selectedReceivables.clear();
                      } else {
                        _selectedReceivables.addAll(visibleIds);
                      }
                    })),
        const Text('Selecionar todos'),
        const Spacer(),
        if (_selectedReceivables.isNotEmpty)
          FilledButton.icon(
              onPressed:
                  state.submitting ? null : () => _bulkReceivablesDialog(state),
              icon: const Icon(Icons.playlist_add_check),
              label: Text('Ações (${_selectedReceivables.length})')),
      ]),
      const Divider(height: 1),
      Expanded(
          child: ListView.separated(
              itemCount: state.receivables.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (_, i) {
                final e = state.receivables[i];
                final id = _int(e['appointment_id']);
                return ListTile(
                  leading: Checkbox(
                      value: _selectedReceivables.contains(id),
                      onChanged: state.submitting
                          ? null
                          : (value) => setState(() => value == true
                              ? _selectedReceivables.add(id)
                              : _selectedReceivables.remove(id))),
                  title: Text('#$id - ${e['client']}'),
                  subtitle: Text(
                      '${e['professional']} - ${e['service']} - ${e['status']}'),
                  trailing: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      children: [
                        Text(money.format(_num(e['outstanding_amount'])),
                            style: const TextStyle(
                                color: PremiumColors.gold,
                                fontWeight: FontWeight.w700)),
                        FilledButton(
                            onPressed: state.submitting
                                ? null
                                : () => _paymentDialogStable(state, e),
                            child: const Text('Registrar pagamento')),
                      ]),
                );
              })),
    ]));
  }

  bool _canIssueReceipt(Map<String, dynamic> item) {
    final appointmentId = _int(item['appointment_id']);
    final total = _num(item['total_amount']);
    final client = item['client']?.toString().trim() ?? '';
    final professional = item['professional']?.toString().trim() ?? '';
    final service = item['service']?.toString().trim() ?? '';
    return appointmentId > 0 &&
        total > 0 &&
        client.isNotEmpty &&
        professional.isNotEmpty &&
        service.isNotEmpty;
  }

  Future<void> _issueServiceReceipt(Map<String, dynamic> item) async {
    final appointmentId = _int(item['appointment_id']);
    if (!_canIssueReceipt(item) || appointmentId <= 0) {
      AppToast.show(context, 'Dados insuficientes para emitir o comprovante.',
          type: AppToastType.error);
      return;
    }
    setState(() => _issuingReceipts.add(appointmentId));
    try {
      final bytes =
          await ServiceReceiptPdf.build(appointment: item, barbershop: {
        'name': item['barbearia_name'],
        'address': item['barbearia_address'],
        'phone': item['barbearia_phone'],
      });
      await downloadReportPdf(bytes, 'comprovante-servico-$appointmentId.pdf');
      if (mounted) {
        AppToast.show(context, 'Comprovante gerado com sucesso.',
            type: AppToastType.success);
      }
    } catch (error, stackTrace) {
      debugPrint('Falha ao gerar comprovante de serviço: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        AppToast.show(context, 'Não foi possível gerar o comprovante.',
            type: AppToastType.error);
      }
    } finally {
      if (mounted) setState(() => _issuingReceipts.remove(appointmentId));
    }
  }

  Future<void> _bulkReceivablesDialog(FinancialController state) async {
    final selected = state.receivables
        .where((e) => _selectedReceivables.contains(_int(e['appointment_id'])))
        .toList();
    if (selected.isEmpty) return;
    final action = await showDialog<String>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
              builder: (ctx, setLocal) => AlertDialog(
                    title: const Text('Ações em lote'),
                    content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${_selectedReceivables.length} conta(s) selecionada(s).'),
                          const SizedBox(height: 14),
                          const Text(
                              'Escolha uma a??o para os pagamentos selecionados.'),
                        ]),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancelar')),
                      OutlinedButton.icon(
                          onPressed: () => Navigator.pop(ctx, 'delete'),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Excluir')),
                      FilledButton.icon(
                          onPressed: () => Navigator.pop(ctx, 'pay'),
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Dar baixa')),
                    ],
                  ));
        });
    if (!mounted || action == null) return;
    final current = state.receivables
        .where((e) => _selectedReceivables.contains(_int(e['appointment_id'])))
        .toList();
    if (action == 'pay') {
      await _bulkPaymentDialog(state, current);
    } else {
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
                  title: const Text('Excluir contas selecionadas?'),
                  content: Text(
                      'As ${current.length} conta(s) serão arquivadas e deixarão de aparecer em A receber.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancelar')),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Excluir'))
                  ]));
      if (confirmed == true) {
        final error = await state.excludeReceivables(
            current.map((e) => _int(e['appointment_id'])).toList());
        if (mounted)
          AppToast.show(
              context, error ?? 'Contas a receber excluídas com sucesso.',
              type: error == null ? AppToastType.success : AppToastType.error);
        if (error == null) setState(_selectedReceivables.clear);
      }
    }
  }

  Future<void> _bulkPaymentDialog(
      FinancialController state, List<Map<String, dynamic>> selected) async {
    final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _BulkPaymentFormDialog(
            controller: state, receivables: selected, money: money));
    if (!mounted || saved != true) return;
    setState(_selectedReceivables.clear);
    AppToast.show(context, 'Pagamentos registrados com sucesso.');
  }

  Future<void> _expenseDialogStable(FinancialController state) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ExpenseFormDialog(controller: state),
    );
    if (!mounted || saved != true) return;
    AppToast.show(context, 'Despesa cadastrada com sucesso.');
  }

  Future<void> _paymentDialogStable(
      FinancialController state, Map<String, dynamic> receivable) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PaymentFormDialog(
          controller: state, receivable: receivable, money: money),
    );
    if (!mounted || saved != true) return;
    AppToast.show(context, 'Pagamento registrado com sucesso.');
  }

  Future<void> _expenseDialog(FinancialController state) async {
    final form = GlobalKey<FormState>(),
        description = TextEditingController(),
        amount = TextEditingController(),
        notes = TextEditingController();
    int? category, account, responsible;
    DateTime competence = DateTime.now(), due = DateTime.now();
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, setLocal) => AlertDialog(
                    title: const Text('Nova despesa'),
                    content: SizedBox(
                        width: 480,
                        child: Form(
                            key: form,
                            child: SingleChildScrollView(
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                  TextFormField(
                                      controller: description,
                                      decoration: const InputDecoration(
                                          labelText: 'Descricao *'),
                                      validator: _required),
                                  const SizedBox(height: 10),
                                  DropdownButtonFormField<int>(
                                      decoration: const InputDecoration(
                                          labelText: 'Categoria *'),
                                      items: _items(
                                              state.metadata['categories'])
                                          .where((e) => e['type'] == 'expense')
                                          .map((e) => DropdownMenuItem(
                                              value: _int(e['id']),
                                              child: Text('${e['name']}')))
                                          .toList(),
                                      onChanged: (v) => category = v,
                                      validator: (v) => v == null
                                          ? 'Selecione a categoria.'
                                          : null),
                                  const SizedBox(height: 10),
                                  TextFormField(
                                      controller: amount,
                                      decoration: const InputDecoration(
                                          labelText: 'Valor *',
                                          prefixText: 'R\$ '),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      validator: (v) => _money(v) <= 0
                                          ? 'Informe um valor valido.'
                                          : null),
                                  const SizedBox(height: 10),
                                  DropdownButtonFormField<int>(
                                      decoration: const InputDecoration(
                                          labelText:
                                              'Conta (opcional ate pagar)'),
                                      items: _items(state.metadata['accounts'])
                                          .map((e) => DropdownMenuItem(
                                              value: _int(e['id']),
                                              child: Text('${e['name']}')))
                                          .toList(),
                                      onChanged: (v) => account = v),
                                  const SizedBox(height: 10),
                                  DropdownButtonFormField<int>(
                                      decoration: const InputDecoration(
                                          labelText: 'Responsavel *'),
                                      items:
                                          _items(state.metadata['responsibles'])
                                              .map((e) => DropdownMenuItem(
                                                  value: _int(e['id']),
                                                  child: Text('${e['name']}')))
                                              .toList(),
                                      onChanged: (v) => responsible = v,
                                      validator: (v) => v == null
                                          ? 'Selecione o responsavel.'
                                          : null),
                                  const SizedBox(height: 10),
                                  TextFormField(
                                      controller: notes,
                                      decoration: const InputDecoration(
                                          labelText: 'Observacao'),
                                      maxLines: 2),
                                  const SizedBox(height: 8),
                                  Text(
                                      'Competencia e vencimento: ${DateFormat('dd/MM/yyyy').format(competence)}')
                                ])))),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancelar')),
                      FilledButton(
                          onPressed: () => form.currentState!.validate()
                              ? Navigator.pop(ctx, true)
                              : null,
                          child: const Text('Salvar despesa'))
                    ])));
    if (ok == true) {
      final error = await state.createExpense({
        'description': description.text.trim(),
        'category_id': category,
        'account_id': account,
        'responsible_user_id': responsible,
        'amount': _money(amount.text).toStringAsFixed(2),
        'competence_date': _iso(competence),
        'due_date': _iso(due),
        'notes': notes.text.trim()
      });
      if (mounted)
        AppToast.show(context, error ?? 'Despesa cadastrada com sucesso.',
            type: error == null ? AppToastType.success : AppToastType.error);
    }
    description.dispose();
    amount.dispose();
    notes.dispose();
  }

  Future<void> _payExpense(
      FinancialController state, Map<String, dynamic> e) async {
    final account = await _accountDialog(state, 'Pagar despesa');
    if (account == null) return;
    final error =
        await state.payExpense(_int(e['id']), account, _iso(DateTime.now()));
    if (mounted)
      AppToast.show(context, error ?? 'Despesa paga com sucesso.',
          type: error == null ? AppToastType.success : AppToastType.error);
  }

  Future<void> _cancelExpense(
      FinancialController state, Map<String, dynamic> e) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Cancelar despesa'),
                content: TextField(
                    controller: reason,
                    decoration: const InputDecoration(labelText: 'Motivo *')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Voltar')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Cancelar despesa'))
                ]));
    if (ok == true) {
      final error = await state.cancelExpense(_int(e['id']), reason.text);
      if (mounted)
        AppToast.show(context, error ?? 'Despesa cancelada.',
            type: error == null ? AppToastType.success : AppToastType.error);
    }
    reason.dispose();
  }

  Future<void> _paymentDialog(
      FinancialController state, Map<String, dynamic> e) async {
    int? account;
    String method = 'pix';
    final notes = TextEditingController();
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, setLocal) => AlertDialog(
                    title: Text('Receber atendimento #${e['appointment_id']}'),
                    content: SizedBox(
                        width: 440,
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${e['client']} · ${e['professional']}'),
                              const SizedBox(height: 8),
                              Text(
                                  'Saldo: ${money.format(_num(e['outstanding_amount']))}',
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 14),
                              DropdownButtonFormField<int>(
                                  decoration: const InputDecoration(
                                      labelText: 'Conta financeira *'),
                                  items: _items(state.metadata['accounts'])
                                      .map((x) => DropdownMenuItem(
                                          value: _int(x['id']),
                                          child: Text('${x['name']}')))
                                      .toList(),
                                  onChanged: (v) =>
                                      setLocal(() => account = v)),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<String>(
                                  initialValue: method,
                                  decoration: const InputDecoration(
                                      labelText: 'Forma *'),
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'cash', child: Text('Dinheiro')),
                                    DropdownMenuItem(
                                        value: 'pix', child: Text('PIX')),
                                    DropdownMenuItem(
                                        value: 'debit_card',
                                        child: Text('Cartao de debito')),
                                    DropdownMenuItem(
                                        value: 'credit_card',
                                        child: Text('Cartao de credito')),
                                    DropdownMenuItem(
                                        value: 'other', child: Text('Outro'))
                                  ],
                                  onChanged: (v) =>
                                      setLocal(() => method = v!)),
                              const SizedBox(height: 10),
                              TextField(
                                  controller: notes,
                                  decoration: const InputDecoration(
                                      labelText: 'Observacao'))
                            ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancelar')),
                      FilledButton(
                          onPressed: account == null
                              ? null
                              : () => Navigator.pop(ctx, true),
                          child: const Text('Confirmar pagamento'))
                    ])));
    if (ok == true) {
      final error = await state.registerPayment(_int(e['appointment_id']), {
        'amount': _num(e['outstanding_amount']).toStringAsFixed(2),
        'account_id': account,
        'method': method,
        'paid_at': _iso(DateTime.now()),
        'notes': notes.text.trim()
      });
      if (mounted)
        AppToast.show(context, error ?? 'Pagamento registrado com sucesso.',
            type: error == null ? AppToastType.success : AppToastType.error);
    }
    notes.dispose();
  }

  Future<int?> _accountDialog(FinancialController state, String title) {
    int? selected;
    return showDialog<int>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, setLocal) => AlertDialog(
                    title: Text(title),
                    content: DropdownButtonFormField<int>(
                        decoration: const InputDecoration(
                            labelText: 'Conta financeira'),
                        items: _items(state.metadata['accounts'])
                            .map((e) => DropdownMenuItem(
                                value: _int(e['id']),
                                child: Text('${e['name']}')))
                            .toList(),
                        onChanged: (v) => setLocal(() => selected = v)),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancelar')),
                      FilledButton(
                          onPressed: selected == null
                              ? null
                              : () => Navigator.pop(ctx, selected),
                          child: const Text('Confirmar'))
                    ])));
  }

  List<Map<String, dynamic>> _items(dynamic v) =>
      v is List ? v.map((e) => Map<String, dynamic>.from(e)).toList() : [];
  int _int(dynamic v) => int.tryParse('$v') ?? 0;
  double _num(dynamic v) => double.tryParse('$v') ?? 0;
  double _money(String? v) =>
      double.tryParse((v ?? '').replaceAll('.', '').replaceAll(',', '.')) ?? 0;
  String _iso(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  String? _required(String? v) =>
      (v ?? '').trim().isEmpty ? 'Campo obrigatorio.' : null;

  Future<void> _openCommissionWizard(FinancialController state) async {
    final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const CommissionRuleWizardScreen()));
    if (saved == true && mounted) await state.loadCurrent();
  }
}

class _ExpenseFormDialog extends StatefulWidget {
  final FinancialController controller;
  const _ExpenseFormDialog({required this.controller});
  @override
  State<_ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends State<_ExpenseFormDialog> {
  final formKey = GlobalKey<FormState>();
  final description = TextEditingController();
  final amount = TextEditingController();
  final notes = TextEditingController();
  int? categoryId, accountId, responsibleId;
  DateTime competence = DateTime.now(), due = DateTime.now();
  bool saving = false;
  String? error;
  List<Map<String, dynamic>> items(dynamic value) => value is List
      ? value.map((e) => Map<String, dynamic>.from(e)).toList()
      : [];
  int id(dynamic value) => int.tryParse('$value') ?? 0;
  String iso(DateTime value) => DateFormat('yyyy-MM-dd').format(value);
  double parsedAmount() =>
      double.tryParse(
          amount.text.trim().replaceAll('.', '').replaceAll(',', '.')) ??
      0;
  @override
  void dispose() {
    description.dispose();
    amount.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> pickDate(bool isDue) async {
    final current = isDue ? due : competence;
    final value = await showDatePicker(
        context: context,
        initialDate: current,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100));
    if (value != null && mounted)
      setState(() {
        if (isDue)
          due = value;
        else
          competence = value;
      });
  }

  Future<void> save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    setState(() {
      saving = true;
      error = null;
    });
    final failure = await widget.controller.createExpense({
      'description': description.text.trim(),
      'category_id': categoryId,
      'account_id': accountId,
      'responsible_user_id': responsibleId,
      'amount': parsedAmount().toStringAsFixed(2),
      'competence_date': iso(competence),
      'due_date': iso(due),
      'notes': notes.text.trim()
    });
    if (!mounted) return;
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      saving = false;
      error = failure;
    });
  }

  @override
  Widget build(BuildContext context) {
    final metadata = widget.controller.metadata;
    final categories = items(metadata['categories'])
        .where((e) => e['type'] == 'expense')
        .toList();
    return AlertDialog(
      title: const Text('Nova despesa'),
      content: SizedBox(
          width: 500,
          child: Form(
              key: formKey,
              child: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                    controller: description,
                    enabled: !saving,
                    decoration: const InputDecoration(labelText: 'Descricao *'),
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'Informe a descricao.'
                        : null),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                    value: categoryId,
                    decoration: const InputDecoration(labelText: 'Categoria *'),
                    items: categories
                        .map((e) => DropdownMenuItem(
                            value: id(e['id']), child: Text('${e['name']}')))
                        .toList(),
                    onChanged:
                        saving ? null : (v) => setState(() => categoryId = v),
                    validator: (v) =>
                        v == null ? 'Selecione a categoria.' : null),
                const SizedBox(height: 12),
                TextFormField(
                    controller: amount,
                    enabled: !saving,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Valor *', prefixText: 'R\$ '),
                    validator: (_) => parsedAmount() <= 0
                        ? 'Informe um valor maior que zero.'
                        : null),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                    value: accountId,
                    decoration: const InputDecoration(
                        labelText: 'Conta financeira (opcional)'),
                    items: items(metadata['accounts'])
                        .map((e) => DropdownMenuItem(
                            value: id(e['id']), child: Text('${e['name']}')))
                        .toList(),
                    onChanged:
                        saving ? null : (v) => setState(() => accountId = v)),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                    value: responsibleId,
                    decoration:
                        const InputDecoration(labelText: 'Responsavel *'),
                    items: items(metadata['responsibles'])
                        .map((e) => DropdownMenuItem(
                            value: id(e['id']), child: Text('${e['name']}')))
                        .toList(),
                    onChanged: saving
                        ? null
                        : (v) => setState(() => responsibleId = v),
                    validator: (v) =>
                        v == null ? 'Selecione o responsavel.' : null),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: OutlinedButton.icon(
                          onPressed: saving ? null : () => pickDate(false),
                          icon: const Icon(Icons.event),
                          label: Text(
                              'Competencia ${DateFormat('dd/MM/yyyy').format(competence)}'))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: OutlinedButton.icon(
                          onPressed: saving ? null : () => pickDate(true),
                          icon: const Icon(Icons.event_available),
                          label: Text(
                              'Vencimento ${DateFormat('dd/MM/yyyy').format(due)}')))
                ]),
                const SizedBox(height: 12),
                TextFormField(
                    controller: notes,
                    enabled: !saving,
                    maxLines: 2,
                    maxLength: 500,
                    decoration: const InputDecoration(labelText: 'Observacao')),
                if (error != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(error!,
                          style: const TextStyle(color: PremiumColors.error))),
              ])))),
      actions: [
        TextButton(
            onPressed: saving ? null : () => Navigator.of(context).pop(false),
            child: const Text('Cancelar')),
        FilledButton(
            onPressed: saving ? null : save,
            child: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Salvar despesa'))
      ],
    );
  }
}

class _PaymentFormDialog extends StatefulWidget {
  final FinancialController controller;
  final Map<String, dynamic> receivable;
  final NumberFormat money;
  const _PaymentFormDialog(
      {required this.controller,
      required this.receivable,
      required this.money});
  @override
  State<_PaymentFormDialog> createState() => _PaymentFormDialogState();
}

class _PaymentFormDialogState extends State<_PaymentFormDialog> {
  final notes = TextEditingController();
  int? accountId;
  String method = 'pix';
  DateTime paidAt = DateTime.now();
  bool saving = false;
  String? error;
  List<Map<String, dynamic>> items(dynamic value) => value is List
      ? value.map((e) => Map<String, dynamic>.from(e)).toList()
      : [];
  int id(dynamic value) => int.tryParse('$value') ?? 0;
  double number(dynamic value) => double.tryParse('$value') ?? 0;
  String iso(DateTime value) => DateFormat('yyyy-MM-dd').format(value);
  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (accountId == null) {
      setState(() => error = 'Selecione a conta financeira.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final failure = await widget.controller.registerPayment(
        id(widget.receivable['appointment_id']),
        {
          'amount': number(widget.receivable['outstanding_amount'])
              .toStringAsFixed(2),
          'account_id': accountId,
          'method': method,
          'paid_at': iso(paidAt),
          'notes': notes.text.trim(),
        },
      );
      if (!mounted) return;
      if (failure == null) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() {
        saving = false;
        error = failure;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error = 'Não foi possível registrar o pagamento. Tente novamente.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: Text(
              'Receber atendimento #${widget.receivable['appointment_id']}'),
          content: SizedBox(
              width: 470,
              child: SingleChildScrollView(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                        '${widget.receivable['client']} - ${widget.receivable['professional']}'),
                    const SizedBox(height: 6),
                    Text('${widget.receivable['service']}'),
                    const SizedBox(height: 12),
                    Text(
                        'Saldo integral: ${widget.money.format(number(widget.receivable['outstanding_amount']))}',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<int>(
                        value: accountId,
                        decoration: const InputDecoration(
                            labelText: 'Conta financeira *'),
                        items: items(widget.controller.metadata['accounts'])
                            .map((e) => DropdownMenuItem(
                                value: id(e['id']),
                                child: Text('${e['name']}')))
                            .toList(),
                        onChanged: saving
                            ? null
                            : (v) => setState(() => accountId = v)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                        value: method,
                        decoration: const InputDecoration(
                            labelText: 'Forma de pagamento *'),
                        items: const [
                          DropdownMenuItem(
                              value: 'cash', child: Text('Dinheiro')),
                          DropdownMenuItem(value: 'pix', child: Text('PIX')),
                          DropdownMenuItem(
                              value: 'debit_card',
                              child: Text('Cartao de debito')),
                          DropdownMenuItem(
                              value: 'credit_card',
                              child: Text('Cartao de credito')),
                          DropdownMenuItem(value: 'other', child: Text('Outro'))
                        ],
                        onChanged:
                            saving ? null : (v) => setState(() => method = v!)),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                        onPressed: saving
                            ? null
                            : () async {
                                final value = await showDatePicker(
                                    context: context,
                                    initialDate: paidAt,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2100));
                                if (value != null && mounted)
                                  setState(() => paidAt = value);
                              },
                        icon: const Icon(Icons.event_available),
                        label: Text(
                            'Recebido em ${DateFormat('dd/MM/yyyy').format(paidAt)}')),
                    const SizedBox(height: 12),
                    TextField(
                        controller: notes,
                        enabled: !saving,
                        maxLength: 500,
                        maxLines: 2,
                        decoration:
                            const InputDecoration(labelText: 'Observacao')),
                    if (error != null)
                      Text(error!,
                          style: const TextStyle(color: PremiumColors.error))
                  ]))),
          actions: [
            TextButton(
                onPressed:
                    saving ? null : () => Navigator.of(context).pop(false),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: saving ? null : save,
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Confirmar pagamento'))
          ]);
}

class _BulkPaymentFormDialog extends StatefulWidget {
  final FinancialController controller;
  final List<Map<String, dynamic>> receivables;
  final NumberFormat money;
  const _BulkPaymentFormDialog(
      {required this.controller,
      required this.receivables,
      required this.money});
  @override
  State<_BulkPaymentFormDialog> createState() => _BulkPaymentFormDialogState();
}

class _BulkPaymentFormDialogState extends State<_BulkPaymentFormDialog> {
  int? accountId;
  String method = 'pix';
  DateTime paidAt = DateTime.now();
  bool saving = false;
  String? error;
  List<Map<String, dynamic>> items(dynamic value) => value is List
      ? value.map((e) => Map<String, dynamic>.from(e)).toList()
      : [];
  int id(dynamic value) => int.tryParse('$value') ?? 0;
  double number(dynamic value) => double.tryParse('$value') ?? 0;
  String iso(DateTime value) => DateFormat('yyyy-MM-dd').format(value);
  double get total => widget.receivables
      .fold(0, (sum, e) => sum + number(e['outstanding_amount']));

  Future<void> save() async {
    if (accountId == null) {
      setState(() => error = 'Selecione a conta financeira.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    final failure = await widget.controller.registerPayments(
      widget.receivables
          .map((e) => {
                'appointment_id': id(e['appointment_id']),
                'amount': number(e['outstanding_amount']).toStringAsFixed(2)
              })
          .toList(),
      {
        'account_id': accountId,
        'method': method,
        'paid_at': iso(paidAt),
        'notes': 'Baixa em lote'
      },
    );
    if (!mounted) return;
    if (failure == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        saving = false;
        error = failure;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Dar baixa em lote'),
        content: SizedBox(
            width: 470,
            child: SingleChildScrollView(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      '${widget.receivables.length} atendimento(s) selecionado(s).'),
                  const SizedBox(height: 6),
                  Text('Total: ${widget.money.format(total)}',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                      value: accountId,
                      decoration: const InputDecoration(
                          labelText: 'Conta financeira *'),
                      items: items(widget.controller.metadata['accounts'])
                          .map((e) => DropdownMenuItem(
                              value: id(e['id']), child: Text('${e['name']}')))
                          .toList(),
                      onChanged:
                          saving ? null : (v) => setState(() => accountId = v)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                      value: method,
                      decoration: const InputDecoration(
                          labelText: 'Forma de pagamento *'),
                      items: const [
                        DropdownMenuItem(
                            value: 'cash', child: Text('Dinheiro')),
                        DropdownMenuItem(value: 'pix', child: Text('PIX')),
                        DropdownMenuItem(
                            value: 'debit_card',
                            child: Text('Cartao de debito')),
                        DropdownMenuItem(
                            value: 'credit_card',
                            child: Text('Cartao de credito')),
                        DropdownMenuItem(value: 'other', child: Text('Outro'))
                      ],
                      onChanged:
                          saving ? null : (v) => setState(() => method = v!)),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                      onPressed: saving
                          ? null
                          : () async {
                              final value = await showDatePicker(
                                  context: context,
                                  initialDate: paidAt,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100));
                              if (value != null && mounted)
                                setState(() => paidAt = value);
                            },
                      icon: const Icon(Icons.event_available),
                      label: Text(
                          'Recebido em ${DateFormat('dd/MM/yyyy').format(paidAt)}')),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(error!,
                        style: const TextStyle(color: PremiumColors.error))
                  ],
                ]))),
        actions: [
          TextButton(
              onPressed: saving ? null : () => Navigator.of(context).pop(false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: saving ? null : save,
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Confirmar baixa'))
        ],
      );
}

class _Kpi extends StatelessWidget {
  final String label, value, hint;
  final IconData icon;
  final Color color;
  const _Kpi(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color,
      required this.hint});
  @override
  Widget build(BuildContext context) => Tooltip(
      message: hint,
      child: PremiumSurface(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 96),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(11)),
                    child: Icon(icon, color: color)),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                child: Text(label,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: PremiumColors.textSecondary,
                                        fontSize: 12))),
                            const SizedBox(width: 5),
                            const Icon(Icons.info_outline,
                                size: 13, color: PremiumColors.textMuted)
                          ]),
                      const SizedBox(height: 5),
                      FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(value,
                              style: const TextStyle(
                                  fontSize: 21, fontWeight: FontWeight.w800)))
                    ]))
              ]))));
}

class _PeriodButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PeriodButton(
      {required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
          backgroundColor:
              selected ? PremiumColors.gold.withValues(alpha: .08) : null,
          side: BorderSide(
              color: selected ? PremiumColors.gold : PremiumColors.border),
          foregroundColor:
              selected ? PremiumColors.gold : PremiumColors.textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17)),
      child: Text(label,
          style: TextStyle(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500)));
}

class _FinancialChart extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final NumberFormat money;
  const _FinancialChart({required this.rows, required this.money});
  double _value(dynamic value) => double.tryParse('$value') ?? 0;
  @override
  Widget build(BuildContext context) {
    final income = <FlSpot>[], expense = <FlSpot>[];
    for (var i = 0; i < rows.length; i++) {
      income.add(FlSpot(i.toDouble(), _value(rows[i]['income'])));
      expense.add(FlSpot(i.toDouble(), _value(rows[i]['expense'])));
    }
    final all = [...income.map((e) => e.y), ...expense.map((e) => e.y)];
    final maxY = all.isEmpty ? 100.0 : all.reduce((a, b) => a > b ? a : b);
    final ceiling = maxY <= 0 ? 100.0 : maxY * 1.2;
    return PremiumSurface(
        child: SizedBox(
            height: 250,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(
                    child: Text('Evolucao financeira',
                        style: TextStyle(fontWeight: FontWeight.w700))),
                _Legend(color: PremiumColors.success, label: 'Entradas'),
                const SizedBox(width: 12),
                _Legend(color: PremiumColors.error, label: 'Despesas')
              ]),
              const SizedBox(height: 18),
              Expanded(
                  child: rows.isEmpty
                      ? const Center(
                          child: Text('Nenhuma movimentacao no periodo.',
                              style: TextStyle(color: PremiumColors.textMuted)))
                      : LineChart(LineChartData(
                          minY: 0,
                          maxY: ceiling,
                          gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: ceiling / 4,
                              getDrawingHorizontalLine: (_) => const FlLine(
                                  color: PremiumColors.border, strokeWidth: 1)),
                          borderData: FlBorderData(
                              show: true,
                              border: const Border(
                                  bottom:
                                      BorderSide(color: PremiumColors.border),
                                  left:
                                      BorderSide(color: PremiumColors.border))),
                          titlesData: FlTitlesData(
                              topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 48,
                                      interval: ceiling / 4,
                                      getTitlesWidget: (v, _) => Text(
                                          v >= 1000
                                              ? 'R\$ ${(v / 1000).toStringAsFixed(0)}k'
                                              : money.format(v),
                                          style: const TextStyle(
                                              fontSize: 9,
                                              color:
                                                  PremiumColors.textMuted)))),
                              bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 25,
                                      interval: rows.length > 8
                                          ? (rows.length / 5).ceilToDouble()
                                          : 1,
                                      getTitlesWidget: (v, _) {
                                        final i = v.toInt();
                                        if (i < 0 || i >= rows.length)
                                          return const SizedBox();
                                        final date = DateTime.tryParse(
                                            '${rows[i]['date']}');
                                        return Text(
                                            date == null
                                                ? ''
                                                : DateFormat('dd/MM')
                                                    .format(date),
                                            style: const TextStyle(
                                                fontSize: 9,
                                                color:
                                                    PremiumColors.textMuted));
                                      }))),
                          lineBarsData: [
                              LineChartBarData(
                                  spots: income,
                                  isCurved: true,
                                  color: PremiumColors.success,
                                  barWidth: 2,
                                  dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                      show: true,
                                      color: PremiumColors.success
                                          .withValues(alpha: .08))),
                              LineChartBarData(
                                  spots: expense,
                                  isCurved: true,
                                  color: PremiumColors.error,
                                  barWidth: 2,
                                  dotData: const FlDotData(show: false))
                            ]))),
            ])));
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(width: 14, height: 2, color: color),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                fontSize: 10, color: PremiumColors.textSecondary))
      ]);
}

String _ruleLifecycle(Map<String, dynamic> rule) {
  final now = DateTime.now();
  final from = DateTime.tryParse('${rule['valid_from']}');
  final until = DateTime.tryParse('${rule['valid_until']}');
  if (rule['active'] != true && rule['active'] != 1) return 'Encerrada';
  if (from != null && now.isBefore(from)) return 'Agendada';
  if (until != null && !now.isBefore(until)) return 'Encerrada';
  return 'Ativa';
}

String _ruleValidityLabel(Map<String, dynamic> rule) {
  final from = rule['valid_from']?.toString().split(' ').first ?? 'sem início';
  final until = rule['valid_until']?.toString().split(' ').first;
  return until == null || until.isEmpty
      ? 'a partir de $from'
      : '$from até $until';
}

Widget _statusChip(String status) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
          color: status == 'Ativa'
              ? PremiumColors.success.withValues(alpha: .12)
              : PremiumColors.gold.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: PremiumColors.border)),
      child: Text(status,
          style: TextStyle(
              color: status == 'Ativa'
                  ? PremiumColors.success
                  : PremiumColors.gold,
              fontSize: 11,
              fontWeight: FontWeight.w700)),
    );
