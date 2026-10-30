const router = require('express').Router();
const { autenticar } = require('../middlewares/auth.middleware');
const { tenantContext, requireCapability } = require('../middlewares/capabilities.middleware');
const controller = require('../controllers/financial-operational.controller');
const commissionController = require('../controllers/commission.controller');

// * Toda a API financeira exige login e tenantContext. O tenant vem da sessao,
// * portanto os handlers nao devem confiar em barbearia_id enviado pelo cliente.
router.use(autenticar, tenantContext);

// * CONSULTAR: painel, movimentacoes, despesas, contas a receber e metadados.
// * As capabilities abaixo controlam leitura por modulo, alem da autenticacao.
router.get('/dashboard', requireCapability('financial.dashboard.read'), controller.dashboard);
router.get('/movements', requireCapability('financial.movements.read'), controller.movements);
router.get('/movements/:id', requireCapability('financial.movements.read'), controller.movement);
router.get('/expenses', requireCapability('financial.expenses.read'), controller.expenses);

// * ADICIONAR: cria uma despesa pendente vinculada ao tenant atual.
router.post('/expenses', requireCapability('financial.expenses.create'), controller.createExpense);
// * EDITAR/EXCLUIR: pagamentos e cancelamentos sao comandos separados para
// * preservar o historico financeiro; o backend valida o estado da despesa.
router.post('/expenses/bulk-pay', requireCapability('financial.expenses.pay'), controller.payExpenses);
router.post('/expenses/bulk-cancel', requireCapability('financial.expenses.update'), controller.cancelExpenses);
router.patch('/expenses/:id', requireCapability('financial.expenses.update'), controller.updateExpense);
router.post('/expenses/:id/pay', requireCapability('financial.expenses.pay'), controller.payExpense);
router.post('/expenses/:id/cancel', requireCapability('financial.expenses.update'), controller.cancelExpense);

// * CONSULTAR/EDITAR: contas a receber sao geradas a partir dos atendimentos.
// * Pagar registra recebimento; excluir apenas marca a conta como cancelada.
router.get('/receivables', requireCapability('financial.receivables.read'), controller.receivables);
router.post('/receivables/bulk-payments', requireCapability('financial.payments.create'), controller.bulkPayment);
router.post('/receivables/bulk-exclude', requireCapability('financial.payments.create'), controller.excludeReceivables);
router.post('/receivables/:appointmentId/payments', requireCapability('financial.payments.create'), controller.payment);
// * EDITAR: estorno desfaz um pagamento sem apagar seu registro de auditoria.
router.post('/payments/:paymentId/refunds', requireCapability('financial.payments.create'), controller.refund);
router.get('/metadata', requireCapability('financial.dashboard.read'), controller.metadata);

// * ADICIONAR/EDITAR: categorias sao configuracao do tenant e podem ser
// * desativadas pelo campo active, sem excluir o historico que ja as utiliza.
router.get('/categories', requireCapability('financial.categories.read'), controller.categories);
router.post('/categories', requireCapability('financial.categories.manage'), controller.createCategory);
router.patch('/categories/:id', requireCapability('financial.categories.manage'), controller.updateCategory);

// * COMISSOES: o mesmo dominio financeiro controla regras, lancamentos,
// * aprovacao, adiantamentos, pagamentos e estornos de comissao.
// * CONFIGURACAO: rules/settings e drafts permitem preparar, editar e publicar
// * uma regra sem substituir silenciosamente uma versao ja usada.
router.get('/commissions/rules', requireCapability('finance.commission.view'), commissionController.rules);
router.get('/commissions/settings', requireCapability('finance.commission.manage'), commissionController.settings);
router.patch('/commissions/settings', requireCapability('finance.commission.manage'), commissionController.updateSettings);
router.post('/commissions/rules', requireCapability('finance.commission.manage'), commissionController.createRule);
router.post('/commissions/rules/:id/new-version', requireCapability('finance.commission.manage'), commissionController.createRuleVersionDraft);
router.post('/commissions/rule-drafts', requireCapability('finance.commission.manage'), commissionController.createRuleDraft);
router.get('/commissions/rule-drafts/active', requireCapability('finance.commission.manage'), commissionController.activeRuleDraft);
router.get('/commissions/rule-drafts/:id', requireCapability('finance.commission.manage'), commissionController.getRuleDraft);
router.patch('/commissions/rule-drafts/:id', requireCapability('finance.commission.manage'), commissionController.updateRuleDraft);
router.post('/commissions/rule-drafts/:id/publish', requireCapability('finance.commission.manage'), commissionController.publishRuleDraft);

