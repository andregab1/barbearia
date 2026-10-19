const crypto = require('crypto');
const { pool } = require('../config/database');
const { postEntry } = require('./accounting.service');
const commissionService = require('./commission.service');

function cents(value) {
  const text = String(value ?? '').trim();
  if (!/^\d{1,10}([.,]\d{1,2})?$/.test(text)) return null;
  const [whole, fraction = ''] = text.replace(',', '.').split('.');
  const result = BigInt(whole) * 100n + BigInt((fraction + '00').slice(0, 2));
  return result >= 0n && result <= 999999999999n ? result : null;
}

function decimal(valueInCents) {
  return `${valueInCents / 100n}.${String(valueInCents % 100n).padStart(2, '0')}`;
}

async function categoryId(connection, tenantId, name, type) {
  await connection.query(
    `INSERT IGNORE INTO financial_categories (barbearia_id, nome, tipo) VALUES (?, ?, ?)`,
    [tenantId, name, type],
  );
  const [[row]] = await connection.query(
    `SELECT id FROM financial_categories WHERE barbearia_id = ? AND nome = ? AND tipo = ? LIMIT 1`,
    [tenantId, name, type],
  );
  return row.id;
}

async function accountId(connection, tenantId, name = 'Caixa', type = 'cash') {
  await connection.query(
    `INSERT IGNORE INTO financial_accounts (barbearia_id, nome, tipo) VALUES (?, ?, ?)`,
    [tenantId, name, type],
  );
  const [[row]] = await connection.query(
    `SELECT id FROM financial_accounts WHERE barbearia_id = ? AND nome = ? LIMIT 1`,
    [tenantId, name],
  );
  return row.id;
}

async function createForecast(connection, appointment, actorId) {
  const category = await categoryId(connection, appointment.barbearia_id, 'Servicos', 'income');
  await connection.query(
    `INSERT INTO financial_transactions
       (barbearia_id, tipo, status, category_id, agendamento_id, colaborador_id, cliente_id,
        source_type, source_id, descricao, valor_bruto, valor_liquido, data_competencia,
        data_vencimento, criado_por)
     VALUES (?, 'forecast', 'posted', ?, ?, ?, ?, 'appointment', ?, ?, ?, ?, DATE(?), DATE(?), ?)
     ON DUPLICATE KEY UPDATE atualizado_em = atualizado_em`,
    [appointment.barbearia_id, category, appointment.id, appointment.colaborador_id,
      appointment.cliente_id, String(appointment.id), `Previsao: ${appointment.servico}`,
      appointment.valor_cobrado, appointment.valor_cobrado, appointment.data_hora,
      appointment.data_hora, actorId],
  );
}

