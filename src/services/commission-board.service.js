// * Quadro operacional de comissoes: monta saldos por profissional e fecha
// * pagamentos com revalidacao de valores e idempotencia.
const { pool } = require('../config/database');
const crypto = require('crypto');
const { parseCents } = require('./commission-calculator');
const { payloadHash } = require('./commission-approval.service');

function positiveId(value) {
  const parsed = Number(value);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : null;
}

function cents(value) {
  try { return parseCents(String(value ?? '0')); } catch (_) { return 0n; }
}

function decimal(value) {
  const sign = value < 0n ? '-' : '';
  const absolute = value < 0n ? -value : value;
  return `${sign}${absolute / 100n}.${(absolute % 100n).toString().padStart(2, '0')}`;
}

function dateOnly(value) {
  const text = String(value || '').slice(0, 10);
  return /^\d{4}-\d{2}-\d{2}$/.test(text) ? text : null;
}

function addDay(value) {
  const date = new Date(`${value}T00:00:00Z`);
  date.setUTCDate(date.getUTCDate() + 1);
  return date.toISOString().slice(0, 10);
}

function period(filters = {}) {
  const from = dateOnly(filters.dateFrom || filters.from) || new Date(Date.UTC(new Date().getUTCFullYear(), new Date().getUTCMonth(), 1)).toISOString().slice(0, 10);
  const toExclusive = dateOnly(filters.dateToExclusive) || addDay(dateOnly(filters.dateTo || filters.to) || new Date().toISOString().slice(0, 10));
  if (toExclusive <= from) return null;
  return { from, toExclusive };
}

function parseJson(value) {
  if (!value) return {};
  if (typeof value === 'object') return value;
  try { return JSON.parse(value); } catch (_) { return {}; }
}

function mapBy(rows, key) {
  const map = new Map();
  for (const row of rows) map.set(String(row[key]), row);
  return map;
}

async function rawEntitlements(connection, tenantId, filters = {}) {
  const range = period(filters);
  if (!range) return { status: 422, code: 'INVALID_PERIOD' };
  const params = [tenantId, `${range.from} 00:00:00`, `${range.toExclusive} 00:00:00`];
  const where = ['ce.barbearia_id = ?', "ce.status <> 'reversed'", 'ce.completed_at >= ?', 'ce.completed_at < ?'];
  const professionalId = positiveId(filters.professionalId);
  const serviceId = positiveId(filters.serviceId);
  if (professionalId != null) { where.push('ce.profissional_id = ?'); params.push(professionalId); }
  if (serviceId != null) { where.push('ce.servico_id = ?'); params.push(serviceId); }
  const [rows] = await connection.query(
    `SELECT ce.id commission_id, ce.barbearia_id, ce.agendamento_id appointment_id,
            ce.servico_id service_id, COALESCE(s.nome, 'Serviço') service_name,
            ce.profissional_id professional_id, u.nome professional_name,
            ce.rule_id rule_id, ce.completed_at completed_at,
            ce.gross_amount gross_amount, ce.discount_amount discount_amount,
            ce.original_net_amount original_net_amount, ce.total_commission total_commission,
            ce.snapshot_json snapshot_json, ce.status entitlement_status,
            ce.approval_mode_snapshot approval_mode_snapshot,
            ce.approval_status approval_status, ce.approved_at approved_at,
            ce.approved_by approved_by, ce.approval_source approval_source,
            a.status appointment_status
       FROM commission_entitlements ce
       JOIN colaboradores c ON c.id = ce.profissional_id AND c.barbearia_id = ce.barbearia_id
       JOIN usuarios u ON u.id = c.usuario_id
       LEFT JOIN servicos s ON s.id = ce.servico_id
       LEFT JOIN agendamentos a ON a.id = ce.agendamento_id
      WHERE ${where.join(' AND ')}
      ORDER BY u.nome, ce.completed_at, ce.id`,
    params,
  );
  return { status: 200, range, rows };
}

