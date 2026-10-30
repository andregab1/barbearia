// * Dominio de regras e lancamentos de comissao. As operacoes de escrita usam
// * transacao, versao e auditoria para nao alterar historico silenciosamente.
const { pool } = require('../config/database');
const { parseCents } = require('./commission-calculator');
const { getApprovalMode, shouldAutoApprove } = require('./commission-approval.service');
function id(value) { const parsed = Number(value); return Number.isInteger(parsed) && parsed > 0 ? parsed : null; }
function date(value) { if (value == null || value === '') return null; const parsed = new Date(value); return Number.isNaN(parsed.getTime()) ? null : parsed; }
function parseBps(value) {
  const text = String(value ?? '').trim().replace(',', '.');
  if (!/^\d{1,3}(?:\.\d{1,2})?$/.test(text)) throw new Error('invalid_bps');
  const [whole, fraction = ''] = text.split('.');
  const bps = BigInt(whole) * 100n + BigInt((fraction + '00').slice(0, 2));
  if (bps > 10000n) throw new Error('invalid_bps');
  return Number(bps);
}
function normalizeRule(data = {}) {
  const professionalId = data.professionalId == null ? null : id(data.professionalId); const serviceId = data.serviceId == null ? null : id(data.serviceId);
  const name = String(data.name || data.nome || 'Regra de comissão').trim();
  const config = data.config && typeof data.config === 'object' ? data.config : {};
  const type = String(data.type || '').trim().toLowerCase(); const base = data.base == null ? null : String(data.base).trim().toLowerCase();
  const validFrom = date(data.validFrom); const validUntil = date(data.validUntil); const valueText = String(data.value ?? '').trim();
  if (name.length < 3 || name.length > 100 || !['percentage', 'fixed'].includes(type) || (professionalId == null && data.professionalId != null) || (serviceId == null && data.serviceId != null)) return { error: 'VALIDATION_ERROR' };
  if (validFrom && validUntil && validUntil <= validFrom) return { error: 'INVALID_VALIDITY' };
  if (type === 'percentage') { let valueBps; try { valueBps = parseBps(valueText); } catch (_) { return { error: 'INVALID_PERCENTAGE' }; } if (!['gross', 'net_after_discount'].includes(base)) return { error: 'INVALID_BASE' }; return { name, config, professionalId, serviceId, type, base, value: valueText, valueBps, validFrom, validUntil }; }
  try { parseCents(valueText); } catch (_) { return { error: 'INVALID_FIXED_VALUE' }; } if (base != null) return { error: 'FIXED_BASE_NOT_ALLOWED' }; return { name, config, professionalId, serviceId, type, base: null, value: valueText, valueBps: null, validFrom, validUntil };
}
function scopeKey(rule) { return String(rule.professionalId || 0) + ':' + String(rule.serviceId || 0); }
async function validateReferences(connection, tenantId, rule) {
  if (rule.professionalId != null) { const [[row]] = await connection.query('SELECT id FROM colaboradores WHERE id = ? AND barbearia_id = ? AND ativo = 1', [rule.professionalId, tenantId]); if (!row) return false; }
  if (rule.serviceId != null) { const [[row]] = await connection.query('SELECT id FROM servicos WHERE id = ? AND barbearia_id = ? AND ativo = 1', [rule.serviceId, tenantId]); if (!row) return false; } return true;
}
// * ADICIONAR: valida referencias, vigencia e sobreposicao antes de criar uma
// * regra versionada para o tenant.
async function createRule({ tenantId, actorId, data }) {
  const rule = normalizeRule(data); if (rule.error) return { status: 422, code: rule.error }; const connection = await pool.getConnection();
  try { await connection.beginTransaction(); if (!await validateReferences(connection, tenantId, rule)) { await connection.rollback(); return { status: 422, code: 'INVALID_RELATION' }; }
    const key = scopeKey(rule); const [[versionRow]] = await connection.query('SELECT COALESCE(MAX(versao), 0) + 1 version FROM commission_rules WHERE barbearia_id = ? AND scope_key = ? FOR UPDATE', [tenantId, key]); const version = Number(versionRow.version);
    const [overlap] = await connection.query('SELECT id FROM commission_rules WHERE barbearia_id = ? AND scope_key = ? AND ativo = 1 AND (valido_ate IS NULL OR ? IS NULL OR valido_de < ?) AND (? IS NULL OR valido_ate IS NULL OR ? < valido_ate) LIMIT 1 FOR UPDATE', [tenantId, key, rule.validUntil, rule.validUntil, rule.validFrom, rule.validFrom]);
    if (overlap.length) { await connection.rollback(); return { status: 409, code: 'COMMISSION_RULE_OVERLAP' }; }
    const lifecycle = rule.validFrom && rule.validFrom > new Date() ? 'scheduled' : 'active';
    const [result] = await connection.query('INSERT INTO commission_rules (nome, config_json, lifecycle, barbearia_id, profissional_id, servico_id, scope_key, tipo, valor, valor_bps, base, valido_de, valido_ate, versao, criado_por) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', [rule.name, JSON.stringify(rule.config), lifecycle, tenantId, rule.professionalId, rule.serviceId, key, rule.type, rule.value, rule.valueBps, rule.base, rule.validFrom, rule.validUntil, version, actorId]);
    await reconcileAppointmentsForRule(connection, { tenantId, actorId, rule });
    await connection.query("INSERT INTO audit_logs (barbearia_id, usuario_id, acao, recurso, recurso_id, detalhes) VALUES (?, ?, 'commission.rule.created', 'commission_rule', ?, JSON_OBJECT('scope', ?, 'version', ?))", [tenantId, actorId, String(result.insertId), key, version]); await connection.commit(); return { status: 201, id: result.insertId, version };
  } catch (error) { await connection.rollback().catch(() => {}); throw error; } finally { connection.release(); }
}
async function listRules(tenantId) { const [rows] = await pool.query('SELECT r.id, r.nome name, r.config_json config, r.lifecycle, r.profissional_id professional_id, r.servico_id service_id, r.tipo type, r.valor value, r.valor_bps value_bps, r.base, r.valido_de valid_from, r.valido_ate valid_until, r.ativo active, r.versao version, r.criado_em created_at, u.nome created_by, p.nome professional_name, s.nome service_name FROM commission_rules r LEFT JOIN colaboradores c ON c.id = r.profissional_id LEFT JOIN usuarios p ON p.id = c.usuario_id LEFT JOIN servicos s ON s.id = r.servico_id LEFT JOIN usuarios u ON u.id = r.criado_por WHERE r.barbearia_id = ? ORDER BY r.valido_de DESC, r.scope_key, r.versao DESC', [tenantId]); const now = Date.now(); return rows.map((row) => { if (typeof row.config === 'string') { try { row.config = JSON.parse(row.config); } catch (_) { row.config = {}; } } row.name = row.name || 'Regra legada'; const from = row.valid_from ? new Date(row.valid_from).getTime() : -Infinity; const until = row.valid_until ? new Date(row.valid_until).getTime() : Infinity; row.lifecycle = row.active ? (now < from ? 'scheduled' : now >= until ? 'ended' : 'active') : 'ended'; return row; }); }