async function completeAppointment({ appointmentId, actorId, allowedProfessionalId = null, tenantId }) {
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const [rows] = await connection.query(
      `SELECT a.id, a.status, a.cliente_id, a.colaborador_id, a.data_hora, a.valor_cobrado,
              c.barbearia_id, s.nome AS servico
         FROM agendamentos a
         JOIN colaboradores c ON c.id = a.colaborador_id
         JOIN servicos s ON s.id = a.servico_id
        WHERE a.id = ? AND c.barbearia_id = ? FOR UPDATE`,
      [appointmentId, tenantId],
    );
    if (rows.length === 0) { await connection.rollback(); return { status: 404, code: 'APPOINTMENT_NOT_FOUND' }; }
    const appointment = rows[0];
    if (allowedProfessionalId != null && Number(appointment.colaborador_id) !== Number(allowedProfessionalId)) {
      await connection.rollback();
      return { status: 403, code: 'APPOINTMENT_FORBIDDEN' };
    }
    if (appointment.status === 'concluido') { await connection.rollback(); return { status: 200, code: 'APPOINTMENT_ALREADY_COMPLETED', idempotent: true }; }
    if (!['confirmado', 'cliente_chegou', 'em_atendimento'].includes(appointment.status)) { await connection.rollback(); return { status: 409, code: 'APPOINTMENT_STATE_CONFLICT' }; }

    await createForecast(connection, appointment, actorId);
    await connection.query(
      `UPDATE agendamentos SET status = 'concluido', concluido_em = NOW() WHERE id = ? AND status IN ('confirmado', 'cliente_chegou', 'em_atendimento')`,
      [appointment.id],
    );
    await commissionService.reconcileAppointment(connection, { tenantId, appointmentId: appointment.id, actorId });
    await connection.query(
      `UPDATE financial_transactions SET status = 'cancelled'
        WHERE barbearia_id = ? AND source_type = 'appointment' AND source_id = ? AND tipo = 'forecast'`,
      [tenantId, String(appointment.id)],
    );
    const category = await categoryId(connection, tenantId, 'Servicos', 'income');
    const [incomeResult] = await connection.query(
      `INSERT INTO financial_transactions
         (barbearia_id, tipo, status, category_id, agendamento_id, colaborador_id, cliente_id,
          source_type, source_id, descricao, valor_bruto, valor_liquido, data_competencia,
          data_vencimento, criado_por)
       VALUES (?, 'income', 'pending', ?, ?, ?, ?, 'appointment', ?, ?, ?, ?, DATE(?), DATE(?), ?)
       ON DUPLICATE KEY UPDATE id = LAST_INSERT_ID(id), atualizado_em = atualizado_em`,
      [tenantId, category, appointment.id, appointment.colaborador_id, appointment.cliente_id,
        String(appointment.id), appointment.servico, appointment.valor_cobrado,
        appointment.valor_cobrado, appointment.data_hora, appointment.data_hora, actorId],
    );
    await postEntry(connection, {
      tenantId, actorId, financialTransactionId: incomeResult.insertId,
      sourceType: 'appointment_completed', sourceId: appointment.id,
      description: appointment.servico, competenceDate: appointment.data_hora,
      debit: { code: '1.3', name: 'Contas a receber', nature: 'asset' },
      credit: { code: '3.1', name: 'Receita de servicos', nature: 'revenue' },
      amount: appointment.valor_cobrado,
    });
    await connection.query(
      `INSERT IGNORE INTO outbox_events
         (barbearia_id, tipo, aggregate_type, aggregate_id, payload)
       VALUES (?, 'APPOINTMENT_COMPLETED', 'appointment', ?, JSON_OBJECT('appointmentId', ?))`,
      [tenantId, String(appointment.id), appointment.id],
    );
    await connection.query(
      `INSERT INTO audit_logs (barbearia_id, usuario_id, acao, recurso, recurso_id, detalhes)
       VALUES (?, ?, 'appointment.completed', 'appointment', ?, JSON_OBJECT('amount', ?))`,
      [tenantId, actorId, String(appointment.id), appointment.valor_cobrado],
    );
    await connection.commit();
    return { status: 200, code: 'APPOINTMENT_COMPLETED' };
  } catch (error) {
    await connection.rollback().catch(() => {});
    throw error;
  } finally {
    connection.release();
  }
}

