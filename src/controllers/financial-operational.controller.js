const service = require('../services/financial-operational.service');
const { errorBody } = require('../middlewares/request.middleware');

const MESSAGES = {
  VALIDATION_ERROR: 'Revise os campos informados.', INVALID_RELATION: 'Categoria, conta ou responsavel invalido.',
  INVALID_ACCOUNT: 'A conta financeira nao pertence a esta barbearia.', EXPENSE_NOT_FOUND: 'Despesa nao encontrada.',
  EXPENSE_NOT_EDITABLE: 'Somente despesas pendentes podem ser editadas.', EXPENSE_STATE_CONFLICT: 'A despesa nao esta pendente.',
  RECEIVABLE_NOT_FOUND: 'Conta a receber nao encontrada.', APPOINTMENT_NOT_COMPLETED: 'O atendimento ainda nao foi concluido.',
  PAYMENT_EXCEEDS_BALANCE: 'O valor excede o saldo em aberto.', FULL_PAYMENT_REQUIRED: 'Nesta fase, informe o saldo integral.',
  PAYMENT_CONFLICT: 'O pagamento ja foi processado ou esta em processamento.', IDEMPOTENCY_CONFLICT: 'A chave ja foi usada em outra operacao.',
};

function sendResult(req, res, result, successMessage) {
  if (result.status >= 400) {
    const message = result.code === 'FULL_PAYMENT_REQUIRED' && result.outstanding
      ? `${MESSAGES[result.code]} Saldo: R$ ${result.outstanding}.` : (MESSAGES[result.code] || 'Nao foi possivel concluir a operacao.');
    return res.status(result.status).json(errorBody(req, result.code, message));
  }
  return res.status(result.status).json({ data: result, message: successMessage, requestId: req.requestId });
}

async function dashboard(req, res, next) { try { return res.json({ data: await service.getDashboard(req.tenant.id, req.query), requestId: req.requestId }); } catch (e) { return next(e); } }
async function movements(req, res, next) { try { const result = await service.listMovements(req.tenant.id, req.query); return res.json({ data: result.rows || result, pagination: result.pagination, requestId: req.requestId }); } catch (e) { return next(e); } }
async function movement(req, res, next) { try { const data = await service.movementDetail(req.tenant.id, Number(req.params.id)); return data ? res.json({ data, requestId: req.requestId }) : res.status(404).json(errorBody(req, 'MOVEMENT_NOT_FOUND', 'Movimentacao nao encontrada.')); } catch (e) { return next(e); } }
async function expenses(req, res, next) { try { const result = await service.listExpenses(req.tenant.id, req.query); return res.json({ data: result.rows, summary: result.summary, pagination: result.pagination, requestId: req.requestId }); } catch (e) { return next(e); } }
async function createExpense(req, res, next) { try { return sendResult(req, res, await service.createExpense({ tenantId: req.tenant.id, actorId: req.usuario.id, data: req.body, requestId: req.requestId }), 'Despesa cadastrada com sucesso.'); } catch (e) { return next(e); } }
async function updateExpense(req, res, next) { try { return sendResult(req, res, await service.updateExpense({ tenantId: req.tenant.id, actorId: req.usuario.id, expenseId: Number(req.params.id), data: req.body, requestId: req.requestId }), 'Despesa atualizada com sucesso.'); } catch (e) { return next(e); } }
async function payExpense(req, res, next) { try { return sendResult(req, res, await service.payExpense({ tenantId: req.tenant.id, actorId: req.usuario.id, expenseId: Number(req.params.id), accountId: req.body.account_id, paidAt: req.body.paid_at, idempotencyKey: req.headers['x-idempotency-key'], requestId: req.requestId }), 'Despesa paga com sucesso.'); } catch (e) { return next(e); } }
async function payExpenses(req, res, next) { try { return sendResult(req, res, await service.payExpenses({ tenantId: req.tenant.id, actorId: req.usuario.id, expenseIds: req.body.expense_ids, accountId: req.body.account_id, paidAt: req.body.paid_at, idempotencyKey: req.headers['x-idempotency-key'], requestId: req.requestId }), 'Despesas pagas com sucesso.'); } catch (e) { return next(e); } }
async function cancelExpense(req, res, next) { try { return sendResult(req, res, await service.cancelExpense({ tenantId: req.tenant.id, actorId: req.usuario.id, expenseId: Number(req.params.id), reason: req.body.reason, requestId: req.requestId }), 'Despesa cancelada com sucesso.'); } catch (e) { return next(e); } }
async function cancelExpenses(req, res, next) { try { return sendResult(req, res, await service.cancelExpenses({ tenantId: req.tenant.id, actorId: req.usuario.id, expenseIds: req.body.expense_ids, reason: req.body.reason, requestId: req.requestId }), 'Despesas canceladas com sucesso.'); } catch (e) { return next(e); } }
async function receivables(req, res, next) { try { const result = await service.listReceivables(req.tenant.id, req.query); return res.json({ data: result.rows, pagination: result.pagination, requestId: req.requestId }); } catch (e) { return next(e); } }
async function payment(req, res, next) { try { return sendResult(req, res, await service.registerPayment({ tenantId: req.tenant.id, actorId: req.usuario.id, appointmentId: Number(req.params.appointmentId), data: req.body, idempotencyKey: req.headers['x-idempotency-key'], requestId: req.requestId }), 'Pagamento registrado com sucesso.'); } catch (e) { return next(e); } }
async function refund(req, res, next) { try { return sendResult(req, res, await service.refundPayment({ tenantId: req.tenant.id, actorId: req.usuario.id, paymentId: Number(req.params.paymentId), data: req.body, idempotencyKey: req.headers['x-idempotency-key'], requestId: req.requestId }), 'Estorno registrado com sucesso.'); } catch (e) { return next(e); } }
async function bulkPayment(req, res, next) { try { return sendResult(req, res, await service.registerPayments({ tenantId: req.tenant.id, actorId: req.usuario.id, items: req.body.items, accountId: req.body.account_id, method: req.body.method, paidAt: req.body.paid_at, notes: req.body.notes, idempotencyKey: req.headers['x-idempotency-key'], requestId: req.requestId }), 'Pagamentos registrados com sucesso.'); } catch (e) { return next(e); } }
async function excludeReceivables(req, res, next) { try { return sendResult(req, res, await service.excludeReceivables({ tenantId: req.tenant.id, actorId: req.usuario.id, appointmentIds: req.body.appointment_ids, requestId: req.requestId }), 'Contas a receber excluidas com sucesso.'); } catch (e) { return next(e); } }
async function metadata(req, res, next) { try { return res.json({ data: await service.metadata(req.tenant.id), requestId: req.requestId }); } catch (e) { return next(e); } }
async function categories(req, res, next) { try { return res.json({ data: await service.listCategories(req.tenant.id), requestId: req.requestId }); } catch (e) { return next(e); } }
async function createCategory(req, res, next) { try { return sendResult(req, res, await service.createCategory({ tenantId: req.tenant.id, data: req.body }), 'Categoria criada com sucesso.'); } catch (e) { return next(e); } }
async function updateCategory(req, res, next) { try { return sendResult(req, res, await service.updateCategory({ tenantId: req.tenant.id, categoryId: Number(req.params.id), data: req.body }), 'Categoria atualizada com sucesso.'); } catch (e) { return next(e); } }

module.exports = { dashboard, movements, movement, expenses, createExpense, updateExpense, payExpense, payExpenses, cancelExpense, cancelExpenses, receivables, payment, refund, bulkPayment, excludeReceivables, metadata, categories, createCategory, updateCategory };
