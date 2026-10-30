// * Ajustes sao eventos compensatorios auditaveis; nao editam o lancamento
// * original e exigem idempotency-key para evitar duplicacao.
const { pool } = require('../config/database');

function parseSignedAmount(value) {
  const text = String(value ?? '').trim();
  if (!/^-?\d+(?:\.\d{1,2})?$/.test(text)) return null;
  const negative = text.startsWith('-');
  const unsigned = negative ? text.slice(1) : text;
  const [whole, fraction = ''] = unsigned.split('.');
  const cents = BigInt(whole) * 100n + BigInt((fraction + '00').slice(0, 2));
  return negative ? -cents : cents;
}

function decimal(cents) {
  const sign = cents < 0n ? '-' : '';
  const absolute = cents < 0n ? -cents : cents;
  return `${sign}${absolute / 100n}.${(absolute % 100n).toString().padStart(2, '0')}`;
}

// * ADICIONAR: cria ajuste positivo/negativo validando o entitlement do tenant.
async function createAdjustment({ tenantId, actorId, entitlementId, amount, reason, idempotencyKey, effectiveAt }) {
  const entitlement = Number.parseInt(entitlementId, 10);
  const signedAmount = parseSignedAmount(amount);
  const note = String(reason || '').trim();
  const key = String(idempotencyKey || '').trim();
  if (!Number.isInteger(entitlement) || entitlement <= 0 || signedAmount == null || signedAmount === 0n || note.length < 3 || note.length > 240 || !/^[a-zA-Z0-9._:-]{8,100}$/.test(key)) {
    return { status: 422, code: 'VALIDATION_ERROR' };
  }
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const [[existing]] = await connection.query(
      'SELECT id FROM commission_entries WHERE barbearia_id = ? AND idempotency_key = ? FOR UPDATE',
      [tenantId, key],
    );
    if (existing) {
      await connection.commit();
      return { status: 200, id: existing.id, idempotent: true };
    }
    const [[row]] = await connection.query(
      `SELECT id, profissional_id, agendamento_id
         FROM commission_entitlements
        WHERE id = ? AND barbearia_id = ?
        FOR UPDATE`,
      [entitlement, tenantId],
    );
    if (!row) {
      await connection.rollback();
      return { status: 404, code: 'ENTITLEMENT_NOT_FOUND' };
    }
    const [entry] = await connection.query(
      `INSERT INTO commission_entries
        (barbearia_id, entitlement_id, profissional_id, agendamento_id, kind,
         signed_amount, source_event_id, idempotency_key, reason, criado_por, effective_at)
       VALUES (?, ?, ?, ?, 'manual_adjustment', ?, ?, ?, ?, ?, ?)`,
      [tenantId, row.id, row.profissional_id, row.agendamento_id, decimal(signedAmount),
        `manual-adjustment:${row.id}:${key}`, key, note, actorId, effectiveAt || new Date()],
    );
    await connection.query(
      `INSERT INTO audit_logs
        (barbearia_id, usuario_id, acao, recurso, recurso_id, detalhes)
       VALUES (?, ?, 'commission.adjustment.created', 'commission_entry', ?, JSON_OBJECT('amount', ?, 'reason', ?, 'entitlementId', ?))`,
      [tenantId, actorId, String(entry.insertId), decimal(signedAmount), note, row.id],
    );
    await connection.commit();
    return { status: 201, id: entry.insertId };
  } catch (error) {
    await connection.rollback().catch(() => {});
    if (error.code === 'ER_DUP_ENTRY') return { status: 409, code: 'ADJUSTMENT_CONFLICT' };
    throw error;
  } finally {
    connection.release();
  }
}

module.exports = { createAdjustment };
