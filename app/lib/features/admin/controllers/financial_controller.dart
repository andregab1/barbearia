import 'package:flutter/foundation.dart';
import '../../../core/services/api_service.dart';

// * Estado da area financeira no Flutter. Este controller concentra consultas
// * e comandos HTTP; a API continua responsavel por tenant, permissoes,
// * transacoes e idempotencia.
enum FinancialArea {
  serviceReceipts,
  overview,
  movements,
  expenses,
  receivables,
  commissions,
  categories
}

class FinancialController extends ChangeNotifier {
  int _commandSequence = 0;
  bool _periodWasSelected = false;
  bool _commissionPeriodInitialized = false;
  FinancialArea area = FinancialArea.overview;
  DateTime from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime to = DateTime.now();
  int? professionalId;
  int? serviceId;
  bool loading = false;
  bool submitting = false;
  String? error;
  Map<String, dynamic> dashboard = {};
  Map<String, dynamic> expenseSummary = {};
  Map<String, dynamic> metadata = {};
  List<Map<String, dynamic>> movements = [];
  List<Map<String, dynamic>> expenses = [];
  List<Map<String, dynamic>> receivables = [];
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> commissionEntries = [];
  Map<String, dynamic> commissionSummary = {};
  Map<String, dynamic> commissionOverview = {};
  List<Map<String, dynamic>> commissionStatementItems = [];
  List<Map<String, dynamic>> commissionLedger = [];
  List<Map<String, dynamic>> commissionRules = [];
  List<Map<String, dynamic>> commissionSettlements = [];
  List<Map<String, dynamic>> commissionAdvances = [];
  List<Map<String, dynamic>> commissionPayments = [];
  List<Map<String, dynamic>> commissionProfessionals = [];
  Map<String, dynamic> commissionBoardTotals = {};
  Map<String, dynamic> commissionPagination = {};
  List<Map<String, dynamic>> commissionHistory = [];

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  String get query =>
      'from=${_date(from)}&to=${_date(to)}${professionalId == null ? '' : '&professional_id=$professionalId'}${serviceId == null ? '' : '&service_id=$serviceId'}';

  Future<void> initialize() async {
    if (metadata.isEmpty) {
      final response = await ApiService.get('/finance/metadata');
      if (response['erro'] != null) error = response['erro'].toString();
      if (response['data'] is Map)
        metadata = Map<String, dynamic>.from(response['data']);
    }
    await loadCurrent();
  }

  Future<void> setArea(FinancialArea value) async {
    area = value;
    if (value == FinancialArea.commissions &&
        !_periodWasSelected &&
        !_commissionPeriodInitialized) {
      final now = DateTime.now();
      from = DateTime(now.year, now.month, 1);
      to = DateTime(now.year, now.month + 1, 0);
      _commissionPeriodInitialized = true;
    }
    notifyListeners();
    await loadCurrent();
  }

  Future<void> setPeriod(DateTime start, DateTime end) async {
    _periodWasSelected = true;
    from = start;
    to = end;
    await loadCurrent();
  }

  Future<void> setProfessional(int? value) async {
    professionalId = value;
    await loadCurrent();
  }

  Future<void> setService(int? value) async {
    serviceId = value;
    await loadCurrent();
  }

