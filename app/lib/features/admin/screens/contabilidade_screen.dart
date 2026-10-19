import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/services/api_service.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/premium_ui.dart';
import '../controllers/admin_controller.dart';
import '../controllers/financial_controller.dart';
import 'financeiro_screen.dart';

class ContabilidadeScreen extends StatefulWidget {
  const ContabilidadeScreen({super.key});

  @override
  State<ContabilidadeScreen> createState() => _ContabilidadeScreenState();
}

class _ContabilidadeScreenState extends State<ContabilidadeScreen> {
  final _money = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  bool _loadingTaxes = true;
  String? _taxError;
  List<Map<String, dynamic>> _taxes = [];

  static const _taxLabels = <String, String>{
    'das_simples_nacional': 'DAS - Simples Nacional',
    'das_mei': 'DAS-MEI',
    'iss_municipal': 'ISS municipal',
    'inss_cpp_folha': 'INSS / CPP / folha',
    'icms_mercadorias': 'ICMS sobre mercadorias',
    'taxas_licencas_municipais': 'Taxas e licencas municipais',
    'outro': 'Outro tributo ou encargo',
  };

  static const _regimeLabels = <String, String>{
    'nao_informado': 'Nao informado',
    'simples_nacional': 'Simples Nacional',
    'mei': 'MEI',
    'lucro_presumido': 'Lucro Presumido',
    'lucro_real': 'Lucro Real',
    'outro': 'Outro enquadramento',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  String _date(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  Future<void> _load() async {
    final financial = context.read<FinancialController>();
    final admin = context.read<AdminController>();
    setState(() {
      _loadingTaxes = true;
      _taxError = null;
    });
    if (financial.metadata.isEmpty || financial.dashboard.isEmpty) {
      await financial.initialize();
    }
    if (financial.area != FinancialArea.overview) {
      await financial.setArea(FinancialArea.overview);
    }
    if (admin.servicos.isEmpty) {
      await admin.carregarServicos();
    }
    final response = await ApiService.get(
      '/accounting/taxes?from=${_date(financial.from)}&to=${_date(financial.to)}',
    );
    if (!mounted) return;
    setState(() {
      _taxError = response['erro']?.toString();
      _taxes = response['data'] is List
          ? (response['data'] as List)
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : [];
      _loadingTaxes = false;
    });
  }

  Future<void> _openTaxForm() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _TaxFormDialog(
        initialDate: context.read<FinancialController>().to,
        taxLabels: _taxLabels,
        regimeLabels: _regimeLabels,
        services: context.read<AdminController>().servicos,
      ),
    );
    if (saved == true && mounted) {
      await _load();
      if (!mounted) return;
      AppToast.show(context, 'Imposto adicionado a contabilidade.',
          type: AppToastType.success);
    }
  }

  Future<void> _deleteTax(Map<String, dynamic> tax) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remover lancamento?'),
        content:
            const Text('O valor deixara de compor o resultado do periodo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final response = await ApiService.delete('/accounting/taxes/${tax['id']}');
    if (!mounted) return;
    if (response['erro'] != null) {
      AppToast.show(context, response['erro'].toString(),
          type: AppToastType.error);
      return;
    }
    await _load();
  }

  double _number(dynamic value) => double.tryParse('$value') ?? 0;