async function getEntryDetail({ tenantId, entryId }) {
  const parsed = id(entryId);
  if (parsed == null) return null;
  const [[entry]] = await pool.query('SELECT e.id, e.entitlement_id, e.profissional_id professional_id, e.agendamento_id appointment_id, e.payment_id, e.refund_id, e.kind, e.signed_amount amount, e.source_event_id, e.reason, e.effective_at, e.criado_em created_at, u.nome professional_name, ce.servico_id service_id, ce.rule_id, ce.completed_at, ce.gross_amount, ce.discount_amount, ce.original_net_amount, ce.total_commission, ce.snapshot_json snapshot, ce.status entitlement_status, s.nome service_name FROM commission_entries e JOIN commission_entitlements ce ON ce.id = e.entitlement_id AND ce.barbearia_id = e.barbearia_id JOIN colaboradores c ON c.id = e.profissional_id AND c.barbearia_id = e.barbearia_id JOIN usuarios u ON u.id = c.usuario_id LEFT JOIN servicos s ON s.id = ce.servico_id WHERE e.id = ? AND e.barbearia_id = ?', [parsed, tenantId]);
  if (!entry) return null;
  if (typeof entry.snapshot === 'string') { try { entry.snapshot = JSON.parse(entry.snapshot); } catch (_) { entry.snapshot = {}; } }
  const [history] = await pool.query('SELECT id, kind, signed_amount amount, source_event_id, reason, effective_at, criado_em created_at FROM commission_entries WHERE barbearia_id = ? AND entitlement_id = ? ORDER BY effective_at, id', [tenantId, entry.entitlement_id]);
  entry.history = history;
  return entry;
}
async function listEntries({ tenantId, professionalId = null, from = null, to = null, ownProfessionalId = null }) { const filters = ['e.barbearia_id = ?']; const params = [tenantId]; const selected = ownProfessionalId != null ? ownProfessionalId : professionalId; if (selected != null) { filters.push('e.profissional_id = ?'); params.push(selected); } if (from) { filters.push('e.effective_at >= ?'); params.push(from); } if (to) { filters.push('e.effective_at < ?'); params.push(to); } const sql = 'SELECT e.id, e.entitlement_id, e.profissional_id professional_id, e.agendamento_id appointment_id, e.payment_id, e.refund_id, e.kind, e.signed_amount amount, e.source_event_id, e.reason, e.effective_at, e.criado_em created_at, u.nome professional_name FROM commission_entries e JOIN colaboradores c ON c.id = e.profissional_id JOIN usuarios u ON u.id = c.usuario_id WHERE ' + filters.join(' AND ') + ' ORDER BY e.effective_at DESC, e.id DESC LIMIT 500'; const [rows] = await pool.query(sql, params); return rows; }
async function summary({ tenantId, professionalId = null, ownProfessionalId = null }) { const selected = ownProfessionalId != null ? ownProfessionalId : professionalId; const params = [tenantId]; const filter = selected == null ? '' : ' AND e.profissional_id = ?'; if (selected != null) params.push(selected); const [rows] = await pool.query('SELECT COALESCE(SUM(CASE WHEN e.kind IN (\'release\',\'manual_adjustment\',\'correction\') THEN e.signed_amount ELSE 0 END), 0) released, COALESCE(SUM(e.signed_amount), 0) balance, COUNT(DISTINCT e.agendamento_id) appointments FROM commission_entries e WHERE e.barbearia_id = ?' + filter, params); return rows[0]; }
module.exports = { normalizeRule, createRule, listRules, listEntries, summary, reconcileAppointment, reconcileEntitlement };
module.exports.getEntryDetail = getEntryDetail;
const { calculateItem, targetReleased, resolveCommissionRule } = require('./commission-calculator');

function centsFromDb(value) { return parseCents(String(value || '0')); }
function decimalFromCents(value) { const sign = value < 0n ? '-' : ''; const abs = value < 0n ? -value : value; return sign + (abs / 100n).toString() + '.' + (abs % 100n).toString().padStart(2, '0'); }
async function findRule(connection, tenantId, professionalId, serviceId, completedAt) {
  const [rows] = await connection.query(
    'SELECT id, profissional_id professionalId, servico_id serviceId, tipo type, valor value, valor_bps valueBps, base, config_json, valido_de validFrom, valido_ate validUntil, versao version, ativo active FROM commission_rules WHERE barbearia_id = ? AND ativo = 1 AND (profissional_id IS NULL OR profissional_id = ?) AND (servico_id IS NULL OR servico_id = ?) AND (valido_de IS NULL OR valido_de <= ?) AND (valido_ate IS NULL OR valido_ate > ?) ORDER BY CASE WHEN profissional_id IS NOT NULL AND servico_id IS NOT NULL THEN 1 WHEN profissional_id IS NOT NULL THEN 2 WHEN servico_id IS NOT NULL THEN 3 ELSE 4 END, versao DESC LIMIT 1',
    [tenantId, professionalId, serviceId, completedAt, completedAt],
  );
  const rule = rows[0] || null;
  if (rule && typeof rule.config_json === 'string') { try { rule.config = JSON.parse(rule.config_json); } catch (_) { rule.config = {}; } }
  return rule;
}
function applyRuleException(rule, serviceId) {
  if (!rule || !rule.config || !Array.isArray(rule.config.exceptions)) return rule;
  const exception = rule.config.exceptions.find((item) => String(item.itemId || item.serviceId || '') === String(serviceId));
  if (!exception || !exception.calculation) return rule;
  const calculation = exception.calculation;
  let valueBps = null;
  if (calculation.model !== 'FIXED_PER_UNIT') { try { valueBps = parseBps(calculation.rate); } catch (_) { return rule; } }
  return { ...rule, type: calculation.model === 'FIXED_PER_UNIT' ? 'fixed' : 'percentage', value: calculation.model === 'FIXED_PER_UNIT' ? calculation.fixedValue : calculation.rate, valueBps, base: calculation.basis === 'GROSS' ? 'gross' : 'net_after_discount', exception_id: exception.itemId || exception.serviceId };
}
async function appointmentItems(connection, tenantId, appointmentId) {
  const [rows] = await connection.query('SELECT a.id appointmentId, a.colaborador_id professionalId, a.cliente_id clientId, a.valor_cobrado appointmentAmount, COALESCE(a.concluido_em, a.data_hora) completedAt, s.id serviceId, s.nome serviceName, COALESCE(ags.preco_cobrado, a.valor_cobrado) grossAmount FROM agendamentos a JOIN colaboradores c ON c.id = a.colaborador_id LEFT JOIN agendamento_servicos ags ON ags.agendamento_id = a.id JOIN servicos s ON s.id = COALESCE(ags.servico_id, a.servico_id) WHERE a.id = ? AND c.barbearia_id = ? FOR UPDATE', [appointmentId, tenantId]); return rows;
}
async function reconcileAppointment(connection, { tenantId, appointmentId, actorId }) {
  const items = await appointmentItems(connection, tenantId, appointmentId); if (!items.length || !items[0].completedAt) return { created: 0, released: 0n };
  const approvalMode = await getApprovalMode(connection, tenantId);
  const grossTotal = items.reduce((sum, item) => sum + centsFromDb(item.grossAmount), 0n); const appointmentTotal = centsFromDb(items[0].appointmentAmount); const generalDiscount = grossTotal > appointmentTotal ? grossTotal - appointmentTotal : 0n;
  let created = 0; let allocatedDiscount = 0n;
  for (const [index, item] of items.entries()) {
    const gross = centsFromDb(item.grossAmount); const discount = index === items.length - 1 ? generalDiscount - allocatedDiscount : (grossTotal === 0n ? 0n : (generalDiscount * gross) / grossTotal); allocatedDiscount += discount;
    const rule = applyRuleException(await findRule(connection, tenantId, item.professionalId, item.serviceId, item.completedAt), item.serviceId);
    const snapshot = rule ? calculateItem({ grossCents: gross, discountCents: discount, rule: { type: rule.type, base: rule.base, value: String(rule.value), valueBps: Number(rule.valueBps || 0) } }) : { gross, discount, originalNet: gross - discount, totalCommission: 0n };
    const status = rule ? 'open' : 'pending_rule';
    const approvalStatus = approvalMode === 'automatic' ? 'approved' : 'pending';
    await connection.query('INSERT INTO commission_entitlements (barbearia_id, agendamento_id, servico_id, profissional_id, rule_id, completed_at, gross_amount, discount_amount, original_net_amount, total_commission, snapshot_json, calculation_version, status, approval_mode_snapshot, approval_status, approved_at, approval_source) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE id = LAST_INSERT_ID(id)', [tenantId, item.appointmentId, item.serviceId, item.professionalId, rule?.id || null, item.completedAt, decimalFromCents(snapshot.gross), decimalFromCents(snapshot.discount), decimalFromCents(snapshot.originalNet), decimalFromCents(snapshot.totalCommission), JSON.stringify({ rule, gross: decimalFromCents(snapshot.gross), discount: decimalFromCents(snapshot.discount), originalNet: decimalFromCents(snapshot.originalNet), totalCommission: decimalFromCents(snapshot.totalCommission), professionalId: item.professionalId, serviceId: item.serviceId }), 'commission-v1', status, approvalMode, approvalStatus, approvalStatus === 'approved' ? new Date() : null, approvalStatus === 'approved' ? 'automatic' : null]);
    if (approvalMode === 'automatic') {
      await connection.query("UPDATE commission_entitlements SET approval_mode_snapshot = 'automatic', approval_status = 'approved', approved_at = COALESCE(approved_at, CURRENT_TIMESTAMP), approved_by = NULL, approval_source = 'automatic' WHERE barbearia_id = ? AND agendamento_id = ? AND servico_id = ? AND profissional_id = ?", [tenantId, item.appointmentId, item.serviceId, item.professionalId]);
    }
    const [[entitlement]] = await connection.query('SELECT id FROM commission_entitlements WHERE barbearia_id = ? AND agendamento_id = ? AND servico_id = ? AND profissional_id = ? ORDER BY revision DESC LIMIT 1 FOR UPDATE', [tenantId, item.appointmentId, item.serviceId, item.professionalId]);
    if (entitlement && rule) {
      await connection.query(
        `UPDATE commission_entitlements
            SET rule_id = ?, completed_at = ?, gross_amount = ?, discount_amount = ?,
                original_net_amount = ?, total_commission = ?, snapshot_json = ?,
                status = 'open', approval_mode_snapshot = ?, approval_status = ?,
                approved_at = ?, approved_by = NULL, approval_source = ?
          WHERE id = ? AND barbearia_id = ? AND status = 'pending_rule'`,
        [rule.id, item.completedAt, decimalFromCents(snapshot.gross),
          decimalFromCents(snapshot.discount), decimalFromCents(snapshot.originalNet),
          decimalFromCents(snapshot.totalCommission), JSON.stringify({ rule,
            gross: decimalFromCents(snapshot.gross),
            discount: decimalFromCents(snapshot.discount),
            originalNet: decimalFromCents(snapshot.originalNet),
            totalCommission: decimalFromCents(snapshot.totalCommission),
            professionalId: item.professionalId, serviceId: item.serviceId }),
          approvalMode, approvalStatus,
          approvalStatus === 'approved' ? new Date() : null,
          approvalStatus === 'approved' ? 'automatic' : null,
          entitlement.id, tenantId],
      );
      const result = await reconcileEntitlement(connection, { tenantId, entitlementId: entitlement.id, appointmentId: item.appointmentId, actorId });
      created += result.created;
    }
  }
  return { created };
}

