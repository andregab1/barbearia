const { pool } = require('../config/database');
const crypto = require('crypto');

function approvalMode(value) {
  return value === 'automatic' ? 'automatic' : 'manual';
}

function stableJson(value) {
  if (Array.isArray(value)) return `[${value.map(stableJson).sort().join(',')}]`;
  if (value && typeof value === 'object') {
    return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${stableJson(value[key])}`).join(',')}}`;
  }
  return JSON.stringify(value);
}

function payloadHash(value) {
  return crypto.createHash('sha256').update(stableJson(value)).digest('hex');
}

async function ensureSettings(connection, tenantId) {
  await connection.query(
    `INSERT INTO commission_settings (barbearia_id, approval_mode, version)
     VALUES (?, 'manual', 1) ON DUPLICATE KEY UPDATE barbearia_id = VALUES(barbearia_id)`,
    [tenantId],
  );
  const [[row]] = await connection.query(
    'SELECT barbearia_id, approval_mode, version FROM commission_settings WHERE barbearia_id = ? FOR UPDATE',
    [tenantId],
  );
  return row;
}

async function getApprovalMode(connection, tenantId) {
  const row = await ensureSettings(connection, tenantId);
  return approvalMode(row.approval_mode);
}

async function getSettings({ tenantId }) {
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const row = await ensureSettings(connection, tenantId);
    await connection.commit();
    return {
      approvalMode: approvalMode(row.approval_mode),
      version: Number(row.version),
      appliesTo: 'new_commissions',
    };
  } catch (error) {
    await connection.rollback().catch(() => {});
    throw error;
  } finally {
    connection.release();
  }
}

async function updateSettings({ tenantId, actorId, mode, expectedVersion }) {
  const nextMode = approvalMode(mode);
  const expected = Number(expectedVersion);
  if (!Number.isInteger(expected) || expected < 1) return { status: 422, code: 'INVALID_VERSION' };
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const current = await ensureSettings(connection, tenantId);
    if (Number(current.version) !== expected) {
      await connection.rollback();
      return { status: 409, code: 'COMMISSION_SETTINGS_VERSION_CONFLICT' };
    }
    const nextVersion = Number(current.version) + 1;
    await connection.query(
      `UPDATE commission_settings
          SET approval_mode = ?, version = ?, updated_by = ?, updated_at = CURRENT_TIMESTAMP
        WHERE barbearia_id = ? AND version = ?`,
      [nextMode, nextVersion, actorId, tenantId, expected],
    );
    await connection.query(
      `INSERT INTO audit_logs (barbearia_id, usuario_id, acao, recurso, recurso_id, detalhes)
       VALUES (?, ?, 'commission.settings.updated', 'commission_settings', ?, JSON_OBJECT('previousMode', ?, 'mode', ?, 'previousVersion', ?, 'version', ?))`,
      [tenantId, actorId, String(tenantId), current.approval_mode, nextMode, expected, nextVersion],
    );
    await connection.commit();
    return { status: 200, approvalMode: nextMode, version: nextVersion, appliesTo: 'new_commissions' };
  } catch (error) {
    await connection.rollback().catch(() => {});
    throw error;
  } finally {
    connection.release();
  }
}

function shouldAutoApprove(input) {
  return input.approvalMode === 'automatic'
    && input.approvalStatus === 'pending'
    && input.eligibilityStatus === 'eligible'
    && !input.cancelled
    && !input.hasBlockingIssue;
}

module.exports = { approvalMode, payloadHash, ensureSettings, getApprovalMode, getSettings, updateSettings, shouldAutoApprove };