// * CONSULTAR: entries, summaries, statements, profissionais e historico sao
// * leituras derivadas dos lancamentos; nao alteram valores persistidos.
router.post('/commissions/simulate', requireCapability('finance.commission.view'), commissionController.simulate);
router.get('/commissions/entries', requireCapability('finance.commission.view'), commissionController.entries);
router.get('/commissions/entries/:id', requireCapability('finance.commission.view'), commissionController.entryDetail);
router.get('/commissions/summary', requireCapability('finance.commission.view'), commissionController.summary);
router.get('/commissions/overview', requireCapability('finance.commission.view'), commissionController.overview);
router.get('/commissions/professionals', requireCapability('finance.commission.view'), commissionController.professionals);
router.get('/commissions/professionals/:id/items', requireCapability('finance.commission.view'), commissionController.professionalDetails);
router.get('/commissions/history', requireCapability('finance.commission.view'), commissionController.history);
router.post('/commissions/approvals', requireCapability('finance.commission.manage'), commissionController.approve);
router.post('/commissions/payment-previews', requireCapability('finance.commission.close'), commissionController.paymentPreview);
router.post('/commissions/payments', requireCapability('finance.commission.pay'), commissionController.payBatch);
router.get('/commissions/statement', requireCapability('finance.commission.view'), commissionController.statement);
router.get('/commissions/me/entries', requireCapability('commission.own.view'), commissionController.ownEntries);
router.get('/commissions/me/summary', requireCapability('commission.own.view'), commissionController.ownSummary);
router.get('/commissions/me/overview', requireCapability('commission.own.view'), commissionController.ownOverview);
router.get('/commissions/me/statement', requireCapability('commission.own.history'), commissionController.ownStatement);

// * EDITAR/ADICIONAR: ajustes e aprovacao registram decisoes financeiras;
// * preview calcula o lote antes do fechamento efetivo.
router.post('/commissions/entitlements/:id/adjustments', requireCapability('finance.commission.adjust'), commissionController.adjustment);
router.post('/commissions/settlements/preview', requireCapability('finance.commission.close'), commissionController.settlementPreview);
router.post('/commissions/settlements', requireCapability('finance.commission.close'), commissionController.createSettlement);
router.get('/commissions/settlements', requireCapability('finance.commission.view'), commissionController.settlements);
router.get('/commissions/settlement-payments', requireCapability('finance.commission.view'), commissionController.settlementPayments);
router.post('/commissions/settlements/:id/payments', requireCapability('finance.commission.pay'), commissionController.paySettlement);
// * EXCLUIR LOGICAMENTE: reversal estorna pagamento/adiantamento e conserva o
// * registro original para auditoria; nao e um DELETE fisico.
router.post('/commissions/settlement-payments/:id/reversal', requireCapability('finance.commission.reverse'), commissionController.reversePayment);
router.get('/commissions/advances', requireCapability('finance.commission.advance'), commissionController.advances);
router.post('/commissions/advances', requireCapability('finance.commission.advance'), commissionController.createAdvance);
router.post('/commissions/advances/:id/reversal', requireCapability('finance.commission.reverse'), commissionController.reverseAdvance);

module.exports = router;