async function reconcileAppointmentsForRule(connection, { tenantId, actorId, rule }) {
  const filters = [
    'c.barbearia_id = ?',
    "a.status NOT IN ('cancelado', 'nao_compareceu')",
    '(? IS NULL OR a.colaborador_id = ?)',
    '(? IS NULL OR COALESCE(ags.servico_id, a.servico_id) = ?)',
    '(? IS NULL OR COALESCE(a.concluido_em, a.data_hora) >= ?)',
    '(? IS NULL OR COALESCE(a.concluido_em, a.data_hora) < ?)',
  ];
  const params = [tenantId,
    rule.professionalId, rule.professionalId,
    rule.serviceId, rule.serviceId,
    rule.validFrom, rule.validFrom,
    rule.validUntil, rule.validUntil];
  const [appointments] = await connection.query(
    `SELECT DISTINCT a.id
       FROM agendamentos a
       JOIN colaboradores c ON c.id = a.colaborador_id
       LEFT JOIN agendamento_servicos ags ON ags.agendamento_id = a.id
      WHERE ${filters.join(' AND ')}`,
    params,
  );
  for (const appointment of appointments) {
    await reconcileAppointment(connection, {
      tenantId,
      appointmentId: appointment.id,
      actorId,
    });
  }
}
async function reconcileEntitlement(connection, { tenantId, entitlementId, appointmentId, actorId }) {
  const [[entitlement]] = await connection.query('SELECT * FROM commission_entitlements WHERE id = ? AND barbearia_id = ? FOR UPDATE', [entitlementId, tenantId]); if (!entitlement || entitlement.status === 'pending_rule') return { created: 0 };
  const [[paid]] = await connection.query("SELECT COALESCE(SUM(p.valor), 0) received FROM payments p WHERE p.barbearia_id = ? AND p.agendamento_id = ? AND p.status IN ('authorized','paid','partially_refunded')", [tenantId, appointmentId]);
  const [[refunded]] = await connection.query("SELECT COALESCE(SUM(r.valor), 0) refunded FROM refunds r JOIN payments p ON p.id = r.payment_id WHERE p.barbearia_id = ? AND p.agendamento_id = ? AND r.status = 'processed'", [tenantId, appointmentId]);
  const receivedTotal = centsFromDb(paid.received) - centsFromDb(refunded.refunded);
  const [siblings] = await connection.query('SELECT id, original_net_amount FROM commission_entitlements WHERE barbearia_id = ? AND agendamento_id = ? ORDER BY id FOR UPDATE', [tenantId, appointmentId]);
  const netTotal = siblings.reduce((sum, row) => sum + centsFromDb(row.original_net_amount), 0n);
  const siblingIndex = siblings.findIndex((row) => Number(row.id) === Number(entitlementId));
  const received = netTotal <= 0n || siblingIndex < 0 ? 0n : siblingIndex === siblings.length - 1 ? receivedTotal - siblings.slice(0, -1).reduce((sum, row) => sum + (receivedTotal > 0n ? (receivedTotal * centsFromDb(row.original_net_amount)) / netTotal : 0n), 0n) : (receivedTotal > 0n ? (receivedTotal * centsFromDb(entitlement.original_net_amount)) / netTotal : 0n);
  const target = targetReleased(true, centsFromDb(entitlement.total_commission), centsFromDb(entitlement.original_net_amount), received > centsFromDb(entitlement.original_net_amount) ? centsFromDb(entitlement.original_net_amount) : received);
  const [[existing]] = await connection.query("SELECT COALESCE(SUM(signed_amount), 0) amount FROM commission_entries WHERE entitlement_id = ? AND kind IN ('release','reversal','correction')", [entitlementId]); const current = centsFromDb(existing.amount); const delta = target - current;
  if (delta === 0n) return { created: 0 };
  const kind = delta > 0n ? 'release' : 'reversal'; const key = 'auto:' + entitlementId + ':' + target.toString();
  await connection.query('INSERT INTO commission_entries (barbearia_id, entitlement_id, profissional_id, agendamento_id, kind, signed_amount, source_event_id, idempotency_key, criado_por, effective_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, COALESCE((SELECT concluido_em FROM agendamentos WHERE id = ?), NOW()))', [tenantId, entitlementId, entitlement.profissional_id, appointmentId, kind, decimalFromCents(delta), 'commission-reconcile:' + entitlementId, key, actorId, appointmentId]);
  const eligible = target > 0n;
  const cancelled = false;
  if (shouldAutoApprove({ approvalMode: entitlement.approval_mode_snapshot, approvalStatus: entitlement.approval_status, eligibilityStatus: eligible ? 'eligible' : 'blocked', cancelled, hasBlockingIssue: false })) {
    await connection.query("UPDATE commission_entitlements SET approval_status = 'approved', approved_at = CURRENT_TIMESTAMP, approved_by = NULL, approval_source = 'automatic' WHERE id = ? AND barbearia_id = ? AND approval_status = 'pending'", [entitlementId, tenantId]);
    await connection.query("INSERT INTO audit_logs (barbearia_id, usuario_id, acao, recurso, recurso_id, detalhes) VALUES (?, NULL, 'commission.approved.automatic', 'commission_entitlement', ?, JSON_OBJECT('entitlementId', ?, 'source', 'automatic'))", [tenantId, String(entitlementId), entitlementId]);
  }
  await connection.query("UPDATE commission_entitlements SET status = CASE WHEN ? >= total_commission THEN 'settled' ELSE 'open' END WHERE id = ?", [decimalFromCents(target), entitlementId]); return { created: 1, delta };
}
module.exports.reconcileAppointment = reconcileAppointment;
module.exports.reconcileEntitlement = reconcileEntitlement;

