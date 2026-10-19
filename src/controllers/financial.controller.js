const crypto = require('crypto');
const { pool } = require('../config/database');
const { errorBody } = require('../middlewares/request.middleware');
const { cents, decimal, categoryId, accountId, registerPayment } = require('../services/financial.service');
const { postEntry } = require('../services/accounting.service');

function period(query) {
  const date = /^\d{4}-\d{2}-\d{2}$/;
  const today = new Date().toISOString().slice(0, 10);
  return {
    from: date.test(query.from || '') ? query.from : `${today.slice(0, 7)}-01`,
    to: date.test(query.to || '') ? query.to : today,
  };
}

function filters(req) {
  const values = period(req.query);
  const professionalId = Number.parseInt(req.query.professional_id, 10);
  return { ...values, professionalId: Number.isInteger(professionalId) && professionalId > 0 ? professionalId : null };
}

async function dashboard(req, res, next) {
  try {
    const { from, to, professionalId } = filters(req);
    const params = [req.tenant.id, from, to];
    const professionalSql = professionalId ? ' AND colaborador_id = ?' : '';
    if (professionalId) params.push(professionalId);
    const [[totals]] = await pool.query(
      `SELECT
         COALESCE(SUM(CASE WHEN tipo = 'forecast' AND status = 'posted' THEN valor_liquido ELSE 0 END), 0) forecast,
         COALESCE(SUM(CASE WHEN tipo = 'income' AND status <> 'cancelled' THEN valor_liquido ELSE 0 END), 0) realized,
         COALESCE(SUM(CASE WHEN tipo = 'expense' AND status = 'paid' THEN valor_liquido ELSE 0 END), 0) expenses,
         COALESCE(SUM(CASE WHEN tipo = 'income' AND status IN ('pending','partially_paid') THEN valor_liquido ELSE 0 END), 0) receivable,
         COALESCE(SUM(CASE WHEN tipo = 'refund' AND status = 'posted' THEN valor_liquido ELSE 0 END), 0) refunds
       FROM financial_transactions
       WHERE barbearia_id = ? AND data_competencia BETWEEN ? AND ?${professionalSql}`,
      params,
    );
    const paymentParams = [req.tenant.id, from, to];
    if (professionalId) paymentParams.push(professionalId);
    const [[cash]] = await pool.query(
      `SELECT COALESCE(SUM(p.valor), 0) received
         FROM payments p LEFT JOIN agendamentos a ON a.id = p.agendamento_id
        WHERE p.barbearia_id = ? AND p.status IN ('paid','partially_refunded','refunded')
          AND DATE(p.pago_em) BETWEEN ? AND ?${professionalId ? ' AND a.colaborador_id = ?' : ''}`,
      paymentParams,
    );
    const appointmentParams = [req.tenant.id, from, to];
    if (professionalId) appointmentParams.push(professionalId);
    const [[appointments]] = await pool.query(
      `SELECT COUNT(*) total,
              SUM(a.status = 'confirmado') confirmed,
              SUM(a.status = 'concluido') completed,
              SUM(a.status = 'cancelado') cancelled
         FROM agendamentos a JOIN colaboradores c ON c.id = a.colaborador_id
        WHERE c.barbearia_id = ? AND DATE(a.data_hora) BETWEEN ? AND ?${professionalId ? ' AND a.colaborador_id = ?' : ''}`,
      appointmentParams,
    );
    const realized = Number(totals.realized);
    const expenses = Number(totals.expenses);
    const received = Number(cash.received);
    const completed = Number(appointments.completed || 0);
    return res.json({ data: {
      period: { from, to }, forecast: Number(totals.forecast), realized, received,
      expenses, balance: received - expenses - Number(totals.refunds),
      receivable: Number(totals.receivable), refunds: Number(totals.refunds),
      cancellations: Number(appointments.cancelled || 0), averageTicket: completed ? realized / completed : 0,
      appointments: { total: Number(appointments.total), confirmed: Number(appointments.confirmed || 0), completed, cancelled: Number(appointments.cancelled || 0) },
    }, requestId: req.requestId });
  } catch (error) { return next(error); }
}

