import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/api_service.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/premium_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FinanceiroScreen extends StatefulWidget {
  const FinanceiroScreen({super.key});

  @override
  State<FinanceiroScreen> createState() => _FinanceiroScreenState();
}

class _FinanceiroScreenState extends State<FinanceiroScreen> {
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _entries = [];
  bool _loading = true;
  int? _barbeariaId;

  final _currency =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    _barbeariaId = prefs.getInt(AppConstants.keyBarbeariaId);
    if (_barbeariaId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final results = await Future.wait([
      ApiService.get('/finance/$_barbeariaId/summary'),
      ApiService.get('/finance/$_barbeariaId/entries?limit=50'),
    ]);
    if (!mounted) return;
    setState(() {
      _summary = results[0]['data'] is Map
          ? Map<String, dynamic>.from(results[0]['data'])
          : {};
      final raw = results[1]['data'];
      _entries = raw is List
          ? raw.map((item) => Map<String, dynamic>.from(item)).toList()
          : [];
      _loading = false;
    });
  }

  Future<void> _addExpense() async {
    final categoryController = TextEditingController();
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Registrar despesa'),
        content: SizedBox(
          width: 430,
          child: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: categoryController,
                decoration: const InputDecoration(
                    labelText: 'Categoria',
                    prefixIcon: Icon(Icons.category_outlined)),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Informe a categoria.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Valor', prefixText: 'R\$ '),
                validator: (value) {
                  final amount = double.tryParse(
                      (value ?? '').replaceAll('.', '').replaceAll(',', '.'));
                  return amount == null || amount <= 0
                      ? 'Informe um valor válido.'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: descriptionController,
                maxLines: 2,
                decoration:
                    const InputDecoration(labelText: 'Descrição (opcional)'),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Registrar')),
        ],
      ),
    );
    final category = categoryController.text.trim();
    final description = descriptionController.text.trim();
    final amountText = amountController.text;
    categoryController.dispose();
    descriptionController.dispose();
    amountController.dispose();
    if (confirmed != true || _barbeariaId == null) return;
    final amount =
        double.parse(amountText.replaceAll('.', '').replaceAll(',', '.'));
    final result = await ApiService.post(
      '/finance/$_barbeariaId/expenses',
      {
        'category': category,
        'description': description,
        'amount': amount,
        'occurred_at': DateTime.now().toIso8601String(),
      },
    );
    if (!mounted) return;
    if (result.containsKey('erro')) {
      AppToast.show(context, result['erro'], type: AppToastType.error);
      return;
    }
    AppToast.show(context, 'Despesa registrada com sucesso.');
    await _load();
  }

  @override
  Widget build(BuildContext context) => PremiumPage(
        title: 'Financeiro',
        subtitle: 'Acompanhe entradas, despesas e o saldo do período.',
        actions: [
          IconButton(
              tooltip: 'Atualizar',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded)),
          FilledButton.icon(
              onPressed: _barbeariaId == null ? null : _addExpense,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Nova despesa')),
        ],
        child: _loading
            ? const PremiumLoadingState(label: 'Carregando financeiro')
            : _barbeariaId == null
                ? const PremiumEmptyState(
                    icon: Icons.store_mall_directory_outlined,
                    title: 'Barbearia não identificada',
                    subtitle: 'Entre novamente para atualizar sua sessão.')
                : Column(children: [
                    _summaryCards(),
                    const SizedBox(height: 18),
                    Expanded(child: _entriesList()),
                  ]),
      );

  Widget _summaryCards() => LayoutBuilder(builder: (context, constraints) {
        final cards = [
          _FinanceCard('Entradas', _summary['income'],
              Icons.trending_up_rounded, PremiumColors.success, _currency),
          _FinanceCard('Despesas', _summary['expenses'],
              Icons.trending_down_rounded, PremiumColors.error, _currency),
          _FinanceCard(
              'Saldo',
              _summary['balance'],
              Icons.account_balance_wallet_outlined,
              PremiumColors.gold,
              _currency),
        ];
        if (constraints.maxWidth < 680) {
          return Column(children: [
            for (final card in cards) ...[card, const SizedBox(height: 10)]
          ]);
        }
        return Row(children: [
          for (var index = 0; index < cards.length; index++) ...[
            Expanded(child: cards[index]),
            if (index < cards.length - 1) const SizedBox(width: 12),
          ]
        ]);
      });

  Widget _entriesList() => PremiumSurface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Movimentações recentes',
              style: GoogleFonts.inter(
                  color: PremiumColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          Expanded(
            child: _entries.isEmpty
                ? const PremiumEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Nenhuma movimentação',
                    subtitle: 'As entradas e despesas aparecerão aqui.')
                : ListView.separated(
                    itemCount: _entries.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final item = _entries[index];
                      final expense = item['tipo'] != 'income';
                      final date = DateTime.tryParse(
                          item['ocorrido_em']?.toString() ?? '');
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: (expense
                                  ? PremiumColors.error
                                  : PremiumColors.success)
                              .withValues(alpha: .1),
                          child: Icon(
                              expense
                                  ? Icons.arrow_downward_rounded
                                  : Icons.arrow_upward_rounded,
                              color: expense
                                  ? PremiumColors.error
                                  : PremiumColors.success,
                              size: 18),
                        ),
                        title: Text(item['categoria'] ?? 'Movimentação'),
                        subtitle: Text(date == null
                            ? (item['descricao'] ?? '')
                            : '${DateFormat('dd/MM/yyyy').format(date)} · ${item['descricao'] ?? ''}'),
                        trailing: Text(
                            '${expense ? '-' : '+'} ${_currency.format(double.tryParse(item['valor'].toString()) ?? 0)}',
                            style: TextStyle(
                                color: expense
                                    ? PremiumColors.error
                                    : PremiumColors.success,
                                fontWeight: FontWeight.w700)),
                      );
                    },
                  ),
          ),
        ]),
      );
}

class _FinanceCard extends StatelessWidget {
  final String label;
  final dynamic amount;
  final IconData icon;
  final Color color;
  final NumberFormat format;
  const _FinanceCard(
      this.label, this.amount, this.icon, this.color, this.format);

  @override
  Widget build(BuildContext context) => PremiumSurface(
        padding: const EdgeInsets.all(17),
        child: Row(children: [
          Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: GoogleFonts.inter(
                        color: PremiumColors.textMuted, fontSize: 11)),
                Text(format.format(double.tryParse(amount.toString()) ?? 0),
                    style: GoogleFonts.inter(
                        color: PremiumColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
              ])),
        ]),
      );
}