  @override
  Widget build(BuildContext context) {
    final financial = context.watch<FinancialController>();
    final dashboard = financial.dashboard;
    final sales = _number(dashboard['received']);
    final expenses = _number(dashboard['expenses']);
    final taxes =
        _taxes.fold<double>(0, (sum, item) => sum + _number(item['amount']));
    final result = sales - taxes - expenses;
    return PremiumPage(
      title: 'Contabilidade',
      subtitle:
          'Visao gerencial para acompanhar vendas, impostos, despesas e resultado.',
      headingFontSize: 27,
      horizontalPadding: 40,
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 32),
      actions: [
        IconButton(
          tooltip: 'Atualizar',
          onPressed: financial.loading || _loadingTaxes ? null : _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
        FilledButton.icon(
          onPressed: _openTaxForm,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Cadastrar imposto'),
        ),
      ],
      child: financial.loading || _loadingTaxes
          ? const PremiumLoadingState(label: 'Carregando contabilidade')
          : financial.error != null
              ? PremiumEmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Nao foi possivel carregar',
                  subtitle: financial.error!,
                )
              : _taxError != null
                  ? PremiumEmptyState(
                      icon: Icons.cloud_off_outlined,
                      title: 'Nao foi possivel carregar impostos',
                      subtitle: _taxError!,
                    )
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _periodLabel(financial),
                          const SizedBox(height: 12),
                          _formulaCards(sales, taxes, expenses, result),
                          const SizedBox(height: 12),
                          FinancialChart(
                            rows: _items(dashboard['evolution']),
                            money: _money,
                          ),
                          const SizedBox(height: 12),
                          _taxSection(),
                          const SizedBox(height: 12),
                          _disclaimer(),
                        ],
                      ),
                    ),
    );
  }

  Widget _periodLabel(FinancialController financial) => PremiumSurface(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_outlined,
                size: 18, color: PremiumColors.gold),
            const SizedBox(width: 8),
            Text(
              'Periodo: ${DateFormat('dd/MM/yyyy').format(financial.from)} a ${DateFormat('dd/MM/yyyy').format(financial.to)}',
              style: const TextStyle(color: PremiumColors.textSecondary),
            ),
          ],
        ),
      );

  Widget _formulaCards(
          double sales, double taxes, double expenses, double result) =>
      LayoutBuilder(
        builder: (_, constraints) {
          final columns = constraints.maxWidth >= 980
              ? 4
              : constraints.maxWidth >= 620
                  ? 2
                  : 1;
          final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
          final cards = [
            ('Vendas', sales, Icons.trending_up_rounded, PremiumColors.success),
            (
              'Impostos',
              taxes,
              Icons.receipt_long_outlined,
              PremiumColors.gold
            ),
            (
              'Despesas',
              expenses,
              Icons.trending_down_rounded,
              PremiumColors.error
            ),
            (
              'Lucro / prejuizo',
              result,
              Icons.account_balance_outlined,
              result >= 0 ? PremiumColors.success : PremiumColors.error
            ),
          ];
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: cards
                .map((card) => SizedBox(
                      width: width,
                      child: PremiumSurface(
                        child: Row(
                          children: [
                            Icon(card.$3, color: card.$4),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(card.$1,
                                      style: const TextStyle(
                                          color: PremiumColors.textSecondary)),
                                  const SizedBox(height: 4),
                                  Text(_money.format(card.$2),
                                      style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ))
                .toList(),
          );
        },
      );

  String _taxRuleSummary(Map<String, dynamic> tax) {
    final value = _number(tax['value']);
    final services = tax['service_names'] is List
        ? (tax['service_names'] as List).map((item) => '$item').toList()
        : <String>[];
    final scope = services.isEmpty ? 'todos os servicos' : services.join(', ');
    if (tax['calculation_type'] == 'percentage') {
      return '${value.toStringAsFixed(2).replaceAll('.', ',')}% sobre $scope';
    }
    return services.isEmpty
        ? '${_money.format(value)} no periodo'
        : '${_money.format(value)} por atendimento · $scope';
  }

  Widget _taxSection() => PremiumSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Impostos cadastrados',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                Text('${_taxes.length} lancamento(s)',
                    style: const TextStyle(
                        color: PremiumColors.textMuted, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 10),
            if (_taxes.isEmpty)
              const Text(
                'Nenhum imposto informado no periodo. O preenchimento e opcional e manual.',
                style: TextStyle(color: PremiumColors.textMuted),
              )
            else
              ..._taxes.map(
                (tax) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.receipt_long_outlined,
                      color: PremiumColors.gold),
                  title: Text(
                      _taxLabels[tax['type']] ?? 'Outro tributo ou encargo'),
                  subtitle: Text(
                      '${_regimeLabels[tax['regime']] ?? 'Nao informado'} · ${tax['competence_date']}\n${_taxRuleSummary(tax)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_money.format(_number(tax['amount']))),
                      IconButton(
                        tooltip: 'Remover',
                        onPressed: () => _deleteTax(tax),
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: PremiumColors.error),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _disclaimer() => const PremiumSurface(
        color: PremiumColors.surfaceSecondary,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, color: PremiumColors.gold),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Este painel e gerencial. Os vinculos calculam estimativas sobre as vendas registradas; confirme o enquadramento e a obrigacao com um contador e com o municipio responsavel.',
                style:
                    TextStyle(color: PremiumColors.textSecondary, height: 1.4),
              ),
            ),
          ],
        ),
      );

  List<Map<String, dynamic>> _items(dynamic value) => value is List
      ? value.map((item) => Map<String, dynamic>.from(item)).toList()
      : <Map<String, dynamic>>[];
}

class _TaxFormDialog extends StatefulWidget {
  final DateTime initialDate;
  final Map<String, String> taxLabels;
  final Map<String, String> regimeLabels;
  final List<Map<String, dynamic>> services;

  const _TaxFormDialog(
      {required this.initialDate,
      required this.taxLabels,
      required this.regimeLabels,
      required this.services});

  @override
  State<_TaxFormDialog> createState() => _TaxFormDialogState();
}