async function previewSettlement({ tenantId, professionalId, from, to }) {
  const professional = id(professionalId); if (professional == null || !date(from) || !date(to)) return { status: 422, code: 'VALIDATION_ERROR' };
  const [entries] = await pool.query('SELECT e.id, e.signed_amount amount, e.kind, e.effective_at FROM commission_entries e WHERE e.barbearia_id = ? AND e.profissional_id = ? AND e.effective_at >= ? AND e.effective_at < ? AND NOT EXISTS (SELECT 1 FROM commission_settlement_items si WHERE si.entry_id = e.id)', [tenantId, professional, from, to]);
  const [[sum]] = await pool.query('SELECT COALESCE(SUM(e.signed_amount), 0) total FROM commission_entries e WHERE e.barbearia_id = ? AND e.profissional_id = ? AND e.effective_at >= ? AND e.effective_at < ? AND NOT EXISTS (SELECT 1 FROM commission_settlement_items si WHERE si.entry_id = e.id)', [tenantId, professional, from, to]);
  const [advances] = await pool.query("SELECT a.id, a.valor amount, a.pago_em paid_at, COALESCE(SUM(aa.amount), 0) allocated FROM commission_advances a LEFT JOIN commission_advance_allocations aa ON aa.advance_id = a.id WHERE a.barbearia_id = ? AND a.profissional_id = ? AND a.status = 'confirmed' GROUP BY a.id ORDER BY a.pago_em, a.id", [tenantId, professional]);
  return { status: 200, entries, total: sum.total, advances: advances.map((row) => ({ ...row, available: Number(row.amount) - Number(row.allocated) })) };
}
async function createSettlement({ tenantId, actorId, professionalId, from, to }) {
  const professional = id(professionalId); if (professional == null || !date(from) || !date(to)) return { status: 422, code: 'VALIDATION_ERROR' }; const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const [entries] = await connection.query('SELECT e.id, e.signed_amount amount FROM commission_entries e WHERE e.barbearia_id = ? AND e.profissional_id = ? AND e.effective_at >= ? AND e.effective_at < ? AND NOT EXISTS (SELECT 1 FROM commission_settlement_items si WHERE si.entry_id = e.id) ORDER BY e.effective_at, e.id FOR UPDATE', [tenantId, professional, from, to]);
    if (!entries.length) { await connection.rollback(); return { status: 409, code: 'NO_COMMISSION_ENTRIES' }; }
    const total = entries.reduce((sum, row) => sum + centsFromDb(row.amount), 0n); const [settlement] = await connection.query("INSERT INTO commission_settlements (barbearia_id, profissional_id, periodo_inicio, periodo_fim, status, total_lancamentos, saldo_a_pagar, criado_por, fechado_em) VALUES (?, ?, ?, ?, 'closed', ?, ?, ?, NOW())", [tenantId, professional, from, to, decimalFromCents(total), decimalFromCents(total), actorId]);
    for (const entry of entries) await connection.query('INSERT INTO commission_settlement_items (settlement_id, entry_id, amount) VALUES (?, ?, ?)', [settlement.insertId, entry.id, entry.amount]);
    let remaining = total; let advancesTotal = 0n;
    const [advances] = await connection.query("SELECT id, valor FROM commission_advances WHERE barbearia_id = ? AND profissional_id = ? AND status = 'confirmed' ORDER BY pago_em, id FOR UPDATE", [tenantId, professional]);
    for (const advance of advances) {
      const [[allocated]] = await connection.query('SELECT COALESCE(SUM(amount), 0) amount FROM commission_advance_allocations WHERE advance_id = ?', [advance.id]);
      const available = centsFromDb(advance.valor) - centsFromDb(allocated.amount); if (available <= 0n || remaining <= 0n) continue;
      const applied = available < remaining ? available : remaining; await connection.query('INSERT INTO commission_advance_allocations (barbearia_id, advance_id, settlement_id, amount) VALUES (?, ?, ?, ?)', [tenantId, advance.id, settlement.insertId, decimalFromCents(applied)]); advancesTotal += applied; remaining -= applied;
    }
    await connection.query('UPDATE commission_settlements SET total_adiantamentos = ?, saldo_a_pagar = ? WHERE id = ?', [decimalFromCents(advancesTotal), decimalFromCents(remaining), settlement.insertId]);
    await connection.query("UPDATE commission_entitlements e JOIN commission_entries ce ON ce.entitlement_id = e.id JOIN commission_settlement_items si ON si.entry_id = ce.id SET e.status = 'reserved' WHERE si.settlement_id = ?", [settlement.insertId]);
    await connection.query("INSERT INTO audit_logs (barbearia_id, usuario_id, acao, recurso, recurso_id, detalhes) VALUES (?, ?, 'commission.settlement.created', 'commission_settlement', ?, JSON_OBJECT('total', ?))", [tenantId, actorId, String(settlement.insertId), decimalFromCents(total)]);
    await connection.commit(); return { status: 201, id: settlement.insertId, total: decimalFromCents(total) };
  } catch (error) { await connection.rollback().catch(() => {}); throw error; } finally { connection.release(); }
}
async function paySettlement({ tenantId, actorId, settlementId, amount, accountId, method, paidAt, idempotencyKey }) {
  let amountCents; try { amountCents = parseCents(String(amount || '')); } catch (_) { return { status: 422, code: 'VALIDATION_ERROR' }; } const account = id(accountId); const settlement = id(settlementId); if (amountCents <= 0n || account == null || settlement == null || !idempotencyKey || !date(paidAt)) return { status: 422, code: 'VALIDATION_ERROR' }; const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const [[existing]] = await connection.query('SELECT id FROM commission_settlement_payments WHERE barbearia_id = ? AND idempotency_key = ? FOR UPDATE', [tenantId, idempotencyKey]); if (existing) { await connection.commit(); return { status: 200, id: existing.id, idempotent: true }; }
    const [[row]] = await connection.query('SELECT * FROM commission_settlements WHERE id = ? AND barbearia_id = ? FOR UPDATE', [settlement, tenantId]); if (!row) { await connection.rollback(); return { status: 404, code: 'SETTLEMENT_NOT_FOUND' }; }
    const [[paid]] = await connection.query("SELECT COALESCE(SUM(amount), 0) total FROM commission_settlement_payments WHERE settlement_id = ? AND status = 'confirmed'", [settlement]); const balance = centsFromDb(row.saldo_a_pagar) - centsFromDb(paid.total); if (amountCents > balance) { await connection.rollback(); return { status: 422, code: 'PAYMENT_EXCEEDS_SETTLEMENT', balance: decimalFromCents(balance) }; }
    const [[financialAccount]] = await connection.query('SELECT id FROM financial_accounts WHERE id = ? AND barbearia_id = ? AND ativo = 1', [account, tenantId]); if (!financialAccount) { await connection.rollback(); return { status: 422, code: 'INVALID_ACCOUNT' }; }
    const [payment] = await connection.query('INSERT INTO commission_settlement_payments (barbearia_id, settlement_id, amount, paid_at, payment_method, financial_account_id, idempotency_key, created_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', [tenantId, settlement, decimalFromCents(amountCents), paidAt, String(method || 'other'), account, idempotencyKey, actorId]);
    const [movement] = await connection.query("INSERT INTO financial_movements (barbearia_id, movement_type, operation, origin_type, origin_id, idempotency_key, professional_id, financial_account_id, amount, movement_date, description, status, created_by) VALUES (?, 'expense', 'commission_settlement_paid', 'manual_adjustment', ?, ?, ?, ?, ?, ?, ?, 'confirmed', ?)", [tenantId, payment.insertId, idempotencyKey, row.profissional_id, account, decimalFromCents(amountCents), paidAt, 'Repasse de comissão #' + settlement, actorId]);
    await connection.query('UPDATE commission_settlement_payments SET financial_movement_id = ? WHERE id = ?', [movement.insertId, payment.insertId]); const newBalance = balance - amountCents; await connection.query("UPDATE commission_settlements SET total_pago = total_pago + ?, status = CASE WHEN ? = 0 THEN 'paid' ELSE 'partially_paid' END, atualizado_em = CURRENT_TIMESTAMP WHERE id = ?", [decimalFromCents(amountCents), decimalFromCents(newBalance), settlement]); await connection.query("INSERT INTO audit_logs (barbearia_id, usuario_id, acao, recurso, recurso_id, detalhes) VALUES (?, ?, 'commission.settlement.paid', 'commission_settlement', ?, JSON_OBJECT('amount', ?, 'paymentId', ?))", [tenantId, actorId, String(settlement), decimalFromCents(amountCents), payment.insertId]); await connection.commit(); return { status: 201, id: payment.insertId, movementId: movement.insertId, balance: decimalFromCents(newBalance) };
  } catch (error) { await connection.rollback().catch(() => {}); if (error.code === 'ER_DUP_ENTRY') return { status: 409, code: 'PAYMENT_CONFLICT' }; throw error; } finally { connection.release(); }
}
module.exports.previewSettlement = previewSettlement;
module.exports.createSettlement = createSettlement;
module.exports.paySettlement = paySettlement;