  Future<void> loadCurrent() async {
    loading = true;
    error = null;
    notifyListeners();
    if (area == FinancialArea.commissions) {
      await loadCommissionBoard();
      loading = false;
      notifyListeners();
      return;
    }
    final endpoint = switch (area) {
      FinancialArea.serviceReceipts => '/finance/receivables?$query&limit=50',
      FinancialArea.overview => '/finance/dashboard?$query',
      FinancialArea.movements => '/finance/movements?$query&limit=50',
      FinancialArea.expenses => '/finance/expenses?$query&limit=50',
      FinancialArea.receivables => '/finance/receivables?$query&limit=50',
      FinancialArea.commissions => '/finance/commissions/entries?$query',
      FinancialArea.categories => '/finance/categories',
    };
    var response = await ApiService.get(endpoint);
    if (area == FinancialArea.commissions && response['erro'] != null) {
      final retryResponse = await ApiService.get(endpoint);
      if (retryResponse['erro'] == null) response = retryResponse;
    }
    if (response['erro'] != null) error = response['erro'].toString();
    final data = response['data'];
    if (area == FinancialArea.overview && data is Map)
      dashboard = Map<String, dynamic>.from(data);
    if (area == FinancialArea.movements && data is List)
      movements = data.map((e) => Map<String, dynamic>.from(e)).toList();
    if (area == FinancialArea.expenses && data is List) {
      expenses = data.map((e) => Map<String, dynamic>.from(e)).toList();
      expenseSummary = response['summary'] is Map
          ? Map<String, dynamic>.from(response['summary'])
          : {};
    }
    if ((area == FinancialArea.receivables ||
            area == FinancialArea.serviceReceipts) &&
        data is List)
      receivables = data.map((e) => Map<String, dynamic>.from(e)).toList();
    if (area == FinancialArea.commissions && data is List) {
      commissionEntries =
          data.map((e) => Map<String, dynamic>.from(e)).toList();
      var overviewResponse =
          await ApiService.get('/finance/commissions/overview?$query');
      if (overviewResponse['erro'] != null) {
        final retryResponse =
            await ApiService.get('/finance/commissions/overview?$query');
        if (retryResponse['erro'] == null) {
          overviewResponse = retryResponse;
        } else {
          error = overviewResponse['erro'].toString();
        }
      }
      if (overviewResponse['data'] is Map) {
        commissionOverview =
            Map<String, dynamic>.from(overviewResponse['data']);
      }
      final statementResponse =
          await ApiService.get('/finance/commissions/statement?$query');
      if (statementResponse['data'] is Map) {
        final statement = Map<String, dynamic>.from(statementResponse['data']);
        commissionStatementItems = (statement['items'] is List)
            ? statement['items']
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
            : [];
        commissionLedger = (statement['ledger'] is List)
            ? statement['ledger']
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
            : [];
        commissionOverview['opening_balance'] = statement['opening_balance'];
        commissionOverview['closing_balance'] = statement['closing_balance'];
      }
      final summaryResponse =
          await ApiService.get('/finance/commissions/summary?$query');
      if (summaryResponse['data'] is Map)
        commissionSummary = Map<String, dynamic>.from(summaryResponse['data']);
      final rulesResponse = await ApiService.get('/finance/commissions/rules');
      if (rulesResponse['data'] is List)
        commissionRules = rulesResponse['data']
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      final settlementsResponse = await ApiService.get(
          '/finance/commissions/settlements${professionalId == null ? '' : '?professional_id=$professionalId'}');
      if (settlementsResponse['data'] is List)
        commissionSettlements = settlementsResponse['data']
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      final advancesResponse = await ApiService.get(
          '/finance/commissions/advances${professionalId == null ? '' : '?professional_id=$professionalId'}');
      if (advancesResponse['data'] is List)
        commissionAdvances = advancesResponse['data']
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      final paymentsResponse =
          await ApiService.get('/finance/commissions/settlement-payments');
      if (paymentsResponse['data'] is List)
        commissionPayments = paymentsResponse['data']
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
    }
    if (area == FinancialArea.categories && data is List)
      categories = data.map((e) => Map<String, dynamic>.from(e)).toList();
    loading = false;
    notifyListeners();
  }

  // * CONSULTAR: carrega o quadro de comissoes e seus totais derivados.
  Future<void> loadCommissionBoard({
    String search = '',
    String? status,
    int page = 1,
    int pageSize = 25,
  }) async {
    final params = <String>[
      'from=${_date(from)}',
      'to=${_date(to)}',
      'page=$page',
      'pageSize=$pageSize',
      if (professionalId != null) 'professionalId=$professionalId',
      if (serviceId != null) 'serviceId=$serviceId',
      if (search.trim().isNotEmpty)
        'search=${Uri.encodeQueryComponent(search.trim())}',
      if (status != null && status.isNotEmpty) 'status=$status',
    ];
    final response = await ApiService.get(
        '/finance/commissions/professionals?${params.join('&')}');
    if (response['erro'] != null) {
      error = response['erro'].toString();
      return;
    }
    commissionProfessionals = response['data'] is List
        ? response['data'].map((e) => Map<String, dynamic>.from(e)).toList()
        : [];
    commissionBoardTotals = response['totals'] is Map
        ? Map<String, dynamic>.from(response['totals'])
        : {};
    commissionPagination = response['pagination'] is Map
        ? Map<String, dynamic>.from(response['pagination'])
        : {};
  }