async function buildRows(connection, tenantId, filters = {}) {
  const result = await rawEntitlements(connection, tenantId, filters);
  if (result.status >= 400) return result;
  const { rows, range } = result;
  if (!rows.length) return { status: 200, range, rows: [], totals: emptyTotals() };
  const ids = rows.map((row) => row.commission_id);
  const placeholders = ids.map(() => '?').join(',');
  const [entryRows] = await connection.query(
    `SELECT e.id entry_id, e.entitlement_id commission_id, e.profissional_id professional_id,
            e.kind, e.signed_amount amount,
            EXISTS (SELECT 1 FROM commission_settlement_items si WHERE si.entry_id = e.id) settled
       FROM commission_entries e
      WHERE e.barbearia_id = ? AND e.entitlement_id IN (${placeholders})`,
    [tenantId, ...ids],
  );
  const [advanceRows] = await connection.query(
    `SELECT a.id, a.profissional_id professional_id, a.valor amount,
            COALESCE(SUM(aa.amount), 0) allocated
       FROM commission_advances a
       LEFT JOIN commission_advance_allocations aa ON aa.advance_id = a.id
      WHERE a.barbearia_id = ? AND a.status = 'confirmed'
      GROUP BY a.id, a.profissional_id, a.valor`,
    [tenantId],
  );
  const entriesByCommission = new Map();
  for (const entry of entryRows) {
    const list = entriesByCommission.get(String(entry.commission_id)) || [];
    list.push(entry);
    entriesByCommission.set(String(entry.commission_id), list);
  }
  const advanceByProfessional = new Map();
  for (const advance of advanceRows) {
    const current = advanceByProfessional.get(String(advance.professional_id)) || 0n;
    const outstanding = cents(advance.amount) - cents(advance.allocated);
    advanceByProfessional.set(String(advance.professional_id), current + (outstanding > 0n ? outstanding : 0n));
  }
  const professionalRows = new Map();
  for (const entitlement of rows) {
    const entries = entriesByCommission.get(String(entitlement.commission_id)) || [];
    const released = entries.reduce((sum, entry) => sum + cents(entry.amount), 0n);
    const settled = entries.filter((entry) => entry.settled).reduce((sum, entry) => sum + cents(entry.amount), 0n);
    const generated = cents(entitlement.total_commission);
    const pendingRelease = generated > released ? generated - released : 0n;
    const approved = entitlement.approval_status === 'approved';
    const eligible = entitlement.appointment_status === 'concluido'
      && entitlement.entitlement_status !== 'reversed'
      && released > 0n;
    const available = approved && eligible && released > settled ? released - settled : 0n;
    const pendingApproval = eligible && !approved ? released : 0n;
    const key = String(entitlement.professional_id);
    const current = professionalRows.get(key) || {
      professional_id: Number(entitlement.professional_id),
      professional_name: entitlement.professional_name,
      pending_release: 0n,
      pending_approval: 0n,
      available: 0n,
      generated: 0n,
      settled: 0n,
      advance_balance: advanceByProfessional.get(key) || 0n,
      commission_count: 0,
    };
    current.pending_release += pendingRelease;
    current.pending_approval += pendingApproval;
    current.available += available;
    current.generated += generated;
    current.settled += settled;
    current.commission_count += 1;
    professionalRows.set(key, current);
  }
  const paidParams = [tenantId, `${range.from} 00:00:00`, `${range.toExclusive} 00:00:00`];
  const professionalId = positiveId(filters.professionalId);
  const paymentFilter = professionalId == null ? '' : ' AND s.profissional_id = ?';
  if (professionalId != null) paidParams.push(professionalId);
  const [[paid]] = await connection.query(
    `SELECT COALESCE(SUM(sp.amount), 0) amount
       FROM commission_settlement_payments sp
       JOIN commission_settlements s ON s.id = sp.settlement_id
      WHERE sp.barbearia_id = ? AND sp.status = 'confirmed'
        AND sp.paid_at >= ? AND sp.paid_at < ?${paymentFilter}`,
    paidParams,
  );
  const boardRows = [...professionalRows.values()].map((row) => {
    const compensation = row.available < row.advance_balance ? row.available : row.advance_balance;
    return {
      ...row,
      advance_balance: decimal(row.advance_balance),
      compensation: decimal(compensation),
      payable: decimal(row.available - compensation),
      pending_release: decimal(row.pending_release),
      pending_approval: decimal(row.pending_approval),
      available: decimal(row.available),
      generated: decimal(row.generated),
      settled: decimal(row.settled),
      status: row.available !== 0n ? 'available' : row.pending_approval !== 0n ? 'awaiting_approval' : row.pending_release !== 0n ? 'pending_release' : 'settled',
    };
  });
  boardRows.sort((a, b) => a.professional_name.localeCompare(b.professional_name, 'pt-BR'));
  const totals = boardRows.reduce((sum, row) => {
    sum.pendingRelease += cents(row.pending_release);
    sum.pendingApproval += cents(row.pending_approval);
    sum.available += cents(row.available);
    sum.advanceBalance += cents(row.advance_balance);
    sum.payable += cents(row.payable);
    return sum;
  }, { pendingRelease: 0n, pendingApproval: 0n, available: 0n, advanceBalance: 0n, payable: 0n });
  totals.paidPeriod = cents(paid.amount);
  return { status: 200, range, rows: boardRows, totals };
}