async function transactions(req, res, next) {
  try {
    const { from, to, professionalId } = filters(req);
    const page = Math.max(1, Number.parseInt(req.query.page, 10) || 1);
    const limit = Math.min(100, Math.max(1, Number.parseInt(req.query.limit, 10) || 25));
    const where = ['ft.barbearia_id = ?', 'ft.data_competencia BETWEEN ? AND ?'];
    const params = [req.tenant.id, from, to];
    if (professionalId) { where.push('ft.colaborador_id = ?'); params.push(professionalId); }
    if (['forecast','income','expense','refund','reversal'].includes(req.query.type)) { where.push('ft.tipo = ?'); params.push(req.query.type); }
    if (['pending','posted','partially_paid','paid','cancelled','reversed'].includes(req.query.status)) { where.push('ft.status = ?'); params.push(req.query.status); }
    const [rows] = await pool.query(
      `SELECT ft.id, ft.tipo type, ft.status, ft.descricao description, ft.valor_bruto gross_amount,
              ft.valor_desconto discount_amount, ft.valor_taxa fee_amount, ft.valor_liquido net_amount,
              ft.data_competencia competence_date, ft.data_vencimento due_date, ft.pago_em paid_at,
              ft.agendamento_id appointment_id, u.nome professional, cl.nome client, fc.nome category
         FROM financial_transactions ft
         LEFT JOIN colaboradores c ON c.id = ft.colaborador_id
         LEFT JOIN usuarios u ON u.id = c.usuario_id
         LEFT JOIN usuarios cl ON cl.id = ft.cliente_id
         LEFT JOIN financial_categories fc ON fc.id = ft.category_id
        WHERE ${where.join(' AND ')} ORDER BY ft.data_competencia DESC, ft.id DESC LIMIT ? OFFSET ?`,
      [...params, limit, (page - 1) * limit],
    );
    const [[count]] = await pool.query(`SELECT COUNT(*) total FROM financial_transactions ft WHERE ${where.join(' AND ')}`, params);
    return res.json({ data: rows, pagination: { page, limit, total: Number(count.total), pages: Math.ceil(Number(count.total) / limit) }, requestId: req.requestId });
  } catch (error) { return next(error); }
}

async function metadata(req, res, next) {
  try {
    const [accounts] = await pool.query('SELECT id, nome name, tipo type, ativo active FROM financial_accounts WHERE barbearia_id = ? ORDER BY nome', [req.tenant.id]);
    const [categories] = await pool.query('SELECT id, nome name, tipo type, ativo active FROM financial_categories WHERE barbearia_id = ? ORDER BY tipo, nome', [req.tenant.id]);
    return res.json({ data: { accounts, categories }, requestId: req.requestId });
  } catch (error) { return next(error); }
}

async function appointments(req, res, next) {
  try {
    const { from, to, professionalId } = filters(req);
    const where = ['c.barbearia_id = ?', 'DATE(a.data_hora) BETWEEN ? AND ?'];
    const params = [req.tenant.id, from, to];
    if (professionalId) { where.push('a.colaborador_id = ?'); params.push(professionalId); }
    if (['pendente','confirmado','concluido','cancelado'].includes(req.query.status)) { where.push('a.status = ?'); params.push(req.query.status); }
    const [rows] = await pool.query(
      `SELECT a.id, a.data_hora, a.status, a.valor_cobrado amount, a.duracao_min,
              cl.nome client, p.nome professional, s.nome service,
              ft.status financial_status, pay.metodo payment_method, pay.status payment_status,
              pay.valor received_amount, fd.status fiscal_status
         FROM agendamentos a
         JOIN colaboradores c ON c.id = a.colaborador_id
         JOIN usuarios p ON p.id = c.usuario_id JOIN usuarios cl ON cl.id = a.cliente_id
         JOIN servicos s ON s.id = a.servico_id
         LEFT JOIN financial_transactions ft ON ft.agendamento_id = a.id AND ft.tipo = 'income'
         LEFT JOIN payment_allocations pa ON pa.financial_transaction_id = ft.id
         LEFT JOIN payments pay ON pay.id = pa.payment_id
         LEFT JOIN fiscal_documents fd ON fd.agendamento_id = a.id
        WHERE ${where.join(' AND ')} ORDER BY a.data_hora DESC LIMIT 100`, params,
    );
    return res.json({ data: rows, requestId: req.requestId });
  } catch (error) { return next(error); }
}