async function registerPayment({ tenantId, actorId, appointmentId, method, amount, idempotencyKey }) {
  const amountCents = cents(amount);
  if (amountCents == null || amountCents <= 0n) return { status: 422, code: 'INVALID_AMOUNT' };
  if (!['pix', 'credit_card', 'debit_card', 'cash', 'other'].includes(method)) return { status: 422, code: 'INVALID_PAYMENT_METHOD' };
  const key = String(idempotencyKey || '').trim();
  if (!/^[a-zA-Z0-9._:-]{8,100}$/.test(key)) return { status: 422, code: 'INVALID_IDEMPOTENCY_KEY' };
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const [existing] = await connection.query(
      `SELECT id, agendamento_id, valor, status FROM payments WHERE idempotency_key = ? FOR UPDATE`, [key],
    );
    if (existing.length > 0) {
      if (Number(existing[0].agendamento_id) !== Number(appointmentId)) { await connection.rollback(); return { status: 409, code: 'IDEMPOTENCY_CONFLICT' }; }
      await connection.commit();
      return { status: 200, code: 'PAYMENT_ALREADY_REGISTERED', paymentId: existing[0].id, idempotent: true };
    }
    const [transactions] = await connection.query(
      `SELECT ft.id, ft.valor_liquido, ft.status, a.cliente_id
         FROM financial_transactions ft
         JOIN agendamentos a ON a.id = ft.agendamento_id
        WHERE ft.barbearia_id = ? AND ft.agendamento_id = ? AND ft.tipo = 'income'
          AND ft.status IN ('pending','partially_paid') FOR UPDATE`,
      [tenantId, appointmentId],
    );
    if (transactions.length === 0) { await connection.rollback(); return { status: 409, code: 'RECEIVABLE_NOT_FOUND' }; }
    const transaction = transactions[0];
    const [allocatedRows] = await connection.query(
      `SELECT COALESCE(SUM(pa.valor), 0) AS allocated
         FROM payment_allocations pa JOIN payments p ON p.id = pa.payment_id
        WHERE pa.financial_transaction_id = ? AND p.status IN ('authorized','paid','partially_refunded')`,
      [transaction.id],
    );
    const outstanding = cents(transaction.valor_liquido) - cents(allocatedRows[0].allocated || '0.00');
    if (amountCents !== outstanding) { await connection.rollback(); return { status: 422, code: 'FULL_PAYMENT_REQUIRED', outstanding: decimal(outstanding) }; }
    const [result] = await connection.query(
      `INSERT INTO payments
         (barbearia_id, agendamento_id, usuario_id, provedor, idempotency_key, tipo, metodo, status, valor, pago_em)
       VALUES (?, ?, ?, 'manual', ?, 'service', ?, 'paid', ?, NOW())`,
      [tenantId, appointmentId, transaction.cliente_id, key, method, decimal(amountCents)],
    );
    await connection.query(
      `INSERT INTO payment_allocations (barbearia_id, payment_id, financial_transaction_id, valor) VALUES (?, ?, ?, ?)`,
      [tenantId, result.insertId, transaction.id, decimal(amountCents)],
    );
    await connection.query(
      `UPDATE financial_transactions SET status = 'paid', pago_em = NOW() WHERE id = ?`, [transaction.id],
    );
    await commissionService.reconcileAppointment(connection, { tenantId, appointmentId, actorId });
    await postEntry(connection, {
      tenantId, actorId, financialTransactionId: transaction.id,
      sourceType: 'payment', sourceId: result.insertId,
      description: 'Recebimento de atendimento', competenceDate: new Date().toISOString().slice(0, 10),
      debit: { code: method === 'cash' ? '1.1' : '1.2', name: method === 'cash' ? 'Caixa' : 'Bancos', nature: 'asset' },
      credit: { code: '1.3', name: 'Contas a receber', nature: 'asset' }, amount: decimal(amountCents),
    });
    await connection.query(
      `INSERT IGNORE INTO cash_entries
         (barbearia_id, payment_id, appointment_id, criado_por, tipo, categoria, descricao, valor, ocorrido_em)
       VALUES (?, ?, ?, ?, 'income', 'Atendimento', 'Pagamento de atendimento', ?, NOW())`,
      [tenantId, result.insertId, appointmentId, actorId, decimal(amountCents)],
    );
    await connection.query(
      `INSERT INTO audit_logs (barbearia_id, usuario_id, acao, recurso, recurso_id, detalhes)
       VALUES (?, ?, 'payment.registered', 'payment', ?, JSON_OBJECT('amount', ?, 'method', ?))`,
      [tenantId, actorId, String(result.insertId), decimal(amountCents), method],
    );
    await connection.query(
      `INSERT IGNORE INTO outbox_events (barbearia_id, tipo, aggregate_type, aggregate_id, payload)
       VALUES (?, 'PAYMENT_CONFIRMED', 'payment', ?, JSON_OBJECT('paymentId', ?, 'appointmentId', ?))`,
      [tenantId, String(result.insertId), result.insertId, appointmentId],
    );
    await connection.commit();
    return { status: 201, code: 'PAYMENT_REGISTERED', paymentId: result.insertId };
  } catch (error) {
    await connection.rollback().catch(() => {});
    if (error.code === 'ER_DUP_ENTRY' || error.code === 'ER_LOCK_DEADLOCK') return { status: 409, code: 'PAYMENT_CONFLICT' };
    throw error;
  } finally {
    connection.release();
  }
}

module.exports = { cents, decimal, createForecast, completeAppointment, registerPayment, categoryId, accountId };