function emptyTotals() {
  return { pendingRelease: 0n, pendingApproval: 0n, available: 0n, advanceBalance: 0n, payable: 0n, paidPeriod: 0n };
}

function publicTotals(totals) {
  return {
    pendingReleaseCents: Number(totals.pendingRelease),
    pendingApprovalCents: Number(totals.pendingApproval),
    availableCents: Number(totals.available),
    advanceBalanceCents: Number(totals.advanceBalance),
    payableCents: Number(totals.payable),
    paidPeriodCents: Number(totals.paidPeriod || 0n),
  };
}

// * CONSULTAR: lista profissionais e totais filtrados por tenant e periodo.
async function professionals({ tenantId, filters = {} }) {
  const connection = await pool.getConnection();
  try {
    const result = await buildRows(connection, tenantId, filters);
    if (result.status >= 400) return result;
    const search = String(filters.search || '').trim().toLocaleLowerCase('pt-BR');
    const status = String(filters.status || '').trim();
    const filtered = result.rows.filter((row) => (!search || row.professional_name.toLocaleLowerCase('pt-BR').includes(search)) && (!status || row.status === status));
    const page = Math.max(1, Number(filters.page) || 1);
    const pageSize = Math.min(100, Math.max(1, Number(filters.pageSize) || 25));
    const start = (page - 1) * pageSize;
    return {
      status: 200,
      data: filtered.slice(start, start + pageSize),
      pagination: { page, pageSize, totalItems: filtered.length },
      totals: publicTotals(result.totals),
      period: result.range,
      asOf: new Date().toISOString(),
    };
  } finally { connection.release(); }
}

async function details({ tenantId, professionalId, filters = {} }) {
  const professional = positiveId(professionalId);
  if (professional == null) return { status: 422, code: 'VALIDATION_ERROR' };
  const connection = await pool.getConnection();
  try {
    const result = await rawEntitlements(connection, tenantId, { ...filters, professionalId: professional });
    if (result.status >= 400) return result;
    const ids = result.rows.map((row) => row.commission_id);
    if (!ids.length) return { status: 200, professionalId: professional, period: result.range, items: [] };
    const placeholders = ids.map(() => '?').join(',');
    const [entries] = await connection.query(`SELECT e.id entry_id, e.entitlement_id commission_id, e.kind, e.signed_amount amount, EXISTS (SELECT 1 FROM commission_settlement_items si WHERE si.entry_id = e.id) settled FROM commission_entries e WHERE e.barbearia_id = ? AND e.entitlement_id IN (${placeholders}) ORDER BY e.effective_at, e.id`, [tenantId, ...ids]);
    const byCommission = new Map();
    for (const entry of entries) { const list = byCommission.get(String(entry.commission_id)) || []; list.push(entry); byCommission.set(String(entry.commission_id), list); }
    const firstName = result.rows[0]?.professional_name || '';
    const items = result.rows.map((row) => {
      const itemEntries = byCommission.get(String(row.commission_id)) || [];
      const released = itemEntries.reduce((sum, entry) => sum + cents(entry.amount), 0n);
      const settled = itemEntries.filter((entry) => entry.settled).reduce((sum, entry) => sum + cents(entry.amount), 0n);
      const snapshot = parseJson(row.snapshot_json);
      const rule = snapshot.rule || null;
      const eligible = row.appointment_status === 'concluido' && row.entitlement_status !== 'reversed' && released > 0n;
      return {
        ...row,
        professional_name: row.professional_name,
        base_amount: rule?.type === 'fixed' ? null : rule?.base === 'gross' ? row.gross_amount : row.original_net_amount,
        rule,
        snapshot,
        released_amount: decimal(released),
        settled_amount: decimal(settled),
        remaining_amount: decimal(released > settled ? released - settled : 0n),
        eligible,
        reason: row.entitlement_status === 'pending_rule' ? 'Regra de comissão pendente.' : !eligible ? 'Aguardando conclusão ou recebimento.' : null,
      };
    });
    return { status: 200, professionalId: professional, professionalName: firstName, period: result.range, items };
  } finally { connection.release(); }
}

