import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/premium_ui.dart';
import '../controllers/admin_controller.dart';
import '../controllers/financial_controller.dart';

class CommissionRuleWizardScreen extends StatefulWidget {
  final int? draftId;

  const CommissionRuleWizardScreen({super.key, this.draftId});

  @override
  State<CommissionRuleWizardScreen> createState() =>
      _CommissionRuleWizardScreenState();
}

class _CommissionRuleWizardScreenState
    extends State<CommissionRuleWizardScreen> {
  final _name = TextEditingController(text: 'Equipe padrão');
  final _rate = TextEditingController(text: '40');
  final _productRate = TextEditingController(text: '10');
  final _fixedValue = TextEditingController(text: '8,00');
  final _date = TextEditingController(
      text: DateFormat('dd/MM/yyyy').format(DateTime.now()));
  final _simulationGross = TextEditingController(text: '100,00');
  final _simulationDiscount = TextEditingController(text: '10,00');
  final _simulationReceived = TextEditingController(text: '100,00');
  Timer? _draftTimer;
  int _step = 0;
  int? _draftId;
  int? _sourceRuleId;
  int _revision = 1;
  bool _savingDraft = false;
  bool _productsEnabled = false;
  bool _allProfessionals = true;
  bool _allServices = true;
  bool _percentage = true;
  bool _afterDiscounts = true;
  bool _proportionalReceipt = true;
  bool _requiresFulfillment = true;
  bool _goalsEnabled = false;
  String _frequency = 'MONTHLY';
  String _goalMethod = 'MARGINAL';
  String? _message;
  String? _error;
  List<Map<String, dynamic>> _exceptions = [];
  final Set<int> _selectedProfessionalIds = <int>{};
  final Set<int> _selectedServiceIds = <int>{};
  Map<String, dynamic>? _simulation;
  bool _simulationLoading = false;

  FinancialController get _controller => context.read<FinancialController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final catalog = context.read<AdminController>();
      if (catalog.colaboradores.isEmpty) await catalog.carregarColaboradores();
      if (catalog.servicos.isEmpty) await catalog.carregarServicos();
      await _restoreDraft();
    });
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _name.dispose();
    _rate.dispose();
    _productRate.dispose();
    _fixedValue.dispose();
    _date.dispose();
    _simulationGross.dispose();
    _simulationDiscount.dispose();
    _simulationReceived.dispose();
    super.dispose();
  }

  Map<String, dynamic> _payload() => {
        'name': _name.text.trim(),
        'revision': _revision,
        if (_sourceRuleId != null) 'sourceRuleId': _sourceRuleId,
        'professionals': {
          'mode': _allProfessionals ? 'ALL' : 'SELECTED',
          'ids': _selectedProfessionalIds.toList()..sort(),
        },
        'services': {
          'enabled': true,
          'scope': {
            'mode': _allServices ? 'ALL' : 'SELECTED',
            'ids': _selectedServiceIds.toList()..sort()
          },
          'calculation': {
            'model': _percentage ? 'PERCENTAGE' : 'FIXED_PER_UNIT',
            'rate': _rate.text.trim().replaceAll(',', '.'),
            'fixedValue': _fixedValue.text.trim().replaceAll(',', '.'),
            'basis': _afterDiscounts ? 'AFTER_DISCOUNTS' : 'GROSS',
          },
        },
        'products': {
          'enabled': _productsEnabled,
          'scope': {'mode': 'ALL', 'ids': <int>[]},
          'calculation': {
            'model': 'PERCENTAGE',
            'rate': _productRate.text.trim().replaceAll(',', '.'),
            'basis': 'AFTER_DISCOUNTS',
          },
        },
        'exceptions': _exceptions,
        'validity': {
          'startsOn': _parseDate(_date.text),
          'endsOn': null,
          'timezone': 'America/Sao_Paulo',
        },
        'release': {
          'requiresFulfillment': _requiresFulfillment,
          'receipt': _proportionalReceipt ? 'PROPORTIONAL' : 'FULL',
        },
        'settlementSchedule': {'kind': _frequency, 'day': 'LAST_DAY'},
        'goalPlan': _goalsEnabled
            ? {
                'metric': 'NET_SERVICE_REVENUE',
                'period': 'MONTH',
                'per': 'PROFESSIONAL',
                'excludeExceptions': true,
                'excludeProducts': true,
                'method': _goalMethod,
                'bands': [
                  {
                    'fromCents': '0',
                    'toCents': '500000',
                    'rateBps': 4000,
                  },
                  {
                    'fromCents': '500000',
                    'toCents': null,
                    'rateBps': 4500,
                  },
                ],
              }
            : null,
      };

  String _parseDate(String value) {
    final parts = value.split('/');
    if (parts.length != 3) return DateTime.now().toIso8601String();
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) {
      return DateTime.now().toIso8601String();
    }
    return DateTime(year, month, day).toIso8601String();
  }

  Future<void> _restoreDraft() async {
    final draft = await _controller.getCommissionDraft(widget.draftId);
    if (!mounted || draft == null || draft['payload'] is! Map) return;
    final payload = Map<String, dynamic>.from(draft['payload'] as Map);
    final services = payload['services'] is Map
        ? Map<String, dynamic>.from(payload['services'] as Map)
        : <String, dynamic>{};
    final calculation = services['calculation'] is Map
        ? Map<String, dynamic>.from(services['calculation'] as Map)
        : <String, dynamic>{};
    final products = payload['products'] is Map
        ? Map<String, dynamic>.from(payload['products'] as Map)
        : <String, dynamic>{};
    final release = payload['release'] is Map
        ? Map<String, dynamic>.from(payload['release'] as Map)
        : <String, dynamic>{};
    final validity = payload['validity'] is Map
        ? Map<String, dynamic>.from(payload['validity'] as Map)
        : <String, dynamic>{};
    setState(() {
      _draftId = int.tryParse('${draft['id']}');
      _sourceRuleId = int.tryParse(
          '${payload['sourceRuleId'] ?? draft['sourceRuleId'] ?? ''}');
      _revision = int.tryParse('${draft['revision']}') ?? 1;
      _name.text = '${payload['name'] ?? _name.text}';
      _allProfessionals = payload['professionals'] is! Map ||
          '${(payload['professionals'] as Map)['mode'] ?? 'ALL'}' == 'ALL';
      _allServices = '${services['scope']?['mode'] ?? 'ALL'}' == 'ALL';
      _selectedProfessionalIds
        ..clear()
        ..addAll(_idsFrom(payload['professionals']));
      _selectedServiceIds
        ..clear()
        ..addAll(_idsFrom(services['scope']));
      _percentage =
          '${calculation['model'] ?? 'PERCENTAGE'}' != 'FIXED_PER_UNIT';
      _afterDiscounts =
          '${calculation['basis'] ?? 'AFTER_DISCOUNTS'}' != 'GROSS';
      _productsEnabled = false;
      _proportionalReceipt =
          '${release['receipt'] ?? 'PROPORTIONAL'}' == 'PROPORTIONAL';
      _requiresFulfillment = release['requiresFulfillment'] != false;
      _goalsEnabled = payload['goalPlan'] is Map;
      _exceptions = (payload['exceptions'] is List)
          ? (payload['exceptions'] as List)
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList()
          : [];
      _date.text = _formatStoredDate(validity['startsOn']);
      if (calculation['rate'] != null) _rate.text = '${calculation['rate']}';
      if (calculation['fixedValue'] != null) {
        _fixedValue.text = '${calculation['fixedValue']}';
      }
      if (products['calculation'] is Map &&
          (products['calculation'] as Map)['rate'] != null) {
        _productRate.text = '${(products['calculation'] as Map)['rate']}';
      }
    });
  }

  String _formatStoredDate(dynamic value) {
    final parsed = DateTime.tryParse('$value');
    return parsed == null
        ? _date.text
        : DateFormat('dd/MM/yyyy').format(parsed);
  }

  Set<int> _idsFrom(dynamic value) {
    if (value is! Map || value['ids'] is! List) return <int>{};
    return (value['ids'] as List)
        .map((item) => int.tryParse('$item'))
        .whereType<int>()
        .where((item) => item > 0)
        .toSet();
  }

  void _scheduleDraftSave() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 650), _saveDraft);
  }

  Future<void> _saveDraft() async {
    if (_savingDraft || !mounted) return;
    setState(() {
      _savingDraft = true;
      _message = null;
    });
    final payload = _payload();
    Map<String, dynamic>? result;
    if (_draftId == null) {
      result = await _controller.createCommissionDraft(payload);
    } else {
      result = await _controller.updateCommissionDraft(
          _draftId!, _revision, payload);
    }
    if (!mounted) return;
    setState(() {
      _savingDraft = false;
      if (result == null) {
        _error = 'Não foi possível salvar o rascunho. Tente novamente.';
      } else {
        _draftId ??= int.tryParse('${result['id']}');
        _revision = int.tryParse('${result['revision']}') ?? _revision;
        _message = 'Rascunho salvo';
      }
    });
  }

  Future<void> _next() async {
    if (_step == 0 && _name.text.trim().length < 3) {
      setState(() =>
          _error = 'Informe um nome de regra com pelo menos 3 caracteres.');
      return;
    }
    if (_step == 0 && !_allProfessionals && _selectedProfessionalIds.isEmpty) {
      setState(() => _error = 'Selecione pelo menos um profissional.');
      return;
    }
    if (_step == 0 && !_allServices && _selectedServiceIds.isEmpty) {
      setState(() => _error = 'Selecione pelo menos um serviço.');
      return;
    }
    if (_step == 1 &&
        _percentage &&
        double.tryParse(_rate.text.replaceAll(',', '.')) == null) {
      setState(() => _error = 'Informe um percentual válido.');
      return;
    }
    setState(() {
      _error = null;
      _step = (_step + 1).clamp(0, 3);
    });
    await _saveDraft();
  }

  void _previous() {
    setState(() {
      _error = null;
      _step = (_step - 1).clamp(0, 3);
    });
  }

  Future<void> _publish() async {
    await _saveDraft();
    if (_draftId == null) return;
    setState(() {
      _savingDraft = true;
      _error = null;
    });
    final error = await _controller.publishCommissionDraft(_draftId!);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _savingDraft = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PremiumColors.background,
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          final compact = constraints.maxWidth < 980;
          return Column(children: [
            _header(compact),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(24, 8, 24, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 1540),
                    child: compact
                        ? Column(children: [
                            _steps(),
                            SizedBox(height: 16),
                            _content(),
                            SizedBox(height: 16),
                            _summary(),
                          ])
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(width: 210, child: _steps()),
                              SizedBox(width: 24),
                              Expanded(child: _content()),
                              SizedBox(width: 24),
                              SizedBox(width: 320, child: _summary()),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ]);
        }),
      ),
    );
  }

  Widget _header(bool compact) => Padding(
        padding: EdgeInsets.fromLTRB(24, 18, 24, 10),
        child: Row(children: [
          IconButton(
            tooltip: 'Sair sem publicar',
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.close, color: PremiumColors.textSecondary),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('02  —  Configuração guiada',
                    style: TextStyle(
                        color: PremiumColors.gold,
                        fontSize: compact ? 12 : 14,
                        fontWeight: FontWeight.w700)),
                SizedBox(height: 4),
                Text(
                    _step == 3
                        ? 'Confira antes de salvar'
                        : 'Configurar comissão',
                    style: TextStyle(
                        color: PremiumColors.textPrimary,
                        fontSize: compact ? 25 : 32,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          if (!compact)
            Text('Etapa ${_step + 1} de 4',
                style: TextStyle(color: PremiumColors.textSecondary)),
          SizedBox(width: 18),
          OutlinedButton(
            onPressed: _savingDraft ? null : () => Navigator.of(context).pop(),
            child: Text('Sair'),
          ),
        ]),
      );

  Widget _steps() => PremiumSurface(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _stepItem(0, 'Aplicação', 'Onde a regra será aplicada',
              Icons.groups_outlined),
          _stepItem(
              1, 'Cálculo', 'Defina como calcular', Icons.percent_outlined),
          _stepItem(2, 'Liberação', 'Quando ficará disponível',
              Icons.schedule_outlined),
          _stepItem(
              3, 'Revisão', 'Confira e finalize', Icons.fact_check_outlined),
        ]),
      );

  Widget _stepItem(int index, String title, String subtitle, IconData icon) {
    final active = index == _step;
    final done = index < _step;
    return InkWell(
      onTap: done ? () => setState(() => _step = index) : null,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active || done ? PremiumColors.gold : PremiumColors.card,
              shape: BoxShape.circle,
              border: Border.all(
                  color: active || done
                      ? PremiumColors.gold
                      : PremiumColors.border),
            ),
            child: done
                ? Icon(Icons.check, color: Colors.black, size: 20)
                : Text('${index + 1}',
                    style: TextStyle(
                        color:
                            active ? Colors.black : PremiumColors.textPrimary,
                        fontWeight: FontWeight.w800)),
          ),
          SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: TextStyle(
                      color: active
                          ? PremiumColors.gold
                          : PremiumColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800)),
              SizedBox(height: 3),
              Text(subtitle,
                  style: TextStyle(
                      color: PremiumColors.textSecondary, fontSize: 11)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _content() {
    final content = switch (_step) {
      0 => _applicationStep(),
      1 => _calculationStep(),
      2 => _releaseStep(),
      _ => _reviewStep(),
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_error != null) _banner(_error!, PremiumColors.error),
      if (_message != null) _banner(_message!, PremiumColors.success),
      content,
      SizedBox(height: 16),
      Row(children: [
        if (_step > 0)
          OutlinedButton.icon(
              onPressed: _savingDraft ? null : _previous,
              icon: Icon(Icons.arrow_back),
              label: Text('Anterior')),
        Spacer(),
        if (_step < 3)
          FilledButton.icon(
              onPressed: _savingDraft ? null : _next,
              icon: Icon(Icons.arrow_forward),
              label: Text('Próximo'))
        else
          FilledButton.icon(
              onPressed: _savingDraft ? null : _publish,
              icon: _savingDraft
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Icons.check),
              label: Text(_savingDraft ? 'Salvando...' : 'Salvar regra')),
      ]),
    ]);
  }

  Widget _selectionSummary(Set<int> ids, String label) => Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text(
            ids.isEmpty
                ? 'Nenhum ' + label + ' selecionado.'
                : ids.length.toString() +
                    ' ' +
                    label +
                    (ids.length == 1 ? ' selecionado' : 's selecionados'),
            style: TextStyle(color: PremiumColors.gold, fontSize: 12)),
      );

  Future<void> _selectProfessionals() async {
    final catalog = context.read<AdminController>();
    final selected = Set<int>.from(_selectedProfessionalIds);
    final result = await _selectCatalogItems(
        title: 'Selecionar profissionais',
        items: catalog.colaboradores,
        selected: selected);
    if (!mounted || result == null) return;
    setState(() {
      _selectedProfessionalIds
        ..clear()
        ..addAll(result);
      _error = result.isEmpty ? 'Selecione pelo menos um profissional.' : null;
    });
    _scheduleDraftSave();
  }

  Future<void> _selectServices() async {
    final catalog = context.read<AdminController>();
    final selected = Set<int>.from(_selectedServiceIds);
    final result = await _selectCatalogItems(
        title: 'Selecionar serviços',
        items: catalog.servicos,
        selected: selected);
    if (!mounted || result == null) return;
    setState(() {
      _selectedServiceIds
        ..clear()
        ..addAll(result);
      _error = result.isEmpty ? 'Selecione pelo menos um serviço.' : null;
    });
    _scheduleDraftSave();
  }

  Future<Set<int>?> _selectCatalogItems(
      {required String title,
      required List<Map<String, dynamic>> items,
      required Set<int> selected}) async {
    return showDialog<Set<int>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 440,
            child: items.isEmpty
                ? Text('Nenhum item ativo encontrado.')
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: items.map((item) {
                        final itemId = int.tryParse('${item['id']}');
                        if (itemId == null) return SizedBox.shrink();
                        return CheckboxListTile(
                          value: selected.contains(itemId),
                          activeColor: PremiumColors.gold,
                          title:
                              Text('${item['nome'] ?? item['name'] ?? 'Item'}'),
                          onChanged: (value) => setDialogState(() {
                            if (value == true) {
                              selected.add(itemId);
                            } else {
                              selected.remove(itemId);
                            }
                          }),
                        );
                      }).toList(),
                    ),
                  ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, selected),
                child: Text('Aplicar seleção')),
          ],
        ),
      ),
    );
  }

  Widget _applicationStep() => PremiumSurface(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _sectionTitle('Onde esta regra será aplicada?',
              'Defina o escopo da aplicação da regra de comissão.'),
          _label('Nome da regra'),
          TextField(
              controller: _name,
              onChanged: (_) => _scheduleDraftSave(),
              decoration: InputDecoration(hintText: 'Ex.: Equipe padrão')),
          SizedBox(height: 18),
          _label('Profissionais'),
          _choiceRow(
              selected: _allProfessionals,
              icon: Icons.groups_outlined,
              title: 'Todos',
              subtitle: 'Inclui novos profissionais adicionados à equipe.',
              onTap: () {
                setState(() => _allProfessionals = true);
                _scheduleDraftSave();
              },
              secondTitle: 'Selecionar',
              secondIcon: Icons.person_search_outlined,
              secondOnTap: () {
                setState(() => _allProfessionals = false);
                _selectProfessionals();
                _scheduleDraftSave();
              }),
          if (!_allProfessionals)
            _selectionSummary(_selectedProfessionalIds, 'profissional'),
          SizedBox(height: 18),
          _label('Serviços'),
          _choiceRow(
              selected: _allServices,
              icon: Icons.content_cut_outlined,
              title: 'Todos',
              subtitle: 'Aplica aos serviços atuais e futuros.',
              onTap: () {
                setState(() => _allServices = true);
                _scheduleDraftSave();
              },
              secondTitle: 'Selecionar',
              secondIcon: Icons.tune_outlined,
              secondOnTap: () {
                setState(() => _allServices = false);
                _selectServices();
                _scheduleDraftSave();
              }),
          if (!_allServices) _selectionSummary(_selectedServiceIds, 'serviço'),
          SizedBox(height: 18),
          _label('Produtos'),
          SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _productsEnabled,
              activeColor: PremiumColors.gold,
              onChanged: null,
              title: Text('Incluir vendas de produtos'),
              subtitle: Text(
                  'Indisponível: o schema atual não possui vendas e vendedor registrados.')),
          SizedBox(height: 12),
          _label('Vigência'),
          TextField(
              controller: _date,
              onChanged: (_) => _scheduleDraftSave(),
              decoration: InputDecoration(
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                  labelText: 'Começa em (DD/MM/AAAA)')),
          SizedBox(height: 14),
          _info(
              'Regras específicas têm prioridade sobre a regra padrão. Alterações valem apenas para novos fatos geradores a partir da vigência.'),
        ]),
      );

  Widget _calculationStep() => PremiumSurface(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _sectionTitle('Como calcular a comissão?',
              'Defina o modelo e os parâmetros do cálculo.'),
          Row(children: [
            Expanded(
                child: _modelChoice(true, Icons.percent, 'Percentual',
                    'Um percentual sobre o valor')),
            SizedBox(width: 12),
            Expanded(
                child: _modelChoice(false, Icons.currency_exchange,
                    'Valor fixo', 'Um valor fixo por serviço')),
          ]),
          SizedBox(height: 18),
          if (_percentage)
            Row(children: [
              Expanded(
                  child: TextField(
                      controller: _rate,
                      onChanged: (_) => _scheduleDraftSave(),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                          labelText: 'Comissão sobre serviços',
                          suffixText: '%'))),
              SizedBox(width: 12),
              Expanded(
                  child: DropdownButtonFormField<String>(
                      value: _afterDiscounts ? 'AFTER_DISCOUNTS' : 'GROSS',
                      decoration: InputDecoration(labelText: 'Base de cálculo'),
                      items: const [
                        DropdownMenuItem(
                            value: 'AFTER_DISCOUNTS',
                            child: Text('Valor após descontos')),
                        DropdownMenuItem(
                            value: 'GROSS',
                            child: Text('Valor antes dos descontos')),
                      ],
                      onChanged: (value) {
                        setState(() => _afterDiscounts = value != 'GROSS');
                        _scheduleDraftSave();
                      })),
            ])
          else
            TextField(
                controller: _fixedValue,
                onChanged: (_) => _scheduleDraftSave(),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: 'Valor por unidade concluída',
                    prefixText: 'R\$ ')),
          SizedBox(height: 18),
          SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _productsEnabled,
              activeColor: PremiumColors.gold,
              onChanged: null,
              title: Text('Comissão sobre produtos'),
              subtitle: Text('Aguardando integração do catálogo de vendas.')),
          if (_productsEnabled)
            SizedBox(
                width: 260,
                child: TextField(
                    controller: _productRate,
                    onChanged: (_) => _scheduleDraftSave(),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                        labelText: 'Percentual de produtos', suffixText: '%'))),
          SizedBox(height: 16),
          _actionTile(
              Icons.settings_outlined,
              'Exceções por serviço',
              _exceptions.isEmpty
                  ? 'Personalize percentuais ou valores fixos sem somar com a regra padrão.'
                  : '${_exceptions.length} exceção(ões) configurada(s).',
              () => _exceptionDialog()),
          SizedBox(height: 10),
          _actionTile(
              Icons.track_changes_outlined,
              'Metas e faixas',
              _goalsEnabled
                  ? 'Meta mensal ativa: faixas progressivas sobre receita líquida.'
                  : 'Opcional. Ative faixas progressivas ou taxa sobre o total.',
              () => _goalDialog()),
          SizedBox(height: 16),
          _calculationPreview(),
        ]),
      );

  Widget _releaseStep() => PremiumSurface(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _sectionTitle('Quando a comissão fica disponível?',
              'Defina as condições para o profissional receber o crédito.'),
          CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _requiresFulfillment,
              activeColor: PremiumColors.gold,
              onChanged: (value) {
                setState(() => _requiresFulfillment = value ?? true);
                _scheduleDraftSave();
              },
              title: Text('Serviço concluído ou produto entregue'),
              subtitle: Text(
                  'Agendamento confirmado não equivale a serviço concluído.')),
          Divider(color: PremiumColors.border),
          _label('Tipo de recebimento'),
          RadioListTile<bool>(
              contentPadding: EdgeInsets.zero,
              value: false,
              groupValue: _proportionalReceipt,
              activeColor: PremiumColors.gold,
              onChanged: (_) {
                setState(() => _proportionalReceipt = false);
                _scheduleDraftSave();
              },
              title: Text('Recebimento integral'),
              subtitle: Text(
                  'Libera 100% apenas quando o valor devido for recebido.')),
          RadioListTile<bool>(
              contentPadding: EdgeInsets.zero,
              value: true,
              groupValue: _proportionalReceipt,
              activeColor: PremiumColors.gold,
              onChanged: (_) {
                setState(() => _proportionalReceipt = true);
                _scheduleDraftSave();
              },
              title: Text('Proporcional ao valor recebido'),
              subtitle: Text(
                  'Recebimentos parciais liberam a mesma proporção da comissão.')),
          _info(
              'Cancelamentos e estornos geram movimentos compensatórios. O histórico original nunca é apagado.'),
          SizedBox(height: 16),
          _label('Frequência de acerto'),
          DropdownButtonFormField<String>(
              value: _frequency,
              decoration: InputDecoration(labelText: 'Fechamento'),
              items: const [
                DropdownMenuItem(
                    value: 'WEEKLY', child: Text('Fechamento semanal')),
                DropdownMenuItem(
                    value: 'SEMI_MONTHLY', child: Text('Fechamento quinzenal')),
                DropdownMenuItem(
                    value: 'MONTHLY', child: Text('Fechamento mensal')),
                DropdownMenuItem(value: 'MANUAL', child: Text('Manual')),
              ],
              onChanged: (value) {
                setState(() => _frequency = value ?? 'MONTHLY');
                _scheduleDraftSave();
              }),
          SizedBox(height: 12),
          _info(
              'Fechar o período consolida os lançamentos, mas não registra pagamento nem transfere dinheiro.'),
        ]),
      );

  Widget _reviewStep() => Column(children: [
        _reviewCard(Icons.groups_outlined, 'Aplicação', [
          ['Nome da regra', _name.text],
          [
            'Profissionais',
            _allProfessionals ? 'Todos os profissionais' : 'Seleção específica'
          ],
          [
            'Serviços e produtos',
            _productsEnabled ? 'Serviços e produtos' : 'Somente serviços'
          ],
          ['Início da vigência', _date.text],
        ]),
        SizedBox(height: 12),
        _reviewCard(Icons.percent_outlined, 'Cálculo', [
          [
            'Serviços',
            _percentage
                ? '${_rate.text}% ${_afterDiscounts ? 'após descontos' : 'antes dos descontos'}'
                : 'R\$ ${_fixedValue.text} por unidade'
          ],
          [
            'Produtos',
            _productsEnabled
                ? '${_productRate.text}% após descontos'
                : 'Desativados'
          ],
          [
            'Exceções',
            _exceptions.isEmpty
                ? 'Nenhuma'
                : '${_exceptions.length} configurada(s)'
          ],
          ['Metas e faixas', _goalsEnabled ? 'Ativadas' : 'Desativadas'],
        ]),
        SizedBox(height: 12),
        _reviewCard(Icons.schedule_outlined, 'Liberação', [
          [
            'Momento',
            _requiresFulfillment ? 'Após conclusão/entrega' : 'Após recebimento'
          ],
          [
            'Recebimento',
            _proportionalReceipt ? 'Proporcional ao valor recebido' : 'Integral'
          ],
          ['Acerto', _frequencyLabel],
        ]),
        SizedBox(height: 12),
        _info(
            'Alterações futuras criarão uma nova versão. Lançamentos anteriores continuam com a regra e o snapshot originais.'),
      ]);

  String get _frequencyLabel => switch (_frequency) {
        'WEEKLY' => 'Semanal',
        'SEMI_MONTHLY' => 'Quinzenal',
        'MANUAL' => 'Manual',
        _ => 'Mensal (último dia)',
      };

  Widget _summary() => PremiumSurface(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Resumo da regra',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          SizedBox(height: 4),
          Text('Confira o impacto da configuração.',
              style: TextStyle(color: PremiumColors.textSecondary)),
          SizedBox(height: 18),
          _summaryRow(Icons.badge_outlined, 'Nome da regra', _name.text),
          _summaryRow(
              Icons.groups_outlined,
              'Aplicação',
              _allProfessionals
                  ? 'Todos os profissionais'
                  : 'Seleção específica'),
          _summaryRow(Icons.calendar_month_outlined, 'Vigência', _date.text),
          _summaryRow(
              Icons.percent_outlined,
              'Cálculo',
              _percentage
                  ? '${_rate.text}% ${_afterDiscounts ? 'após descontos' : 'bruto'}'
                  : 'R\$ ${_fixedValue.text} por unidade'),
          _summaryRow(
              Icons.schedule_outlined,
              'Liberação',
              _proportionalReceipt
                  ? 'Conclusão e recebimento proporcional'
                  : 'Conclusão e recebimento integral'),
          Divider(color: PremiumColors.border, height: 30),
          Text('Simulação de cálculo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          SizedBox(height: 4),
          Text('Exemplo baseado na configuração atual.',
              style:
                  TextStyle(color: PremiumColors.textSecondary, fontSize: 12)),
          SizedBox(height: 12),
          _simulationBox(),
        ]),
      );

  Widget _simulationBox() {
    final gross = _money(_simulationGross.text);
    final discount = _money(_simulationDiscount.text);
    final base = (gross - discount).clamp(0, double.infinity).toDouble();
    final commission = _percentage
        ? base * (_number(_rate.text) / 100)
        : _money(_fixedValue.text);
    final backendMemory = _simulation?['memory'] is Map
        ? Map<String, dynamic>.from(_simulation!['memory'] as Map)
        : null;
    return Container(
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: PremiumColors.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: PremiumColors.border)),
        child: Column(children: [
          _amountLine('Serviço', gross),
          _amountLine('Desconto', -discount),
          _amountLine('Base de cálculo', base),
          Divider(color: PremiumColors.border),
          _amountLine('Comissão (${_percentage ? '${_rate.text}%' : 'fixa'})',
              commission,
              highlight: true),
          if (backendMemory != null)
            Align(
                alignment: Alignment.centerLeft,
                child: Text(
                    'Backend: regra ${_simulation?['rule']?['version'] ?? '-'} · liberado ${backendMemory['released_amount'] ?? '0.00'}',
                    style:
                        TextStyle(color: PremiumColors.success, fontSize: 12))),
        ]));
  }

  Future<void> _runBackendSimulation() async {
    final catalog = context.read<AdminController>();
    final professionalId = _selectedProfessionalIds.isNotEmpty
        ? _selectedProfessionalIds.first
        : (catalog.colaboradores.isEmpty
            ? null
            : int.tryParse('${catalog.colaboradores.first['id']}'));
    final serviceId = _selectedServiceIds.isNotEmpty
        ? _selectedServiceIds.first
        : (catalog.servicos.isEmpty
            ? null
            : int.tryParse('${catalog.servicos.first['id']}'));
    if (professionalId == null || serviceId == null) {
      setState(() => _error =
          'Selecione ou cadastre um profissional e um serviço para simular.');
      return;
    }
    setState(() {
      _simulationLoading = true;
      _error = null;
    });
    final result = await _controller.simulateCommission({
      'professional_id': professionalId,
      'service_id': serviceId,
      'effective_at': _parseDate(_date.text),
      'gross_amount': _simulationGross.text.trim(),
      'discount_amount': _simulationDiscount.text.trim(),
      'received_amount': _simulationReceived.text.trim(),
      'quantity': 1,
    });
    if (!mounted) return;
    setState(() {
      _simulationLoading = false;
      _simulation = result;
      if (result == null)
        _error = _controller.error ?? 'Não foi possível simular no backend.';
    });
  }

  Widget _calculationPreview() =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Simulador de cálculo',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: TextField(
                  controller: _simulationGross,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                      labelText: 'Valor do serviço', prefixText: 'R\$ '))),
          SizedBox(width: 10),
          Expanded(
              child: TextField(
                  controller: _simulationDiscount,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                      labelText: 'Desconto', prefixText: 'R\$ '))),
        ]),
        SizedBox(height: 10),
        Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
                onPressed: _simulationLoading ? null : _runBackendSimulation,
                icon: _simulationLoading
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.cloud_done_outlined),
                label: Text(_simulationLoading
                    ? 'Simulando...'
                    : 'Validar no motor do backend'))),
        SizedBox(height: 10),
        _simulationBox(),
      ]);

  Widget _reviewCard(IconData icon, String title, List<List<String>> rows) =>
      PremiumSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(icon, color: PremiumColors.gold),
          SizedBox(width: 12),
          Text(title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))
        ]),
        Divider(color: PremiumColors.border, height: 24),
        ...rows.map((row) => Padding(
            padding: EdgeInsets.symmetric(vertical: 5),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                  width: 170,
                  child: Text(row[0],
                      style: TextStyle(color: PremiumColors.textSecondary))),
              Expanded(child: Text(row[1]))
            ]))),
      ]));

  Widget _choiceRow(
          {required bool selected,
          required IconData icon,
          required String title,
          required String subtitle,
          required VoidCallback onTap,
          required String secondTitle,
          required IconData secondIcon,
          required VoidCallback secondOnTap}) =>
      Row(children: [
        Expanded(child: _choice(selected, icon, title, subtitle, onTap)),
        SizedBox(width: 12),
        Expanded(
            child: _choice(!selected, secondIcon, secondTitle,
                'Selecione os itens específicos.', secondOnTap)),
      ]);

  Widget _choice(bool selected, IconData icon, String title, String subtitle,
      VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? PremiumColors.gold.withValues(alpha: .12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? PremiumColors.gold : PremiumColors.border,
              width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: selected
                    ? PremiumColors.gold
                    : PremiumColors.textSecondary),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: selected
                              ? PremiumColors.gold
                              : PremiumColors.textPrimary,
                          fontWeight: FontWeight.w800)),
                  SizedBox(height: 3),
                  Text(subtitle,
                      style: TextStyle(
                          color: PremiumColors.textSecondary, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modelChoice(
          bool percentage, IconData icon, String title, String subtitle) =>
      _choice(_percentage == percentage, icon, title, subtitle, () {
        setState(() => _percentage = percentage);
        _scheduleDraftSave();
      });

  Widget _actionTile(
          IconData icon, String title, String subtitle, VoidCallback onTap) =>
      InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: PremiumColors.border)),
              child: Row(children: [
                Icon(icon, color: PremiumColors.gold),
                SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      SizedBox(height: 3),
                      Text(subtitle,
                          style: TextStyle(
                              color: PremiumColors.textSecondary, fontSize: 12))
                    ])),
                Icon(Icons.chevron_right, color: PremiumColors.textSecondary)
              ])));

  Future<void> _exceptionDialog() async {
    final service = TextEditingController(text: 'Barba');
    final rate = TextEditingController(text: '35');
    final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: Text('Exceções por serviço'),
              content: SizedBox(
                  width: 430,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(
                        controller: service,
                        decoration: InputDecoration(labelText: 'Serviço')),
                    SizedBox(height: 12),
                    TextField(
                        controller: rate,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                            labelText: 'Percentual', suffixText: '%'))
                  ])),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text('Cancelar')),
                FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, {
                          'itemType': 'SERVICE',
                          'label': service.text.trim(),
                          'calculation': {
                            'model': 'PERCENTAGE',
                            'rate': rate.text.trim(),
                            'basis': 'AFTER_DISCOUNTS'
                          }
                        }),
                    child: Text('Aplicar à configuração'))
              ],
            ));
    if (!mounted || result == null) return;
    setState(() => _exceptions = [..._exceptions, result]);
    _scheduleDraftSave();
  }

  Future<void> _goalDialog() async {
    bool enabled = _goalsEnabled;
    String method = _goalMethod;
    final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
                  title: Text('Metas e faixas'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    SwitchListTile.adaptive(
                        value: enabled,
                        activeColor: PremiumColors.gold,
                        onChanged: (value) =>
                            setDialogState(() => enabled = value),
                        title: Text('Ativar metas')),
                    SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                        value: method,
                        items: const [
                          DropdownMenuItem(
                              value: 'MARGINAL',
                              child: Text('Aplicar por faixa')),
                          DropdownMenuItem(
                              value: 'WHOLE_TOTAL',
                              child: Text('Aplicar ao total'))
                        ],
                        onChanged: (value) =>
                            setDialogState(() => method = value ?? method),
                        decoration:
                            InputDecoration(labelText: 'Método de aplicação'))
                  ]),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text('Cancelar')),
                    FilledButton(
                        onPressed: () {
                          _goalsEnabled = enabled;
                          _goalMethod = method;
                          Navigator.pop(dialogContext, true);
                        },
                        child: Text('Aplicar à configuração'))
                  ],
                )));
    if (result == true && mounted) {
      setState(() {});
      _scheduleDraftSave();
    }
  }

  Widget _sectionTitle(String title, String subtitle) => Padding(
      padding: EdgeInsets.only(bottom: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
        SizedBox(height: 4),
        Text(subtitle, style: TextStyle(color: PremiumColors.textSecondary))
      ]));
  Widget _label(String text) => Padding(
      padding: EdgeInsets.only(bottom: 7),
      child: Text(text, style: TextStyle(fontWeight: FontWeight.w700)));
  Widget _info(String text) => Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: PremiumColors.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: PremiumColors.border)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.info_outline, size: 18, color: PremiumColors.textSecondary),
        SizedBox(width: 9),
        Expanded(
            child: Text(text,
                style: TextStyle(
                    color: PremiumColors.textSecondary, fontSize: 12)))
      ]));
  Widget _banner(String text, Color color) => Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: .4))),
      child: Row(children: [
        Icon(Icons.info_outline, color: color, size: 18),
        SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(color: color)))
      ]));
  Widget _summaryRow(IconData icon, String label, String value) => Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 19, color: PremiumColors.textSecondary),
        SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style:
                  TextStyle(color: PremiumColors.textSecondary, fontSize: 12)),
          SizedBox(height: 3),
          Text(value, style: TextStyle(fontWeight: FontWeight.w700))
        ]))
      ]));
  Widget _amountLine(String label, double value, {bool highlight = false}) =>
      Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(
                child: Text(label,
                    style: TextStyle(
                        color: highlight
                            ? PremiumColors.textPrimary
                            : PremiumColors.textSecondary))),
            Text(_currency(value),
                style: TextStyle(
                    color: highlight
                        ? PremiumColors.gold
                        : PremiumColors.textPrimary,
                    fontWeight: highlight ? FontWeight.w800 : FontWeight.w500,
                    fontSize: highlight ? 18 : 13))
          ]));
  double _number(String value) {
    final normalized = value.trim().replaceAll(' ', '');
    if (normalized.contains(',') && normalized.contains('.')) {
      return double.tryParse(
              normalized.replaceAll('.', '').replaceAll(',', '.')) ??
          0;
    }
    return double.tryParse(normalized.replaceAll(',', '.')) ?? 0;
  }

  double _money(String value) => _number(value);
  String _currency(double value) =>
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(value);
}