async function listAdvances({ tenantId, professionalId = null }) {
  const params = [tenantId]; const filter = professionalId == null ? '' : ' AND a.profissional_id = ?'; if (professionalId != null) params.push(id(professionalId));
  const [rows] = await pool.query('SELECT a.id, a.profissional_id professional_id, a.valor amount, a.pago_em paid_at, a.metodo method, a.observacao notes, a.status, a.idempotency_key, COALESCE(SUM(aa.amount), 0) allocated, a.valor - COALESCE(SUM(aa.amount), 0) available FROM commission_advances a LEFT JOIN commission_advance_allocations aa ON aa.advance_id = a.id WHERE a.barbearia_id = ?' + filter + ' GROUP BY a.id ORDER BY a.pago_em DESC, a.id DESC', params); return rows;
}
async function createAdvance({ tenantId, actorId, professionalId, amount, paidAt, method, accountId, notes, idempotencyKey }) {
  const professional = id(professionalId); const account = id(accountId); let amountCents; try { amountCents = parseCents(String(amount || '')); } catch (_) { return { status: 422, code: 'VALIDATION_ERROR' }; }
  if (professional == null || account == null || amountCents <= 0n || !date(paidAt) || !idempotencyKey) return { status: 422, code: 'VALIDATION_ERROR' }; const connection = await pool.getConnection();
  try {
    await connection.beginTransaction(); const [[existing]] = await connection.query('SELECT id FROM commission_advances WHERE barbearia_id = ? AND idempotency_key = ? FOR UPDATE', [tenantId, idempotencyKey]); if (existing) { await connection.commit(); return { status: 200, id: existing.id, idempotent: true }; }
    const [[professionalRow]] = await connection.query('SELECT id FROM colaboradores WHERE id = ? AND barbearia_id = ? AND ativo = 1 FOR UPDATE', [professional, tenantId]); if (!professionalRow) { await connection.rollback(); return { status: 422, code: 'INVALID_RELATION' }; }
    const [[accountRow]] = await connection.query('SELECT id FROM financial_accounts WHERE id = ? AND barbearia_id = ? AND ativo = 1', [account, tenantId]); if (!accountRow) { await connection.rollback(); return { status: 422, code: 'INVALID_ACCOUNT' }; }
    const [advance] = await connection.query("INSERT INTO commission_advances (barbearia_id, profissional_id, valor, pago_em, metodo, observacao, status, idempotency_key, criado_por) VALUES (?, ?, ?, ?, ?, ?, 'confirmed', ?, ?)", [tenantId, professional, decimalFromCents(amountCents), paidAt, String(method || 'other'), String(notes || '').trim() || null, idempotencyKey, actorId]);
    const [movement] = await connection.query("INSERT INTO financial_movements (barbearia_id, movement_type, operation, origin_type, origin_id, idempotency_key, professional_id, financial_account_id, amount, movement_date, description, status, created_by) VALUES (?, 'expense', 'commission_advance_paid', 'manual_adjustment', ?, ?, ?, ?, ?, ?, ?, 'confirmed', ?)", [tenantId, advance.insertId, idempotencyKey, professional, account, decimalFromCents(amountCents), paidAt, 'Adiantamento de comissão #' + advance.insertId, actorId]);
    await connection.query('UPDATE commission_advances SET financial_movement_id = ? WHERE id = ?', [movement.insertId, advance.insertId]); await connection.query("INSERT INTO audit_logs (barbearia_id, usuario_id, acao, recurso, recurso_id, detalhes) VALUES (?, ?, 'commission.advance.created', 'commission_advance', ?, JSON_OBJECT('amount', ?, 'movementId', ?))", [tenantId, actorId, String(advance.insertId), decimalFromCents(amountCents), movement.insertId]); await connection.commit(); return { status: 201, id: advance.insertId, movementId: movement.insertId };
  } catch (error) { await connection.rollback().catch(() => {}); if (error.code === 'ER_DUP_ENTRY') return { status: 409, code: 'PAYMENT_CONFLICT' }; throw error; } finally { connection.release(); }
}
module.exports.listAdvances = listAdvances;
module.exports.createAdvance = createAdvance;

async function listSettlements({ tenantId, professionalId = null }) {
  const params = [tenantId];
  const filter = professionalId == null ? '' : ' AND s.profissional_id = ?';
  if (professionalId != null) params.push(id(professionalId));
  const [rows] = await pool.query(
    'SELECT s.id, s.profissional_id professional_id, u.nome professional_name, s.periodo_inicio from_date, s.periodo_fim to_date, s.status, s.total_lancamentos total_entries, s.total_adiantamentos advances, s.total_pago paid, s.saldo_a_pagar balance, s.fechado_em closed_at, s.criado_em created_at FROM commission_settlements s JOIN colaboradores c ON c.id = s.profissional_id JOIN usuarios u ON u.id = c.usuario_id WHERE s.barbearia_id = ?' + filter + ' ORDER BY s.fechado_em DESC, s.id DESC LIMIT 100',
    params,
  );
  return rows;
}

module.exports.listSettlements = listSettlements;