async function selectedEntries(connection, tenantId, payload) {
  const ids = [...new Set((payload.commissionIds || []).map(positiveId).filter(Boolean))];
  const professionalIds = [...new Set((payload.professionalIds || []).map(positiveId).filter(Boolean))];
  if (!ids.length && !professionalIds.length) return { status: 422, code: 'COMMISSION_SELECTION_REQUIRED' };
  const source = await rawEntitlements(connection, tenantId, { ...payload.filters, professionalId: null });
  if (source.status >= 400) return source;
  const allowed = source.rows.filter((row) => (ids.length ? ids.includes(Number(row.commission_id)) : professionalIds.includes(Number(row.professional_id))));
  if (ids.length && allowed.length !== ids.length) return { status: 403, code: 'COMMISSION_SCOPE_FORBIDDEN' };
  if (!allowed.length) return { status: 409, code: 'NO_COMMISSION_ENTRIES' };
  const placeholders = allowed.map(() => '?').join(',');
  const [entries] = await connection.query(`SELECT e.id entry_id, e.entitlement_id commission_id, e.profissional_id professional_id, e.signed_amount amount FROM commission_entries e JOIN commission_entitlements ce ON ce.id = e.entitlement_id AND ce.barbearia_id = e.barbearia_id WHERE e.barbearia_id = ? AND e.entitlement_id IN (${placeholders}) AND e.kind IN ('release','manual_adjustment','correction') AND e.signed_amount > 0 AND ce.approval_status = 'approved' AND ce.status <> 'reversed' AND NOT EXISTS (SELECT 1 FROM commission_settlement_items si WHERE si.entry_id = e.id) ORDER BY e.profissional_id, e.id`, [tenantId, ...allowed.map((row) => row.commission_id)]);
  if (!entries.length) return { status: 409, code: 'NO_COMMISSION_ENTRIES' };
  return { status: 200, range: source.range, rows: allowed, entries };
}

async function advancesByProfessional(connection, tenantId, professionalId) {
  const [rows] = await connection.query(`SELECT a.id, a.valor amount, COALESCE(SUM(aa.amount), 0) allocated FROM commission_advances a LEFT JOIN commission_advance_allocations aa ON aa.advance_id = a.id WHERE a.barbearia_id = ? AND a.profissional_id = ? AND a.status = 'confirmed' GROUP BY a.id, a.valor ORDER BY a.pago_em, a.id`, [tenantId, professionalId]);
  return rows;
}

