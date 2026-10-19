const { pool } = require('../config/database');

async function requestInvoice({ tenantId, actorId, appointmentId, idempotencyKey }) {
  const key = String(idempotencyKey || '').trim();
  if (!/^[a-zA-Z0-9._:-]{8,100}$/.test(key)) return { status: 422, code: 'INVALID_IDEMPOTENCY_KEY' };
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const [existing] = await connection.query('SELECT id, status FROM fiscal_documents WHERE idempotency_key = ? FOR UPDATE', [key]);
    if (existing.length) { await connection.commit(); return { status: 200, id: existing[0].id, documentStatus: existing[0].status, idempotent: true }; }
    const [rows] = await connection.query(
      `SELECT a.id, a.cliente_id, a.status appointment_status, a.valor_cobrado, a.data_hora,
              c.barbearia_id, u.nome cliente, u.email, u.telefone, s.nome servico,
              ft.id financial_transaction_id, ft.status financial_status,
              p.id payment_id, fs.provedor, fs.ativo
         FROM agendamentos a
         JOIN colaboradores c ON c.id = a.colaborador_id
         JOIN usuarios u ON u.id = a.cliente_id
         JOIN servicos s ON s.id = a.servico_id
         JOIN financial_transactions ft ON ft.agendamento_id = a.id AND ft.tipo = 'income'
         LEFT JOIN payment_allocations pa ON pa.financial_transaction_id = ft.id
         LEFT JOIN payments p ON p.id = pa.payment_id AND p.status IN ('paid','partially_refunded')
         LEFT JOIN fiscal_settings fs ON fs.barbearia_id = c.barbearia_id
        WHERE a.id = ? AND c.barbearia_id = ? FOR UPDATE`,
      [appointmentId, tenantId],
    );
    if (!rows.length) { await connection.rollback(); return { status: 404, code: 'FISCAL_SOURCE_NOT_FOUND' }; }
    const item = rows[0];
    if (item.appointment_status !== 'concluido' || item.financial_status !== 'paid' || !item.payment_id) { await connection.rollback(); return { status: 409, code: 'FISCAL_NOT_ELIGIBLE' }; }
    if (!item.ativo || !item.provedor) { await connection.rollback(); return { status: 409, code: 'FISCAL_NOT_CONFIGURED' }; }
    const snapshot = { appointmentId: item.id, client: { name: item.cliente, email: item.email, phone: item.telefone }, services: [{ name: item.servico, amount: String(item.valor_cobrado) }], competenceDate: String(item.data_hora).slice(0, 10) };
    const [result] = await connection.query(
      `INSERT INTO fiscal_documents
         (barbearia_id, agendamento_id, cliente_id, financial_transaction_id, payment_id,
          provider, idempotency_key, status, total_amount, service_amount, snapshot)
       VALUES (?, ?, ?, ?, ?, ?, ?, 'pending', ?, ?, ?)`,
      [tenantId, item.id, item.cliente_id, item.financial_transaction_id, item.payment_id,
        item.provedor, key, item.valor_cobrado, item.valor_cobrado, JSON.stringify(snapshot)],
    );
    await connection.query(
      `INSERT INTO outbox_events (barbearia_id, tipo, aggregate_type, aggregate_id, payload)
       VALUES (?, 'FISCAL_INVOICE_REQUESTED', 'fiscal_document', ?, JSON_OBJECT('documentId', ?))`,
      [tenantId, String(result.insertId), result.insertId],
    );
    await connection.query(
      `INSERT INTO audit_logs (barbearia_id, usuario_id, acao, recurso, recurso_id, detalhes)
       VALUES (?, ?, 'fiscal.requested', 'fiscal_document', ?, JSON_OBJECT('appointmentId', ?))`,
      [tenantId, actorId, String(result.insertId), item.id],
    );
    await connection.commit();
    return { status: 202, id: result.insertId, documentStatus: 'pending' };
  } catch (error) {
    await connection.rollback().catch(() => {});
    if (error.code === 'ER_DUP_ENTRY') return { status: 409, code: 'FISCAL_DOCUMENT_EXISTS' };
    throw error;
  } finally { connection.release(); }
}

module.exports = { requestInvoice };