  Future<Map<String, dynamic>?> loadCommissionProfessionalDetails(
      int professionalId) async {
    final response = await ApiService.get(
        '/finance/commissions/professionals/$professionalId/items?$query');
    if (response['erro'] != null) {
      error = response['erro'].toString();
      notifyListeners();
      return null;
    }
    return response['data'] is Map
        ? Map<String, dynamic>.from(response['data'])
        : null;
  }

  Future<Map<String, dynamic>?> createCommissionPaymentPreview(
      Map<String, dynamic> body) async {
    final response =
        await ApiService.post('/finance/commissions/payment-previews', body);
    if (response['erro'] != null) {
      error = response['erro'].toString();
      notifyListeners();
      return null;
    }
    return response['data'] is Map
        ? Map<String, dynamic>.from(response['data'])
        : null;
  }

  // * EDITAR ESTADO: pagamentos usam Idempotency-Key; repetir o clique nao
  // * deve criar um segundo pagamento.
  Future<Map<String, dynamic>?> payCommissionBatch(Map<String, dynamic> body,
      {String? idempotencyKey}) async {
    final response = await ApiService.post(
        '/finance/commissions/payments', body, extraHeaders: {
      'Idempotency-Key': idempotencyKey ?? _key('commission-batch')
    });
    if (response['erro'] != null) {
      error = response['erro'].toString();
      notifyListeners();
      return null;
    }
    await loadCommissionBoard();
    return response['data'] is Map
        ? Map<String, dynamic>.from(response['data'])
        : {};
  }

  Future<void> loadCommissionHistory() async {
    final response = await ApiService.get(
        '/finance/commissions/history?from=${_date(from)}&to=${_date(to)}');
    if (response['erro'] != null) {
      error = response['erro'].toString();
      return;
    }
    commissionHistory = response['data'] is List
        ? response['data'].map((e) => Map<String, dynamic>.from(e)).toList()
        : [];
  }