async function paymentPreview({ tenantId, actorId, payload }) {
  const connection = await pool.getConnection();
  try {
    const selected = await selectedEntries(connection, tenantId, payload || {});
    if (selected.status >= 400) return selected;
    const byProfessional = new Map();
    for (const entry of selected.entries) {
      const list = byProfessional.get(String(entry.professional_id)) || [];
      list.push(entry);
      byProfessional.set(String(entry.professional_id), list);
    }
    const items = [];
    for (const [professionalId, entries] of byProfessional) {
      const commission = entries.reduce((sum, entry) => sum + cents(entry.amount), 0n);
      const advances = await advancesByProfessional(connection, tenantId, Number(professionalId));
      let advanceBalance = advances.reduce((sum, advance) => sum + (cents(advance.amount) - cents(advance.allocated)), 0n);
      if (advanceBalance < 0n) advanceBalance = 0n;
      const compensation = commission < advanceBalance ? commission : advanceBalance;
      const professional = selected.rows.find((row) => String(row.professional_id) === professionalId);
      items.push({ professionalId: Number(professionalId), professionalName: professional?.professional_name || 'Profissional', commissionCents: Number(commission), advanceCompensationCents: Number(compensation), payableCents: Number(commission - compensation), commissionIds: [...new Set(entries.map((entry) => Number(entry.commission_id)))], entryIds: entries.map((entry) => Number(entry.entry_id)) });
    }
    const previewId = crypto.randomUUID();
    const totalPayable = items.reduce((sum, item) => sum + item.payableCents, 0);
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000);
    const result = { previewId, expiresAt: expiresAt.toISOString(), items, totalPayableCents: totalPayable, period: selected.range };
    await connection.query('INSERT INTO commission_payment_previews (id, barbearia_id, payload_hash, payload_json, result_json, expires_at, created_by) VALUES (?, ?, ?, ?, ?, ?, ?)', [previewId, tenantId, payloadHash(payload || {}), JSON.stringify(payload || {}), JSON.stringify(result), expiresAt.toISOString().slice(0, 19).replace('T', ' '), actorId]);
    return { status: 200, ...result };
  } finally { connection.release(); }
}