class _TaxFormDialogState extends State<_TaxFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String _type = 'das_simples_nacional';
  String _regime = 'nao_informado';
  String _calculationType = 'percentage';
  final Set<int> _selectedServiceIds = <int>{};
  late DateTime _date;
  bool _saving = false;

  double? _parseAmount(String value) {
    final normalized = value.trim().replaceAll(' ', '');
    if (normalized.contains(',')) {
      return double.tryParse(
          normalized.replaceAll('.', '').replaceAll(',', '.'));
    }
    return double.tryParse(normalized);
  }

  @override
  void initState() {
    super.initState();
    _date = DateTime(widget.initialDate.year, widget.initialDate.month, 1);
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final rawAmount = _parseAmount(_amount.text);
    final response = await ApiService.post('/accounting/taxes', {
      'type': _type,
      'regime': _regime,
      'calculation_type': _calculationType,
      'value': rawAmount,
      'service_ids': _selectedServiceIds.toList(),
      'competence_date': DateFormat('yyyy-MM-dd').format(_date),
      'note': _note.text.trim(),
    });
    if (!mounted) return;
    if (response['erro'] != null) {
      setState(() => _saving = false);
      AppToast.show(context, response['erro'].toString(),
          type: AppToastType.error);
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Cadastrar imposto'),
        content: SizedBox(
          width: 480,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _type,
                    decoration:
                        const InputDecoration(labelText: 'Tipo de tributo *'),
                    items: widget.taxLabels.entries
                        .map((entry) => DropdownMenuItem(
                            value: entry.key, child: Text(entry.value)))
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _type = value ?? _type),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _regime,
                    decoration: const InputDecoration(
                        labelText: 'Enquadramento, se souber'),
                    items: widget.regimeLabels.entries
                        .map((entry) => DropdownMenuItem(
                            value: entry.key, child: Text(entry.value)))
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _regime = value ?? _regime),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _calculationType,
                    decoration:
                        const InputDecoration(labelText: 'Forma de calculo *'),
                    items: const [
                      DropdownMenuItem(
                          value: 'percentage', child: Text('Percentual (%)')),
                      DropdownMenuItem(
                          value: 'fixed', child: Text('Valor fixo (R\$)')),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) => setState(
                            () => _calculationType = value ?? _calculationType),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _amount,
                    enabled: !_saving,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: _calculationType == 'percentage'
                          ? 'Percentual do imposto *'
                          : _selectedServiceIds.isEmpty
                              ? 'Valor fixo do periodo *'
                              : 'Valor por atendimento *',
                      suffixText:
                          _calculationType == 'percentage' ? '%' : 'R\$',
                    ),
                    validator: (value) {
                      final amount = _parseAmount(value ?? '');
                      if (amount == null || amount <= 0) {
                        return 'Informe um valor maior que zero.';
                      }
                      if (_calculationType == 'percentage' && amount > 100) {
                        return 'O percentual deve ser menor ou igual a 100.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Vincular aos servicos (opcional)',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _calculationType == 'percentage'
                        ? 'O percentual sera aplicado sobre as vendas dos servicos selecionados.'
                        : _selectedServiceIds.isEmpty
                            ? 'Sem vinculo, o valor sera lancado uma vez no periodo.'
                            : 'Com vinculo, o valor sera aplicado a cada atendimento desses servicos.',
                    style: const TextStyle(
                        color: PremiumColors.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  if (widget.services.isEmpty)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Nenhum servico ativo cadastrado.'),
                    )
                  else
                    Container(
                      constraints: const BoxConstraints(maxHeight: 180),
                      decoration: BoxDecoration(
                        border: Border.all(color: PremiumColors.border),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListView(
                        shrinkWrap: true,
                        children: widget.services.map((service) {
                          final id = int.tryParse('${service['id']}');
                          if (id == null) return const SizedBox.shrink();
                          return CheckboxListTile(
                            dense: true,
                            value: _selectedServiceIds.contains(id),
                            title:
                                Text(service['nome']?.toString() ?? 'Servico'),
                            subtitle: Text('R\$ ${service["preco"] ?? "0,00"}'),
                            onChanged: _saving
                                ? null
                                : (selected) => setState(() {
                                      if (selected == true) {
                                        _selectedServiceIds.add(id);
                                      } else {
                                        _selectedServiceIds.remove(id);
                                      }
                                    }),
                          );
                        }).toList(),
                      ),
                    ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                        'Competencia: ${DateFormat('MM/yyyy').format(_date)}'),
                    trailing: IconButton(
                      tooltip: 'Escolher competencia',
                      onPressed: _saving
                          ? null
                          : () async {
                              final picked = await showDatePicker(
                                  context: context,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100),
                                  initialDate: _date);
                              if (picked != null) {
                                setState(() => _date =
                                    DateTime(picked.year, picked.month, 1));
                              }
                            },
                      icon: const Icon(Icons.calendar_month_outlined),
                    ),
                  ),
                  TextFormField(
                    controller: _note,
                    enabled: !_saving,
                    maxLength: 240,
                    maxLines: 2,
                    decoration: const InputDecoration(
                        labelText: 'Observacao (opcional)'),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Use o valor da guia ou apuracao ja conferida. Este cadastro nao substitui a orientacao contabil.',
                    style:
                        TextStyle(color: PremiumColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Salvando...' : 'Salvar')),
        ],
      );
}