async function professionals(req, res, next) {
  try {
    const { from, to } = period(req.query);
    const [rows] = await pool.query(
      `SELECT c.id professional_id, u.nome professional, COUNT(DISTINCT a.id) total,
              COUNT(DISTINCT CASE WHEN a.status = 'confirmado' THEN a.id END) confirmed,
              COUNT(DISTINCT CASE WHEN a.status = 'concluido' THEN a.id END) completed,
              COUNT(DISTINCT CASE WHEN a.status = 'cancelado' THEN a.id END) cancelled,
              COALESCE(SUM(CASE WHEN ft.tipo = 'income' AND ft.status <> 'cancelled' THEN ft.valor_liquido ELSE 0 END), 0) realized,
              COALESCE(SUM(CASE WHEN ft.tipo = 'forecast' AND ft.status = 'posted' THEN ft.valor_liquido ELSE 0 END), 0) forecast,
              COALESCE(SUM(CASE WHEN pay.status IN ('paid','partially_refunded','refunded') THEN pay.valor ELSE 0 END), 0) received
         FROM colaboradores c JOIN usuarios u ON u.id = c.usuario_id
         LEFT JOIN agendamentos a ON a.colaborador_id = c.id AND DATE(a.data_hora) BETWEEN ? AND ?
         LEFT JOIN financial_transactions ft ON ft.agendamento_id = a.id
         LEFT JOIN payment_allocations pa ON pa.financial_transaction_id = ft.id
         LEFT JOIN payments pay ON pay.id = pa.payment_id
        WHERE c.barbearia_id = ? GROUP BY c.id, u.nome ORDER BY realized DESC`,
      [from, to, req.tenant.id],
    );
    return res.json({ data: rows.map((row) => ({ ...row, average_ticket: Number(row.completed) ? Number(row.realized) / Number(row.completed) : 0 })), requestId: req.requestId });
  } catch (error) { return next(error); }
}

async function createExpense(req, res, next) {
  const amount = cents(req.body.amount);
  const description = String(req.body.description || '').trim();
  const categoryName = String(req.body.category || '').trim();
  const competence = /^\d{4}-\d{2}-\d{2}$/.test(req.body.competence_date || '') ? req.body.competence_date : null;
  const dueDate = /^\d{4}-\d{2}-\d{2}$/.test(req.body.due_date || '') ? req.body.due_date : competence;
  const status = req.body.status === 'paid' ? 'paid' : 'pending';
  if (amount == null || amount <= 0n || !description || description.length > 240 || !categoryName || categoryName.length > 80 || !competence) {
    return res.status(422).json(errorBody(req, 'VALIDATION_ERROR', 'Descrição, categoria, valor e competência devem ser válidos.'));
  }
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const category = await categoryId(connection, req.tenant.id, categoryName, 'expense');
    const account = status === 'paid' ? await accountId(connection, req.tenant.id) : null;
    const sourceId = crypto.randomUUID();
    const [result] = await connection.query(
      `INSERT INTO financial_transactions
         (barbearia_id, tipo, status, category_id, account_id, source_type, source_id, descricao,
          valor_bruto, valor_liquido, data_competencia, data_vencimento, pago_em, criado_por)
       VALUES (?, 'expense', ?, ?, ?, 'manual_expense', ?, ?, ?, ?, ?, ?, ${status === 'paid' ? 'NOW()' : 'NULL'}, ?)`,
      [req.tenant.id, status, category, account, sourceId, description, decimal(amount), decimal(amount), competence, dueDate, req.usuario.id],
    );
    await postEntry(connection, {
      tenantId: req.tenant.id, actorId: req.usuario.id, financialTransactionId: result.insertId,
      sourceType: 'expense', sourceId: result.insertId, description, competenceDate: competence,
      debit: { code: '4.9', name: categoryName, nature: 'expense' },
      credit: { code: status === 'paid' ? '1.1' : '2.1', name: status === 'paid' ? 'Caixa' : 'Contas a pagar', nature: status === 'paid' ? 'asset' : 'liability' },
      amount: decimal(amount),
    });
    await connection.query(
      `INSERT INTO audit_logs (barbearia_id, usuario_id, acao, recurso, recurso_id, request_id, detalhes)
       VALUES (?, ?, 'expense.created', 'financial_transaction', ?, ?, JSON_OBJECT('amount', ?, 'category', ?))`,
      [req.tenant.id, req.usuario.id, String(result.insertId), req.requestId, decimal(amount), categoryName],
    );
    await connection.commit();
    return res.status(201).json({ data: { id: result.insertId }, message: 'Despesa registrada.', requestId: req.requestId });
  } catch (error) { await connection.rollback().catch(() => {}); return next(error); }
  finally { connection.release(); }
}

async function payment(req, res, next) {
  try {
    const result = await registerPayment({
      tenantId: req.tenant.id, actorId: req.usuario.id,
      appointmentId: Number.parseInt(req.body.appointment_id, 10), method: req.body.method,
      amount: req.body.amount, idempotencyKey: req.headers['x-idempotency-key'],
    });
    if (result.status >= 400) return res.status(result.status).json(errorBody(req, result.code, result.code === 'FULL_PAYMENT_REQUIRED' ? `Pagamento integral exigido: R$ ${result.outstanding}.` : 'Não foi possível registrar o pagamento.'));
    return res.status(result.status).json({ data: { id: result.paymentId }, idempotent: !!result.idempotent, requestId: req.requestId });
  } catch (error) { return next(error); }
}