async function payBatch({ tenantId, actorId, payload, idempotencyKey }) {
  const key = String(idempotencyKey || '').trim();
  if (!/^[a-zA-Z0-9._:-]{8,120}$/.test(key)) return { status: 422, code: 'IDEMPOTENCY_KEY_REQUIRED' };
  const previewId = String(payload?.previewId || '').trim();
  const paymentDate = dateOnly(payload?.paymentDate) || new Date().toISOString().slice(0, 10);
  const accountId = positiveId(payload?.financialAccountId);
  if (!previewId || !String(payload?.paymentMethod || '').trim()) return { status: 422, code: 'VALIDATION_ERROR' };
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const requestBody = { previewId, paymentDate, paymentMethod: String(payload.paymentMethod), financialAccountId: accountId, note: String(payload.note || '') };
    const hash = payloadHash(requestBody);
    const [[existing]] = await connection.query('SELECT payload_hash, response_json FROM commission_payment_batches WHERE barbearia_id = ? AND idempotency_key = ? FOR UPDATE', [tenantId, key]);
    if (existing) {
      if (existing.payload_hash !== hash) { await connection.rollback(); return { status: 409, code: 'IDEMPOTENCY_CONFLICT' }; }
      await connection.commit();
      return { status: 200, ...parseJson(existing.response_json), idempotent: true };
    }
    const [[previewRow]] = await connection.query('SELECT * FROM commission_payment_previews WHERE id = ? AND barbearia_id = ? FOR UPDATE', [previewId, tenantId]);
    if (!previewRow || new Date(previewRow.expires_at).getTime() <= Date.now()) { await connection.rollback(); return { status: 409, code: 'PREVIEW_EXPIRED' }; }
    const preview = parseJson(previewRow.result_json);
    if (previewRow.payload_hash !== payloadHash(parseJson(previewRow.payload_json))) { await connection.rollback(); return { status: 409, code: 'PREVIEW_INVALID' }; }
    const totalPreviewPayable = Number(preview.totalPayableCents || 0);
    if (totalPreviewPayable > 0 && accountId == null) { await connection.rollback(); return { status: 422, code: 'INVALID_ACCOUNT' }; }
    if (accountId != null) {
      const [[account]] = await connection.query('SELECT id FROM financial_accounts WHERE id = ? AND barbearia_id = ? AND ativo = 1 FOR UPDATE', [accountId, tenantId]);
      if (!account) { await connection.rollback(); return { status: 422, code: 'INVALID_ACCOUNT' }; }
    }
    const outputItems = [];
    for (const item of preview.items || []) {
      const ids = (item.entryIds || []).map(positiveId).filter(Boolean);
      if (!ids.length) continue;
      const placeholders = ids.map(() => '?').join(',');
      const [entries] = await connection.query(`SELECT e.id entry_id, e.entitlement_id commission_id, e.profissional_id professional_id, e.agendamento_id appointment_id, e.signed_amount amount, ce.approval_status, ce.status entitlement_status, a.status appointment_status FROM commission_entries e JOIN commission_entitlements ce ON ce.id = e.entitlement_id AND ce.barbearia_id = e.barbearia_id JOIN agendamentos a ON a.id = e.agendamento_id WHERE e.barbearia_id = ? AND e.id IN (${placeholders}) FOR UPDATE`, [tenantId, ...ids]);
      if (entries.length !== ids.length || entries.some((entry) => entry.approval_status !== 'approved' || entry.entitlement_status === 'reversed' || entry.appointment_status !== 'concluido')) { await connection.rollback(); return { status: 409, code: 'COMMISSION_BALANCE_CHANGED' }; }
      const total = entries.reduce((sum, entry) => sum + cents(entry.amount), 0n);
      if (Number(total) !== Number(item.commissionCents)) { await connection.rollback(); return { status: 409, code: 'COMMISSION_BALANCE_CHANGED' }; }
      const advances = await advancesByProfessional(connection, tenantId, Number(item.professionalId));
      let remaining = total;
      let compensation = 0n;
      for (const advance of advances) {
        if (remaining <= 0n) break;
        const available = cents(advance.amount) - cents(advance.allocated);
        if (available <= 0n) continue;
        const applied = available < remaining ? available : remaining;
        compensation += applied;
        remaining -= applied;
      }
      if (Number(compensation) !== Number(item.advanceCompensationCents)) { await connection.rollback(); return { status: 409, code: 'COMMISSION_BALANCE_CHANGED' }; }
      const [settlement] = await connection.query("INSERT INTO commission_settlements (barbearia_id, profissional_id, periodo_inicio, periodo_fim, status, total_lancamentos, total_adiantamentos, total_pago, saldo_a_pagar, criado_por, fechado_em) VALUES (?, ?, ?, ?, 'closed', ?, ?, 0, ?, ?, NOW())", [tenantId, item.professionalId, `${preview.period.from} 00:00:00`, `${preview.period.toExclusive} 00:00:00`, decimal(total), decimal(compensation), decimal(remaining), actorId]);
      for (const entry of entries) await connection.query('INSERT INTO commission_settlement_items (settlement_id, entry_id, amount) VALUES (?, ?, ?)', [settlement.insertId, entry.entry_id, entry.amount]);
      let advanceRemaining = compensation;
      for (const advance of advances) {
        if (advanceRemaining <= 0n) break;
        const available = cents(advance.amount) - cents(advance.allocated);
        if (available <= 0n) continue;
        const applied = available < advanceRemaining ? available : advanceRemaining;
        await connection.query('INSERT INTO commission_advance_allocations (barbearia_id, advance_id, settlement_id, amount) VALUES (?, ?, ?, ?)', [tenantId, advance.id, settlement.insertId, decimal(applied)]);
        advanceRemaining -= applied;
      }
      let paymentId = null;
      let movementId = null;
      if (remaining > 0n) {
        const paymentKey = `${key}:${item.professionalId}`;
        const [payment] = await connection.query('INSERT INTO commission_settlement_payments (barbearia_id, settlement_id, amount, paid_at, payment_method, financial_account_id, idempotency_key, created_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', [tenantId, settlement.insertId, decimal(remaining), `${paymentDate} 12:00:00`, requestBody.paymentMethod, accountId, paymentKey, actorId]);
        paymentId = payment.insertId;
        const [movement] = await connection.query("INSERT INTO financial_movements (barbearia_id, movement_type, operation, origin_type, origin_id, idempotency_key, professional_id, financial_account_id, amount, movement_date, description, status, created_by) VALUES (?, 'expense', 'commission_settlement_paid', 'manual_adjustment', ?, ?, ?, ?, ?, ?, ?, 'confirmed', ?)", [tenantId, paymentId, paymentKey, item.professionalId, accountId, decimal(remaining), `${paymentDate} 12:00:00`, `Repasse de comissão #${settlement.insertId}`, actorId]);
        movementId = movement.insertId;
        await connection.query('UPDATE commission_settlement_payments SET financial_movement_id = ? WHERE id = ?', [movementId, paymentId]);
      }
      await connection.query("UPDATE commission_settlements SET total_pago = ?, status = 'paid', atualizado_em = CURRENT_TIMESTAMP WHERE id = ?", [decimal(remaining), settlement.insertId]);
      await connection.query(`UPDATE commission_entitlements SET status = 'reserved' WHERE barbearia_id = ? AND id IN (${entries.map(() => '?').join(',')})`, [tenantId, ...entries.map((entry) => entry.commission_id)]);
      await connection.query("INSERT INTO audit_logs (barbearia_id, usuario_id, acao, recurso, recurso_id, detalhes) VALUES (?, ?, 'commission.batch.paid', 'commission_settlement', ?, JSON_OBJECT('total', ?, 'compensation', ?, 'paymentId', ?))", [tenantId, actorId, String(settlement.insertId), decimal(total), decimal(compensation), paymentId]);
      outputItems.push({ professionalId: item.professionalId, settlementId: settlement.insertId, commissionCents: Number(total), advanceCompensationCents: Number(compensation), payableCents: Number(remaining), paymentId, movementId });
    }
    const response = { batchId: crypto.randomUUID(), items: outputItems, totalPayableCents: outputItems.reduce((sum, item) => sum + item.payableCents, 0), paymentDate };
    await connection.query('INSERT INTO commission_payment_batches (barbearia_id, idempotency_key, payload_hash, response_json, created_by) VALUES (?, ?, ?, ?, ?)', [tenantId, key, hash, JSON.stringify(response), actorId]);
    await connection.commit();
    return { status: 201, ...response };
  } catch (error) {
    await connection.rollback().catch(() => {});
    if (error.code === 'ER_DUP_ENTRY' || error.code === 'ER_LOCK_DEADLOCK') return { status: 409, code: 'COMMISSION_PAYMENT_CONFLICT' };
    throw error;
  } finally { connection.release(); }
}