async function reverseSettlementPayment({ tenantId, actorId, paymentId, reason, idempotencyKey }) {
  const payment = id(paymentId);
  const note = String(reason || '').trim();
  const key = String(idempotencyKey || '').trim();
  if (payment == null || note.length < 3 || note.length > 240 || !/^[a-zA-Z0-9._:-]{8,100}$/.test(key)) return { status: 422, code: 'VALIDATION_ERROR' };
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const [[already]] = await connection.query(
      "SELECT id FROM financial_movements WHERE barbearia_id = ? AND origin_type = 'manual_adjustment' AND origin_id = ? AND operation = 'commission_settlement_payment_reversal' FOR UPDATE",
      [tenantId, payment],
    );
    if (already) { await connection.commit(); return { status: 200, id: already.id, idempotent: true }; }
    const [[row]] = await connection.query(
      "SELECT p.id, p.amount, p.settlement_id, p.financial_movement_id, p.status, s.profissional_id, s.saldo_a_pagar FROM commission_settlement_payments p JOIN commission_settlements s ON s.id = p.settlement_id WHERE p.id = ? AND p.barbearia_id = ? FOR UPDATE",
      [payment, tenantId],
    );
    if (!row) { await connection.rollback(); return { status: 404, code: 'COMMISSION_PAYMENT_NOT_FOUND' }; }
    if (row.status !== 'confirmed') { await connection.rollback(); return { status: 409, code: 'COMMISSION_PAYMENT_ALREADY_REVERSED' }; }
    const amount = centsFromDb(row.amount);
    if (row.financial_movement_id) {
      await connection.query("UPDATE financial_movements SET status = 'reversed', cancelled_by = ?, cancelled_at = NOW(), cancellation_reason = ? WHERE id = ? AND barbearia_id = ?", [actorId, note, row.financial_movement_id, tenantId]);
    }
    const [movement] = await connection.query(
      "INSERT INTO financial_movements (barbearia_id, movement_type, operation, origin_type, origin_id, professional_id, financial_account_id, amount, movement_date, description, status, created_by) SELECT p.barbearia_id, 'reversal', 'commission_settlement_payment_reversal', 'manual_adjustment', p.id, s.profissional_id, p.financial_account_id, p.amount, NOW(), ?, 'confirmed', ? FROM commission_settlement_payments p JOIN commission_settlements s ON s.id = p.settlement_id WHERE p.id = ? AND p.barbearia_id = ?",
      ['Reversão do pagamento de comissão #' + payment + ': ' + note, actorId, payment, tenantId],
    );
    await connection.query("UPDATE commission_settlement_payments SET status = 'reversed' WHERE id = ? AND barbearia_id = ?", [payment, tenantId]);
    const [[paid]] = await connection.query("SELECT COALESCE(SUM(amount), 0) total FROM commission_settlement_payments WHERE settlement_id = ? AND status = 'confirmed'", [row.settlement_id]);
    const totalPaid = centsFromDb(paid.total);
    const settlementBalance = centsFromDb(row.saldo_a_pagar);
    const status = totalPaid === 0n ? 'closed' : totalPaid >= settlementBalance ? 'paid' : 'partially_paid';
    await connection.query('UPDATE commission_settlements SET total_pago = ?, status = ?, atualizado_em = CURRENT_TIMESTAMP WHERE id = ? AND barbearia_id = ?', [decimalFromCents(totalPaid), status, row.settlement_id, tenantId]);
    await connection.query("INSERT INTO audit_logs (barbearia_id, usuario_id, acao, recurso, recurso_id, detalhes) VALUES (?, ?, 'commission.settlement.payment.reversed', 'commission_settlement_payment', ?, JSON_OBJECT('paymentId', ?, 'amount', ?, 'reason', ?, 'movementId', ?))", [tenantId, actorId, String(payment), payment, decimalFromCents(amount), note, movement.insertId]);
    await connection.commit();
    return { status: 201, id: movement.insertId, paymentId: payment, balance: decimalFromCents(settlementBalance - totalPaid) };
  } catch (error) {
    await connection.rollback().catch(() => {});
    if (error.code === 'ER_DUP_ENTRY') return { status: 409, code: 'REVERSAL_CONFLICT' };
    throw error;
  } finally { connection.release(); }
}

async function reverseAdvance({ tenantId, actorId, advanceId, reason, idempotencyKey }) {
  const advance = id(advanceId);
  const note = String(reason || '').trim();
  const key = String(idempotencyKey || '').trim();
  if (advance == null || note.length < 3 || note.length > 240 || !/^[a-zA-Z0-9._:-]{8,100}$/.test(key)) return { status: 422, code: 'VALIDATION_ERROR' };
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const [[already]] = await connection.query("SELECT id FROM financial_movements WHERE barbearia_id = ? AND origin_type = 'manual_adjustment' AND origin_id = ? AND operation = 'commission_advance_reversal' FOR UPDATE", [tenantId, advance]);
    if (already) { await connection.commit(); return { status: 200, id: already.id, idempotent: true }; }
    const [[row]] = await connection.query("SELECT id, valor, profissional_id, financial_movement_id, status FROM commission_advances WHERE id = ? AND barbearia_id = ? FOR UPDATE", [advance, tenantId]);
    if (!row) { await connection.rollback(); return { status: 404, code: 'COMMISSION_ADVANCE_NOT_FOUND' }; }
    if (row.status !== 'confirmed') { await connection.rollback(); return { status: 409, code: 'COMMISSION_ADVANCE_ALREADY_REVERSED' }; }
    const [[allocated]] = await connection.query('SELECT COALESCE(SUM(amount), 0) amount FROM commission_advance_allocations WHERE advance_id = ?', [advance]);
    if (centsFromDb(allocated.amount) > 0n) { await connection.rollback(); return { status: 409, code: 'ADVANCE_ALREADY_APPLIED' }; }
    if (row.financial_movement_id) await connection.query("UPDATE financial_movements SET status = 'reversed', cancelled_by = ?, cancelled_at = NOW(), cancellation_reason = ? WHERE id = ? AND barbearia_id = ?", [actorId, note, row.financial_movement_id, tenantId]);
    const [movement] = await connection.query("INSERT INTO financial_movements (barbearia_id, movement_type, operation, origin_type, origin_id, professional_id, financial_account_id, amount, movement_date, description, status, created_by) SELECT a.barbearia_id, 'reversal', 'commission_advance_reversal', 'manual_adjustment', a.id, a.profissional_id, fm.financial_account_id, a.valor, NOW(), ?, 'confirmed', ? FROM commission_advances a JOIN financial_movements fm ON fm.id = a.financial_movement_id WHERE a.id = ? AND a.barbearia_id = ?", ['Reversão do adiantamento #' + advance + ': ' + note, actorId, advance, tenantId]);
    await connection.query("UPDATE commission_advances SET status = 'reversed' WHERE id = ? AND barbearia_id = ?", [advance, tenantId]);
    await connection.query("INSERT INTO audit_logs (barbearia_id, usuario_id, acao, recurso, recurso_id, detalhes) VALUES (?, ?, 'commission.advance.reversed', 'commission_advance', ?, JSON_OBJECT('amount', ?, 'reason', ?, 'movementId', ?))", [tenantId, actorId, String(advance), String(row.valor), note, movement.insertId]);
    await connection.commit();
    return { status: 201, id: movement.insertId, advanceId: advance };
  } catch (error) { await connection.rollback().catch(() => {}); if (error.code === 'ER_DUP_ENTRY') return { status: 409, code: 'REVERSAL_CONFLICT' }; throw error; } finally { connection.release(); }
}

module.exports.reverseSettlementPayment = reverseSettlementPayment;
module.exports.reverseAdvance = reverseAdvance;


async function listSettlementPayments({ tenantId, settlementId = null }) {
  const params = [tenantId];
  let filter = '';
  if (settlementId != null) { const parsed = id(settlementId); if (parsed == null) return []; filter = ' AND p.settlement_id = ?'; params.push(parsed); }
  const [rows] = await pool.query("SELECT p.id, p.settlement_id, p.amount, p.paid_at, p.payment_method method, p.financial_account_id account_id, fa.nome account_name, p.status, p.created_at FROM commission_settlement_payments p JOIN financial_accounts fa ON fa.id = p.financial_account_id WHERE p.barbearia_id = ?" + filter + ' ORDER BY p.paid_at DESC, p.id DESC LIMIT 200', params);
  return rows;
}
module.exports.listSettlementPayments = listSettlementPayments;