async function refund(req, res, next) {
  const amount = cents(req.body.amount);
  const reason = String(req.body.reason || '').trim();
  const key = String(req.headers['x-idempotency-key'] || '').trim();
  const paymentId = Number.parseInt(req.params.id, 10);
  if (amount == null || amount <= 0n || reason.length < 3 || reason.length > 240 || !/^[a-zA-Z0-9._:-]{8,100}$/.test(key)) {
    return res.status(422).json(errorBody(req, 'VALIDATION_ERROR', 'Valor, motivo e chave de idempotência são obrigatórios.'));
  }
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const [existing] = await connection.query('SELECT id, status FROM refunds WHERE idempotency_key = ? FOR UPDATE', [key]);
    if (existing.length) { await connection.commit(); return res.json({ data: { id: existing[0].id }, idempotent: true, requestId: req.requestId }); }
    const [payments] = await connection.query(
      `SELECT id, valor, agendamento_id, status FROM payments
        WHERE id = ? AND barbearia_id = ? AND status IN ('paid','partially_refunded') FOR UPDATE`,
      [paymentId, req.tenant.id],
    );
    if (!payments.length) { await connection.rollback(); return res.status(404).json(errorBody(req, 'PAYMENT_NOT_FOUND', 'Pagamento não encontrado.')); }
    const [[total]] = await connection.query(
      `SELECT COALESCE(SUM(valor), 0) refunded FROM refunds WHERE payment_id = ? AND status = 'processed'`, [paymentId],
    );
    const available = cents(payments[0].valor) - cents(total.refunded);
    if (amount > available) { await connection.rollback(); return res.status(422).json(errorBody(req, 'REFUND_EXCEEDS_PAYMENT', 'Reembolso supera valor disponível.')); }
    const [result] = await connection.query(
      `INSERT INTO refunds (payment_id, idempotency_key, status, valor, motivo, processado_em)
       VALUES (?, ?, 'processed', ?, ?, NOW())`, [paymentId, key, decimal(amount), reason],
    );
    const finalStatus = amount === available ? 'refunded' : 'partially_refunded';
    await connection.query('UPDATE payments SET status = ? WHERE id = ?', [finalStatus, paymentId]);
    const [transaction] = await connection.query(
      `INSERT INTO financial_transactions
         (barbearia_id, tipo, status, agendamento_id, source_type, source_id, descricao,
          valor_bruto, valor_liquido, data_competencia, pago_em, criado_por)
       VALUES (?, 'refund', 'posted', ?, 'refund', ?, ?, ?, ?, CURRENT_DATE, NOW(), ?)`,
      [req.tenant.id, payments[0].agendamento_id, String(result.insertId), reason, decimal(amount), decimal(amount), req.usuario.id],
    );
    await connection.query(
      `INSERT INTO cash_entries (barbearia_id, payment_id, criado_por, tipo, categoria, descricao, valor, ocorrido_em)
       VALUES (?, ?, ?, 'refund', 'Reembolso', ?, ?, NOW())`,
      [req.tenant.id, paymentId, req.usuario.id, reason, decimal(amount)],
    );
    await postEntry(connection, {
      tenantId: req.tenant.id, actorId: req.usuario.id, financialTransactionId: transaction.insertId,
      sourceType: 'refund', sourceId: result.insertId, description: reason, competenceDate: new Date().toISOString().slice(0, 10),
      debit: { code: '3.9', name: 'Deducoes e reembolsos', nature: 'revenue' },
      credit: { code: '1.1', name: 'Caixa', nature: 'asset' }, amount: decimal(amount),
    });
    await connection.query(
      `INSERT INTO audit_logs (barbearia_id, usuario_id, acao, recurso, recurso_id, request_id, detalhes)
       VALUES (?, ?, 'payment.refunded', 'refund', ?, ?, JSON_OBJECT('paymentId', ?, 'amount', ?, 'reason', ?))`,
      [req.tenant.id, req.usuario.id, String(result.insertId), req.requestId, paymentId, decimal(amount), reason],
    );
    await connection.commit();
    return res.status(201).json({ data: { id: result.insertId, payment_status: finalStatus }, requestId: req.requestId });
  } catch (error) { await connection.rollback().catch(() => {}); return next(error); }
  finally { connection.release(); }
}

module.exports = { dashboard, transactions, metadata, appointments, professionals, createExpense, payment, refund };