async function approveManual({ tenantId, actorId, commissionIds, idempotencyKey }) {
  const ids = [...new Set((commissionIds || []).map(positiveId).filter(Boolean))];
  const key = String(idempotencyKey || '').trim();
  if (!ids.length || !/^[a-zA-Z0-9._:-]{8,120}$/.test(key)) return { status: 422, code: 'VALIDATION_ERROR' };
  const payload = { commissionIds: ids.sort((a, b) => a - b) };
  const hash = payloadHash(payload);
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const [[existing]] = await connection.query('SELECT payload_hash, response_json FROM commission_approval_requests WHERE barbearia_id = ? AND idempotency_key = ? FOR UPDATE', [tenantId, key]);
    if (existing) {
      if (existing.payload_hash !== hash) { await connection.rollback(); return { status: 409, code: 'IDEMPOTENCY_CONFLICT' }; }
      await connection.commit(); return { status: 200, ...parseJson(existing.response_json), idempotent: true };
    }
    const placeholders = ids.map(() => '?').join(',');
    const [rows] = await connection.query(`SELECT ce.id, ce.approval_mode_snapshot, ce.approval_status, ce.status entitlement_status, a.status appointment_status, COALESCE(SUM(e.signed_amount), 0) released FROM commission_entitlements ce JOIN agendamentos a ON a.id = ce.agendamento_id LEFT JOIN commission_entries e ON e.entitlement_id = ce.id AND e.kind IN ('release','manual_adjustment','correction') WHERE ce.barbearia_id = ? AND ce.id IN (${placeholders}) GROUP BY ce.id, ce.approval_mode_snapshot, ce.approval_status, ce.status, a.status FOR UPDATE`, [tenantId, ...ids]);
    if (rows.length !== ids.length || rows.some((row) => row.approval_mode_snapshot !== 'manual' || row.approval_status !== 'pending' || row.entitlement_status === 'reversed' || row.appointment_status !== 'concluido' || cents(row.released) <= 0n)) { await connection.rollback(); return { status: 409, code: 'COMMISSION_NOT_ELIGIBLE_FOR_APPROVAL' }; }
    await connection.query(`UPDATE commission_entitlements SET approval_status = 'approved', approved_at = CURRENT_TIMESTAMP, approved_by = ?, approval_source = 'manual' WHERE barbearia_id = ? AND id IN (${placeholders}) AND approval_status = 'pending'`, [actorId, tenantId, ...ids]);
    for (const id of ids) await connection.query("INSERT INTO audit_logs (barbearia_id, usuario_id, acao, recurso, recurso_id, detalhes) VALUES (?, ?, 'commission.approved.manual', 'commission_entitlement', ?, JSON_OBJECT('source', 'manual'))", [tenantId, actorId, String(id)]);
    const response = { approvedIds: ids, approvedCount: ids.length };
    await connection.query('INSERT INTO commission_approval_requests (barbearia_id, idempotency_key, payload_hash, response_json, created_by) VALUES (?, ?, ?, ?, ?)', [tenantId, key, hash, JSON.stringify(response), actorId]);
    await connection.commit();
    return { status: 201, ...response };
  } catch (error) { await connection.rollback().catch(() => {}); if (error.code === 'ER_DUP_ENTRY') return { status: 409, code: 'COMMISSION_APPROVAL_CONFLICT' }; throw error; } finally { connection.release(); }
}