async function simulateRule({ tenantId, professionalId, serviceId, effectiveAt, grossAmount, discountAmount = '0.00', quantity = 1, receivedAmount = null }) {
  const professional = id(professionalId);
  const service = id(serviceId);
  const when = date(effectiveAt);
  const units = Number(quantity);
  if (professional == null || service == null || !when || !Number.isInteger(units) || units <= 0) return { status: 422, code: 'VALIDATION_ERROR' };
  let gross;
  let discount;
  let received = null;
  try {
    gross = parseCents(String(grossAmount ?? '').replace(',', '.'));
    discount = parseCents(String(discountAmount ?? '0.00').replace(',', '.'));
    if (receivedAmount != null && receivedAmount !== '') received = parseCents(String(receivedAmount).replace(',', '.'));
  } catch (_) { return { status: 422, code: 'INVALID_AMOUNT' }; }
  const connection = await pool.getConnection();
  try {
    const [[professionalRow]] = await connection.query('SELECT id FROM colaboradores WHERE id = ? AND barbearia_id = ?', [professional, tenantId]);
    const [[serviceRow]] = await connection.query('SELECT id FROM servicos WHERE id = ? AND barbearia_id = ?', [service, tenantId]);
    if (!professionalRow || !serviceRow) return { status: 422, code: 'INVALID_RELATION' };
    const rule = applyRuleException(await findRule(connection, tenantId, professional, service, when), service);
    if (!rule) return { status: 200, status_code: 'NO_APPLICABLE_RULE', rule: null, memory: { gross_amount: decimalFromCents(gross), discount_amount: decimalFromCents(discount), base_amount: null, commission: '0.00' } };
    const result = calculateItem({ grossCents: gross, discountCents: discount, quantity: BigInt(units), rule: { type: rule.type, base: rule.base, value: String(rule.value), valueBps: Number(rule.valueBps || 0) } });
    const receivedCents = received == null ? result.originalNet : received;
    const released = targetReleased(true, result.totalCommission, result.originalNet, receivedCents > result.originalNet ? result.originalNet : receivedCents);
    const priority = rule.professionalId != null && rule.serviceId != null ? 1 : rule.professionalId != null ? 2 : rule.serviceId != null ? 3 : 4;
    return { status: 200, status_code: 'OK', rule: { id: rule.id, type: rule.type, value: rule.value, value_bps: rule.valueBps, base: rule.base, version: rule.version, valid_from: rule.validFrom, valid_until: rule.validUntil, priority, selection_reason: ['profissional + serviço', 'profissional + padrão do tipo', 'serviço + todos os profissionais', 'padrão da barbearia'][priority - 1] }, memory: { quantity: units, gross_amount: decimalFromCents(result.gross), discount_amount: decimalFromCents(result.discount), original_net_amount: decimalFromCents(result.originalNet), base_amount: decimalFromCents(result.base), total_commission: decimalFromCents(result.totalCommission), received_amount: decimalFromCents(receivedCents), released_amount: decimalFromCents(released), pending_amount: decimalFromCents(result.totalCommission - released) } };
  } catch (error) {
    if (error.message === 'discount_exceeds_item' || error.message === 'invalid_item_amount') return { status: 422, code: 'INVALID_ITEM_AMOUNT' };
    throw error;
  } finally { connection.release(); }
}
module.exports.simulateRule = simulateRule;

function draftId(value) {
  const parsed = Number(value);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : null;
}

function normalizeDraftPayload(payload = {}) {
  const value = payload && typeof payload === 'object' ? payload : {};
  const name = String(value.name || '').trim();
  if (name.length < 3 || name.length > 100) return { error: 'INVALID_RULE_NAME' };
  if (!value.validity || !value.validity.startsOn) return { error: 'INVALID_VALIDITY' };
  if (!value.services?.enabled && !value.products?.enabled) return { error: 'ITEM_TYPE_REQUIRED' };
  if (value.products?.enabled) return { error: 'UNSUPPORTED_PRODUCT_COMMISSION' };
  if (value.professionals?.mode === 'SELECTED' && (!Array.isArray(value.professionals.ids) || value.professionals.ids.length === 0)) return { error: 'PROFESSIONAL_SCOPE_REQUIRED' };
  if (value.services?.enabled && value.services?.scope?.mode === 'SELECTED' && (!Array.isArray(value.services.scope.ids) || value.services.scope.ids.length === 0)) return { error: 'SERVICE_SCOPE_REQUIRED' };
  return {
    ...value,
    name,
    revision: Number(value.revision || 1),
    services: value.services || { enabled: true, scope: { mode: 'ALL' }, calculation: { model: 'PERCENTAGE', rate: '0', basis: 'AFTER_DISCOUNTS' } },
    products: value.products || { enabled: false, scope: { mode: 'ALL' }, calculation: { model: 'PERCENTAGE', rate: '0', basis: 'AFTER_DISCOUNTS' } },
    exceptions: Array.isArray(value.exceptions) ? value.exceptions : [],
    goalPlan: value.goalPlan || null,
  };
}

async function createRuleDraft({ tenantId, actorId, payload = {} }) {
  const normalized = normalizeDraftPayload(payload);
  if (normalized.error) return { status: 422, code: normalized.error };
  const [result] = await pool.query(
    'INSERT INTO commission_rule_drafts (barbearia_id, criado_por, payload) VALUES (?, ?, ?)',
    [tenantId, actorId, JSON.stringify(normalized)],
  );
  return { status: 201, id: result.insertId, revision: 1, payload: normalized };
}

async function getRuleDraft({ tenantId, actorId, draftId: requestedId = null }) {
  const parsed = requestedId == null ? null : draftId(requestedId);
  const params = [tenantId, actorId];
  const filter = parsed == null ? ' AND status = \'editing\'' : ' AND id = ?';
  if (parsed != null) params.push(parsed);
  const [[row]] = await pool.query(
    'SELECT id, status, revision, payload, atualizado_em updated_at FROM commission_rule_drafts WHERE barbearia_id = ? AND criado_por = ?' + filter + ' ORDER BY atualizado_em DESC, id DESC LIMIT 1',
    params,
  );
  if (!row) return null;
  if (typeof row.payload === 'string') {
    try { row.payload = JSON.parse(row.payload); } catch (_) { row.payload = {}; }
  }
  return row;
}

async function updateRuleDraft({ tenantId, actorId, draftId: requestedId, revision, payload }) {
  const parsed = draftId(requestedId);
  const normalized = normalizeDraftPayload(payload);
  if (parsed == null || normalized.error) return { status: 422, code: normalized.error || 'INVALID_DRAFT' };
  const [result] = await pool.query(
    'UPDATE commission_rule_drafts SET payload = ?, revision = revision + 1 WHERE id = ? AND barbearia_id = ? AND criado_por = ? AND status = \'editing\' AND revision = ?',
    [JSON.stringify(normalized), parsed, tenantId, actorId, Number(revision) || 1],
  );
  if (result.affectedRows === 0) return { status: 409, code: 'DRAFT_VERSION_CONFLICT' };
  return { status: 200, id: parsed, revision: (Number(revision) || 1) + 1, payload: normalized };
}