  // nextInt precisa receber um limite positivo de 32 bits também no Dart2JS.
  // `1 << 32` virava zero no Flutter Web e impedia o POST antes de chegar à API.
  String _key(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${++_commandSequence}';
  Future<String?> _command(String path, Map<String, dynamic> body,
      {String? key}) async {
    // O dialogo possui seu proprio estado de envio. Notificar os listeners aqui,
    // durante o callback do botao do dialogo, pode provocar uma reconstrucao no
    // meio do frame e interromper a chamada antes mesmo do POST ser executado.
    submitting = true;
    try {
      final response = await ApiService.post(path, body,
          extraHeaders: key == null ? null : {'X-Idempotency-Key': key});
      if (response['erro'] != null) return response['erro'].toString();
      await loadCurrent();
      return null;
    } catch (_) {
      return 'Nao foi possivel concluir a operacao. Tente novamente.';
    } finally {
      submitting = false;
      notifyListeners();
    }
  }

  // * ADICIONAR: despesas, regras, rascunhos, ajustes e categorias.
  Future<String?> createExpense(Map<String, dynamic> body) =>
      _command('/finance/expenses', body);
  Future<String?> createCommissionRule(Map<String, dynamic> body) =>
      _command('/finance/commissions/rules', body);
  Future<Map<String, dynamic>?> createCommissionDraft(
      Map<String, dynamic> payload) async {
    final response =
        await ApiService.post('/finance/commissions/rule-drafts', payload);
    if (response['erro'] != null) {
      error = response['erro'].toString();
      notifyListeners();
      return null;
    }
    return response['data'] is Map
        ? Map<String, dynamic>.from(response['data'])
        : null;
  }

  Future<Map<String, dynamic>?> createCommissionRuleVersionDraft(
      int ruleId) async {
    final response = await ApiService.post(
        '/finance/commissions/rules/$ruleId/new-version', {});
    if (response['erro'] != null) {
      error = response['erro'].toString();
      notifyListeners();
      return null;
    }
    return response['data'] is Map
        ? Map<String, dynamic>.from(response['data'])
        : null;
  }

  Future<Map<String, dynamic>?> getCommissionDraft([int? draftId]) async {
    final response = await ApiService.get(draftId == null
        ? '/finance/commissions/rule-drafts/active'
        : '/finance/commissions/rule-drafts/$draftId');
    if (response['erro'] != null) return null;
    return response['data'] is Map
        ? Map<String, dynamic>.from(response['data'])
        : null;
  }

  Future<Map<String, dynamic>?> updateCommissionDraft(
      int draftId, int revision, Map<String, dynamic> payload) async {
    final response = await ApiService.patch(
        '/finance/commissions/rule-drafts/$draftId',
        {'revision': revision, 'payload': payload});
    if (response['erro'] != null) {
      error = response['erro'].toString();
      notifyListeners();
      return null;
    }
    return response['data'] is Map
        ? Map<String, dynamic>.from(response['data'])
        : null;
  }

  Future<String?> publishCommissionDraft(int draftId) async {
    final response = await ApiService.post(
        '/finance/commissions/rule-drafts/$draftId/publish', {});
    if (response['erro'] != null) return response['erro'].toString();
    await loadCurrent();
    return null;
  }

  Future<Map<String, dynamic>?> simulateCommission(
      Map<String, dynamic> body) async {
    try {
      final response =
          await ApiService.post('/finance/commissions/simulate', body);
      if (response['erro'] != null) {
        error = response['erro'].toString();
        notifyListeners();
        return null;
      }
      return response['data'] is Map
          ? Map<String, dynamic>.from(response['data'])
          : null;
    } catch (_) {
      error = 'Nao foi possivel simular a comissao.';
      notifyListeners();
      return null;
    }
  }

  // * ADICIONAR/EDITAR: fechamento, pagamento, adiantamento e ajustes de
  // * comissao; reversal e cancelamento sao compensacoes auditaveis.
  Future<String?> createCommissionSettlement(Map<String, dynamic> body) =>
      _command('/finance/commissions/settlements', body,
          key: _key('commission-settlement'));
  Future<String?> payCommissionSettlement(
          int settlementId, Map<String, dynamic> body) =>
      _command('/finance/commissions/settlements/$settlementId/payments', body,
          key: _key('commission-payment'));
  Future<String?> createCommissionAdvance(Map<String, dynamic> body) =>
      _command('/finance/commissions/advances', body,
          key: _key('commission-advance'));
  Future<String?> reverseCommissionPayment(int paymentId, String reason) =>
      _command('/finance/commissions/settlement-payments/$paymentId/reversal',
          {'reason': reason},
          key: _key('commission-payment-reversal'));
  Future<String?> reverseCommissionAdvance(int advanceId, String reason) =>
      _command('/finance/commissions/advances/$advanceId/reversal',
          {'reason': reason},
          key: _key('commission-advance-reversal'));
  Future<String?> createCommissionAdjustment(
          int entitlementId, Map<String, dynamic> body) =>
      _command(
          '/finance/commissions/entitlements/$entitlementId/adjustments', body,
          key: _key('commission-adjustment'));
  Future<String?> createCategory(String name, String type) =>
      _command('/finance/categories', {'name': name, 'type': type});
  Future<String?> updateCategory(
          int id, String name, String type, bool active) =>
      _command('/finance/categories/$id',
          {'name': name, 'type': type, 'active': active});
  Future<String?> payExpense(int id, int accountId, String paidAt) => _command(
      '/finance/expenses/$id/pay', {'account_id': accountId, 'paid_at': paidAt},
      key: _key('expense'));
  Future<String?> payExpenses(List<int> ids, int accountId, String paidAt) =>
      _command('/finance/expenses/bulk-pay',
          {'expense_ids': ids, 'account_id': accountId, 'paid_at': paidAt},
          key: _key('expense-batch'));
  Future<String?> cancelExpense(int id, String reason) =>
      _command('/finance/expenses/$id/cancel', {'reason': reason});
  Future<String?> cancelExpenses(List<int> ids, String reason) => _command(
      '/finance/expenses/bulk-cancel', {'expense_ids': ids, 'reason': reason});
  Future<String?> registerPayment(
          int appointmentId, Map<String, dynamic> body) =>
      _command('/finance/receivables/$appointmentId/payments', body,
          key: _key('payment'));
  Future<String?> registerPayments(
          List<Map<String, dynamic>> items, Map<String, dynamic> body) =>
      _command('/finance/receivables/bulk-payments', {'items': items, ...body},
          key: _key('bulk-payment'));
  Future<String?> excludeReceivables(List<int> appointmentIds) => _command(
      '/finance/receivables/bulk-exclude', {'appointment_ids': appointmentIds},
      key: _key('exclude-receivables'));
}