async function history({ tenantId, filters = {} }) {
  const from = dateOnly(filters.dateFrom || filters.from);
  const to = dateOnly(filters.dateToExclusive) || (dateOnly(filters.dateTo || filters.to) ? addDay(dateOnly(filters.dateTo || filters.to)) : null);
  const professionalId = positiveId(filters.professionalId);
  const params = [tenantId];
  const dateFilter = from && to ? ' AND created_at >= ? AND created_at < ?' : '';
  if (from && to) params.push(`${from} 00:00:00`, `${to} 00:00:00`);
  const professionalFilter = professionalId == null ? '' : ' AND professional_id = ?';
  if (professionalId != null) params.push(professionalId);
  const [payments] = await pool.query(`SELECT sp.id, sp.created_at, sp.paid_at event_date, 'payment' type, sp.amount, s.profissional_id professional_id, u.nome professional_name, sp.status, sp.created_by FROM commission_settlement_payments sp JOIN commission_settlements s ON s.id = sp.settlement_id JOIN colaboradores c ON c.id = s.profissional_id JOIN usuarios u ON u.id = c.usuario_id WHERE sp.barbearia_id = ?${dateFilter}${professionalFilter}`, params);
  const advanceParams = [tenantId];
  const advanceDateFilter = from && to ? ' AND a.criado_em >= ? AND a.criado_em < ?' : '';
  if (from && to) advanceParams.push(`${from} 00:00:00`, `${to} 00:00:00`);
  const advanceProfessionalFilter = professionalId == null ? '' : ' AND a.profissional_id = ?';
  if (professionalId != null) advanceParams.push(professionalId);
  const [advances] = await pool.query(`SELECT a.id, a.criado_em created_at, a.pago_em event_date, 'advance' type, a.valor amount, a.profissional_id professional_id, u.nome professional_name, a.status, a.criado_por created_by FROM commission_advances a JOIN colaboradores c ON c.id = a.profissional_id JOIN usuarios u ON u.id = c.usuario_id WHERE a.barbearia_id = ?${advanceDateFilter}${advanceProfessionalFilter}`, advanceParams);
  return [...payments, ...advances].filter((item) => !filters.type || item.type === filters.type).sort((a, b) => new Date(b.event_date || b.created_at).getTime() - new Date(a.event_date || a.created_at).getTime());
}

module.exports = { professionals, details, paymentPreview, payBatch, approveManual, history, publicTotals };