async function createRuleVersionDraft({ tenantId, actorId, ruleId: requestedId }) {
  const parsed = id(requestedId);
  if (parsed == null) return { status: 422, code: 'INVALID_RULE' };
  const [[row]] = await pool.query(
    'SELECT id, nome, config_json, profissional_id professionalId, servico_id serviceId, tipo type, valor value, valor_bps valueBps, base, valido_de validFrom, valido_ate validUntil FROM commission_rules WHERE id = ? AND barbearia_id = ?',
    [parsed, tenantId],
  );
  if (!row) return { status: 404, code: 'RULE_NOT_FOUND' };
  let config = {};
  if (typeof row.config_json === 'string') {
    try { config = JSON.parse(row.config_json); } catch (_) { config = {}; }
  } else if (row.config_json && typeof row.config_json === 'object') {
    config = row.config_json;
  }
  const previousStart = row.validFrom ? new Date(row.validFrom) : new Date();
  const now = new Date();
  const nextStart = new Date(Math.max(previousStart.getTime() + 86400000, now.getTime() + 86400000));
  const calculation = row.type === 'fixed'
    ? { model: 'FIXED_PER_UNIT', fixedValue: String(row.value), basis: 'AFTER_DISCOUNTS' }
    : { model: 'PERCENTAGE', rate: String(row.value), basis: row.base === 'gross' ? 'GROSS' : 'AFTER_DISCOUNTS' };
  const payload = {
    ...config,
    name: row.nome || config.name || 'Regra de comissão',
    revision: 1,
    sourceRuleId: row.id,
    professionals: row.professionalId == null
      ? { mode: 'ALL', ids: [] }
      : { mode: 'SELECTED', ids: [String(row.professionalId)] },
    services: {
      ...(config.services || {}),
      enabled: true,
      scope: row.serviceId == null
        ? { mode: 'ALL', ids: [] }
        : { mode: 'SELECTED', ids: [String(row.serviceId)] },
      calculation,
    },
    products: { enabled: false, scope: { mode: 'ALL', ids: [] }, calculation: { model: 'PERCENTAGE', rate: '0', basis: 'AFTER_DISCOUNTS' } },
    validity: {
      ...(config.validity || {}),
      startsOn: nextStart.toISOString(),
      endsOn: null,
      timezone: config.validity?.timezone || 'America/Sao_Paulo',
    },
  };
  const normalized = normalizeDraftPayload(payload);
  if (normalized.error) return { status: 422, code: normalized.error };
  const [result] = await pool.query(
    'INSERT INTO commission_rule_drafts (barbearia_id, criado_por, payload) VALUES (?, ?, ?)',
    [tenantId, actorId, JSON.stringify(normalized)],
  );
  return { status: 201, id: result.insertId, revision: 1, sourceRuleId: row.id, payload: normalized };
}

async function publishRuleDraft({ tenantId, actorId, draftId: requestedId }) {
  const parsed = draftId(requestedId);
  if (parsed == null) return { status: 422, code: 'INVALID_DRAFT' };
  const draft = await getRuleDraft({ tenantId, actorId, draftId: parsed });
  if (!draft) return { status: 404, code: 'DRAFT_NOT_FOUND' };
  if (draft.status === 'published') return { status: 200, id: draft.id, payload: draft.payload };
  const payload = draft.payload || {};
  const sourceRuleId = id(payload.sourceRuleId);
  const serviceCalculation = payload.services?.calculation || {};
  const professionals = payload.professionals?.mode === 'SELECTED' ? payload.professionals.ids : [null];
  const services = payload.services?.scope?.mode === 'SELECTED' ? payload.services.scope.ids : [null];
  if (!Array.isArray(professionals) || !Array.isArray(services) || !professionals.length || !services.length) return { status: 422, code: 'INVALID_SCOPE' };
  if (professionals.length * services.length > 100) return { status: 422, code: 'SCOPE_TOO_LARGE' };
  const ruleInput = {
    name: payload.name,
    type: serviceCalculation.model === 'FIXED_PER_UNIT' ? 'fixed' : 'percentage',
    value: serviceCalculation.model === 'FIXED_PER_UNIT' ? serviceCalculation.fixedValue : serviceCalculation.rate,
    base: serviceCalculation.basis === 'GROSS' ? 'gross' : 'net_after_discount',
    validFrom: payload.validity?.startsOn,
    validUntil: payload.validity?.endsOn || null,
    config: payload,
  };
  const normalized = normalizeRule(ruleInput);
  if (normalized.error) return { status: 422, code: normalized.error };
  const connection = await pool.getConnection();
  const created = [];
  try {
    await connection.beginTransaction();
    for (const professionalId of professionals) {
      for (const serviceId of services) {
        const rule = normalizeRule({ ...ruleInput, professionalId, serviceId });
        if (rule.error) { await connection.rollback(); return { status: 422, code: rule.error }; }
        if (!await validateReferences(connection, tenantId, rule)) { await connection.rollback(); return { status: 422, code: 'INVALID_RELATION' }; }
        const key = scopeKey(rule);
        const [[versionRow]] = await connection.query('SELECT COALESCE(MAX(versao), 0) + 1 version FROM commission_rules WHERE barbearia_id = ? AND scope_key = ? FOR UPDATE', [tenantId, key]);
        const version = Number(versionRow.version);
        if (sourceRuleId != null) {
          const [[previous]] = await connection.query(
            'SELECT id, valido_de validFrom, valido_ate validUntil FROM commission_rules WHERE id = ? AND barbearia_id = ? AND scope_key = ? FOR UPDATE',
            [sourceRuleId, tenantId, key],
          );
          if (!previous) { await connection.rollback(); return { status: 404, code: 'RULE_NOT_FOUND' }; }
          const previousStart = previous.validFrom ? new Date(previous.validFrom).getTime() : -Infinity;
          const nextStart = rule.validFrom ? rule.validFrom.getTime() : Date.now();
          if (previousStart >= nextStart) { await connection.rollback(); return { status: 409, code: 'RULE_VERSION_DATE_INVALID' }; }
          const previousEnd = previous.validUntil ? new Date(previous.validUntil).getTime() : Infinity;
          if (previousEnd > nextStart) {
            await connection.query(
              'UPDATE commission_rules SET valido_ate = ?, atualizado_em = CURRENT_TIMESTAMP WHERE id = ? AND barbearia_id = ?',
              [rule.validFrom, sourceRuleId, tenantId],
            );
          }
        }
        const [overlap] = await connection.query('SELECT id FROM commission_rules WHERE barbearia_id = ? AND scope_key = ? AND ativo = 1 AND id <> ? AND (valido_ate IS NULL OR ? IS NULL OR valido_de < ?) AND (? IS NULL OR valido_ate IS NULL OR ? < valido_ate) LIMIT 1 FOR UPDATE', [tenantId, key, sourceRuleId || 0, rule.validUntil, rule.validUntil, rule.validFrom, rule.validFrom]);
        if (overlap.length) { await connection.rollback(); return { status: 409, code: 'COMMISSION_RULE_OVERLAP' }; }
        const lifecycle = rule.validFrom && rule.validFrom > new Date() ? 'scheduled' : 'active';
        const [inserted] = await connection.query('INSERT INTO commission_rules (nome, config_json, lifecycle, barbearia_id, profissional_id, servico_id, scope_key, tipo, valor, valor_bps, base, valido_de, valido_ate, versao, criado_por) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', [rule.name, JSON.stringify(rule.config), lifecycle, tenantId, rule.professionalId, rule.serviceId, key, rule.type, rule.value, rule.valueBps, rule.base, rule.validFrom, rule.validUntil, version, actorId]);
        await reconcileAppointmentsForRule(connection, { tenantId, actorId, rule });
        await connection.query("INSERT INTO audit_logs (barbearia_id, usuario_id, acao, recurso, recurso_id, detalhes) VALUES (?, ?, ?, 'commission_rule', ?, JSON_OBJECT('scope', ?, 'version', ?, 'draftId', ?, 'sourceRuleId', ?))", [tenantId, actorId, sourceRuleId == null ? 'commission.rule.published' : 'commission.rule.versioned', String(inserted.insertId), key, version, parsed, sourceRuleId]);
        created.push({ id: inserted.insertId, version, professionalId: rule.professionalId, serviceId: rule.serviceId });
      }
    }
    await connection.query("UPDATE commission_rule_drafts SET status = 'published', revision = revision + 1 WHERE id = ? AND barbearia_id = ? AND criado_por = ? AND status = 'editing'", [parsed, tenantId, actorId]);
    await connection.commit();
    return { status: 201, id: created[0].id, ids: created.map((item) => item.id), version: created[0].version, draftId: parsed, payload };
  } catch (error) { await connection.rollback().catch(() => {}); throw error; } finally { connection.release(); }
}

module.exports.createRuleVersionDraft = createRuleVersionDraft;
module.exports.createRuleDraft = createRuleDraft;
module.exports.getRuleDraft = getRuleDraft;
module.exports.updateRuleDraft = updateRuleDraft;
module.exports.publishRuleDraft = publishRuleDraft;
