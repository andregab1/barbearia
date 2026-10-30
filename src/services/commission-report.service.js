// * Relatorios de comissao. Sao leituras derivadas e preservam os filtros de
// * periodo/profissional recebidos pelo controller.
const { pool } = require('../config/database');

function positiveId(value) {
  const parsed = Number.parseInt(value, 10);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : null;
}

function parseDate(value) {
  if (!value) return null;
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function formatDate(value) {
  return value.toISOString().slice(0, 10);
}

function addDay(value) {
  const parsed = parseDate(value);
  if (!parsed) return null;
  parsed.setUTCDate(parsed.getUTCDate() + 1);
  return formatDate(parsed);
}

function normalizePeriod(from, to) {
  const now = new Date();
  const start = parseDate(from) || new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1));
  const endInput = parseDate(to) || now;
  const end = new Date(Date.UTC(endInput.getUTCFullYear(), endInput.getUTCMonth(), endInput.getUTCDate() + 1));
  if (end <= start) return null;
  return { from: formatDate(start), to: formatDate(end) };
}

function numberValue(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

function signed(value) {
  return numberValue(value);
}

function baseAmount(row) {
  if (row.type === 'fixed') return null;
  return row.base === 'gross' ? numberValue(row.gross_amount) : numberValue(row.original_net_amount);
}

// * CONSULTAR: consolida calculado, liberado, pago e saldo pendente.
async function overview({ tenantId, professionalId = null, from = null, to = null, ownProfessionalId = null }) {
  const period = normalizePeriod(from, to);
  if (!period) return { status: 422, code: 'INVALID_PERIOD' };

  const selectedProfessional = ownProfessionalId != null ? ownProfessionalId : positiveId(professionalId);
  const entitlementWhere = ['ce.barbearia_id = ?', "ce.status <> 'reversed'", 'ce.completed_at >= ?', 'ce.completed_at < ?'];
  const entitlementParams = [tenantId, `${period.from} 00:00:00`, `${period.to} 00:00:00`];
  const entryWhere = ['e.barbearia_id = ?', 'e.effective_at >= ?', 'e.effective_at < ?'];
  const entryParams = [tenantId, `${period.from} 00:00:00`, `${period.to} 00:00:00`];
  const paymentWhere = ['sp.barbearia_id = ?', 'sp.status = \'confirmed\'', 'sp.paid_at >= ?', 'sp.paid_at < ?'];
  const paymentParams = [tenantId, `${period.from} 00:00:00`, `${period.to} 00:00:00`];
  const advanceWhere = ['a.barbearia_id = ?', "a.status = 'confirmed'"];
  const advanceParams = [tenantId];

  if (selectedProfessional != null) {
    entitlementWhere.push('ce.profissional_id = ?');
    entitlementParams.push(selectedProfessional);
    entryWhere.push('e.profissional_id = ?');
    entryParams.push(selectedProfessional);
    paymentWhere.push('s.profissional_id = ?');
    paymentParams.push(selectedProfessional);
    advanceWhere.push('a.profissional_id = ?');
    advanceParams.push(selectedProfessional);
  }

  const [[calculated]] = await pool.query(
    `SELECT COALESCE(SUM(ce.total_commission), 0) calculated,
            COUNT(DISTINCT ce.id) entitlement_count
       FROM commission_entitlements ce
      WHERE ${entitlementWhere.join(' AND ')}`,
    entitlementParams,
  );
  const [[released]] = await pool.query(
    `SELECT COALESCE(SUM(e.signed_amount), 0) released,
            COALESCE(SUM(CASE WHEN e.kind IN ('manual_adjustment', 'correction') THEN e.signed_amount ELSE 0 END), 0) adjustments
       FROM commission_entries e
      WHERE ${entryWhere.join(' AND ')}`,
    entryParams,
  );
  const [[paid]] = await pool.query(
    `SELECT COALESCE(SUM(sp.amount), 0) paid
       FROM commission_settlement_payments sp
       JOIN commission_settlements s ON s.id = sp.settlement_id
      WHERE ${paymentWhere.join(' AND ')}`,
    paymentParams,
  );
  const [[advances]] = await pool.query(
    `SELECT COALESCE(SUM(a.valor - COALESCE(allocated.amount, 0)), 0) outstanding
       FROM commission_advances a
       LEFT JOIN (
         SELECT advance_id, SUM(amount) amount
           FROM commission_advance_allocations
          GROUP BY advance_id
       ) allocated ON allocated.advance_id = a.id
      WHERE ${advanceWhere.join(' AND ')}`,
    advanceParams,
  );

  const allProfessionalFilter = selectedProfessional == null ? '' : ' AND e.profissional_id = ?';
  const allProfessionalParams = selectedProfessional == null ? [tenantId] : [tenantId, selectedProfessional];
  const [[allReleased]] = await pool.query('SELECT COALESCE(SUM(e.signed_amount), 0) amount FROM commission_entries e WHERE e.barbearia_id = ?' + allProfessionalFilter, allProfessionalParams);
  const [[allPaid]] = await pool.query('SELECT COALESCE(SUM(sp.amount), 0) amount FROM commission_settlement_payments sp JOIN commission_settlements s ON s.id = sp.settlement_id WHERE sp.barbearia_id = ? AND sp.status = \'confirmed\'' + (selectedProfessional == null ? '' : ' AND s.profissional_id = ?'), allProfessionalParams);
  const calculatedAmount = numberValue(calculated.calculated);
  const releasedAmount = signed(released.released);
  const paidAmount = numberValue(paid.paid);
  const advancesOutstanding = Math.max(0, numberValue(advances.outstanding));
  const availableNow = Math.max(0, numberValue(allReleased.amount) - numberValue(allPaid.amount) - advancesOutstanding);

  const professionalFilters = ['ce.barbearia_id = ?', 'ce.completed_at >= ?', 'ce.completed_at < ?'];
  const professionalParams = [tenantId, period.from + ' 00:00:00', period.to + ' 00:00:00'];
  if (selectedProfessional != null) { professionalFilters.push('ce.profissional_id = ?'); professionalParams.push(selectedProfessional); }
  const [professionalRows] = await pool.query('SELECT ce.profissional_id professional_id, pu.nome professional_name, COALESCE(SUM(ce.total_commission), 0) calculated FROM commission_entitlements ce JOIN colaboradores c ON c.id = ce.profissional_id JOIN usuarios pu ON pu.id = c.usuario_id WHERE ' + professionalFilters.join(' AND ') + ' GROUP BY ce.profissional_id, pu.nome ORDER BY pu.nome, ce.profissional_id', professionalParams);
  const groupValues = (rows, key) => new Map(rows.map((row) => [Number(row.professional_id), numberValue(row[key])]));
  const groupQuery = async (sql, params) => (await pool.query(sql, params))[0];
  const periodStart = period.from + ' 00:00:00';
  const periodEnd = period.to + ' 00:00:00';
  const professionalFilterSql = selectedProfessional == null ? '' : ' AND professional_id = ?';
  const professionalFilterParams = selectedProfessional == null ? [] : [selectedProfessional];
  const releasedByProfessional = await groupQuery('SELECT e.profissional_id professional_id, COALESCE(SUM(e.signed_amount), 0) released, COALESCE(SUM(CASE WHEN e.kind IN (\'manual_adjustment\', \'correction\') THEN e.signed_amount ELSE 0 END), 0) adjustments FROM commission_entries e WHERE e.barbearia_id = ? AND e.effective_at >= ? AND e.effective_at < ?' + professionalFilterSql.replace('professional_id', 'e.profissional_id') + ' GROUP BY e.profissional_id', [tenantId, periodStart, periodEnd, ...professionalFilterParams]);
  const paidByProfessional = await groupQuery('SELECT s.profissional_id professional_id, COALESCE(SUM(sp.amount), 0) paid FROM commission_settlement_payments sp JOIN commission_settlements s ON s.id = sp.settlement_id WHERE sp.barbearia_id = ? AND sp.status = \'confirmed\' AND sp.paid_at >= ? AND sp.paid_at < ?' + professionalFilterSql.replace('professional_id', 's.profissional_id') + ' GROUP BY s.profissional_id', [tenantId, periodStart, periodEnd, ...professionalFilterParams]);
  const advancesByProfessional = await groupQuery('SELECT a.profissional_id professional_id, COALESCE(SUM(a.valor - COALESCE(allocated.amount, 0)), 0) outstanding FROM commission_advances a LEFT JOIN (SELECT advance_id, SUM(amount) amount FROM commission_advance_allocations GROUP BY advance_id) allocated ON allocated.advance_id = a.id WHERE a.barbearia_id = ? AND a.status = \'confirmed\'' + (selectedProfessional == null ? '' : ' AND a.profissional_id = ?') + ' GROUP BY a.profissional_id', selectedProfessional == null ? [tenantId] : [tenantId, selectedProfessional]);
  const releasedMap = groupValues(releasedByProfessional, 'released');
  const paidMap = groupValues(paidByProfessional, 'paid');
  const advancesMap = groupValues(advancesByProfessional, 'outstanding');
  const adjustmentsMap = groupValues(releasedByProfessional, 'adjustments');
  const allReleasedByProfessional = await groupQuery('SELECT e.profissional_id professional_id, COALESCE(SUM(e.signed_amount), 0) released FROM commission_entries e WHERE e.barbearia_id = ?' + (selectedProfessional == null ? '' : ' AND e.profissional_id = ?') + ' GROUP BY e.profissional_id', selectedProfessional == null ? [tenantId] : [tenantId, selectedProfessional]);
  const allPaidByProfessional = await groupQuery('SELECT s.profissional_id professional_id, COALESCE(SUM(sp.amount), 0) paid FROM commission_settlement_payments sp JOIN commission_settlements s ON s.id = sp.settlement_id WHERE sp.barbearia_id = ? AND sp.status = \'confirmed\'' + (selectedProfessional == null ? '' : ' AND s.profissional_id = ?') + ' GROUP BY s.profissional_id', selectedProfessional == null ? [tenantId] : [tenantId, selectedProfessional]);
  const allReleasedMap = groupValues(allReleasedByProfessional, 'released');
  const allPaidMap = groupValues(allPaidByProfessional, 'paid');
  const professionals = professionalRows.map((row) => {
    const professionalId = Number(row.professional_id);
    const professionalCalculated = numberValue(row.calculated);
    const professionalReleased = releasedMap.get(professionalId) || 0;
    const professionalCurrentReleased = allReleasedMap.get(professionalId) || 0;
    const professionalPaid = paidMap.get(professionalId) || 0;
    const professionalCurrentPaid = allPaidMap.get(professionalId) || 0;
    const professionalAdvances = Math.max(0, advancesMap.get(professionalId) || 0);
    return { professional_id: professionalId, professional_name: row.professional_name, calculated: professionalCalculated, to_release: Math.max(0, professionalCalculated - professionalReleased), released: professionalReleased, available: Math.max(0, professionalReleased - professionalPaid - professionalAdvances), paid_period: professionalPaid, advances_to_compensate: professionalAdvances, adjustments: adjustmentsMap.get(professionalId) || 0 };
  });

  return {
    status: 200,
    period,
    calculated: calculatedAmount,
    to_release: Math.max(0, calculatedAmount - releasedAmount),
    released: releasedAmount,
    available: availableNow,
    paid_period: paidAmount,
    advances_to_compensate: advancesOutstanding,
    adjustments: signed(released.adjustments),
    entitlement_count: Number(calculated.entitlement_count || 0),
    professionals,
  };
}

async function statement({ tenantId, professionalId = null, from = null, to = null, ownProfessionalId = null }) {
  const period = normalizePeriod(from, to);
  if (!period) return { status: 422, code: 'INVALID_PERIOD' };
  const selectedProfessional = ownProfessionalId != null ? ownProfessionalId : positiveId(professionalId);
  const params = [tenantId, `${period.from} 00:00:00`, `${period.to} 00:00:00`];
  const filters = ['ce.barbearia_id = ?', "ce.status <> 'reversed'", 'ce.completed_at >= ?', 'ce.completed_at < ?'];
  if (selectedProfessional != null) {
    filters.push('ce.profissional_id = ?');
    params.push(selectedProfessional);
  }

  const [items] = await pool.query(
    `SELECT ce.id entitlement_id, ce.agendamento_id appointment_id, ce.servico_id service_id,
            ce.profissional_id professional_id, pu.nome professional_name, s.nome service_name,
            ce.completed_at, ce.gross_amount, ce.discount_amount, ce.original_net_amount,
            ce.total_commission, ce.status entitlement_status, ce.snapshot_json,
            r.id rule_id, r.tipo type, r.valor value, r.valor_bps value_bps, r.base,
            r.valido_de valid_from, r.valido_ate valid_until,
            COALESCE(SUM(e.signed_amount), 0) released_amount
       FROM commission_entitlements ce
       JOIN colaboradores c ON c.id = ce.profissional_id
       JOIN usuarios pu ON pu.id = c.usuario_id
       JOIN servicos s ON s.id = ce.servico_id
       LEFT JOIN commission_rules r ON r.id = ce.rule_id
       LEFT JOIN commission_entries e ON e.entitlement_id = ce.id
      WHERE ${filters.join(' AND ')}
      GROUP BY ce.id, ce.agendamento_id, ce.servico_id, ce.profissional_id, pu.nome,
               s.nome, ce.completed_at, ce.gross_amount, ce.discount_amount,
               ce.original_net_amount, ce.total_commission, ce.status, ce.snapshot_json,
               r.id, r.tipo, r.valor, r.valor_bps, r.base, r.valido_de, r.valido_ate
      ORDER BY ce.completed_at DESC, ce.id DESC
      LIMIT 500`,
    params,
  );

  const entryParams = [tenantId, `${period.from} 00:00:00`, `${period.to} 00:00:00`];
  const entryFilters = ['e.barbearia_id = ?', 'e.effective_at >= ?', 'e.effective_at < ?'];
  if (selectedProfessional != null) {
    entryFilters.push('e.profissional_id = ?');
    entryParams.push(selectedProfessional);
  }
  const [ledger] = await pool.query(
    `SELECT e.id, e.entitlement_id, e.profissional_id professional_id,
            pu.nome professional_name, e.agendamento_id appointment_id, e.kind,
            e.signed_amount amount, e.reason, e.source_event_id, e.payment_id,
            e.refund_id, e.effective_at, e.criado_em created_at
       FROM commission_entries e
       JOIN colaboradores c ON c.id = e.profissional_id
       JOIN usuarios pu ON pu.id = c.usuario_id
      WHERE ${entryFilters.join(' AND ')}
      ORDER BY e.effective_at DESC, e.id DESC
      LIMIT 500`,
    entryParams,
  );

  const professionalEntryFilter = selectedProfessional == null ? '' : ' AND profissional_id = ?';
  const professionalParamsBefore = selectedProfessional == null ? [tenantId, period.from + ' 00:00:00'] : [tenantId, period.from + ' 00:00:00', selectedProfessional];
  const [openingEntryRows] = await pool.query('SELECT COALESCE(SUM(e.signed_amount), 0) amount FROM commission_entries e WHERE e.barbearia_id = ? AND e.effective_at < ?' + (selectedProfessional == null ? '' : ' AND e.profissional_id = ?'), professionalParamsBefore);
  const paymentProfessional = selectedProfessional == null ? '' : ' AND s.profissional_id = ?';
  const paymentBeforeParams = selectedProfessional == null ? [tenantId, period.from + ' 00:00:00'] : [tenantId, period.from + ' 00:00:00', selectedProfessional];
  const [openingPaymentRows] = await pool.query('SELECT COALESCE(SUM(sp.amount), 0) amount FROM commission_settlement_payments sp JOIN commission_settlements s ON s.id = sp.settlement_id WHERE sp.barbearia_id = ? AND sp.status = \'confirmed\' AND sp.paid_at < ?' + paymentProfessional, paymentBeforeParams);
  const [openingAdvanceRows] = await pool.query('SELECT COALESCE(SUM(aa.amount), 0) amount FROM commission_advance_allocations aa JOIN commission_advances a ON a.id = aa.advance_id WHERE aa.barbearia_id = ? AND aa.criado_em < ?' + (selectedProfessional == null ? '' : ' AND a.profissional_id = ?'), professionalParamsBefore);
  const paymentPeriodParams = selectedProfessional == null ? [tenantId, period.from + ' 00:00:00', period.to + ' 00:00:00'] : [tenantId, period.from + ' 00:00:00', period.to + ' 00:00:00', selectedProfessional];
  const [paymentRows] = await pool.query('SELECT sp.id, s.profissional_id, sp.amount, sp.paid_at, sp.created_at, sp.settlement_id FROM commission_settlement_payments sp JOIN commission_settlements s ON s.id = sp.settlement_id WHERE sp.barbearia_id = ? AND sp.status = \'confirmed\' AND sp.paid_at >= ? AND sp.paid_at < ?' + paymentProfessional, paymentPeriodParams);
  const [advanceRows] = await pool.query('SELECT aa.id, a.profissional_id, aa.amount, aa.criado_em, aa.advance_id, aa.settlement_id FROM commission_advance_allocations aa JOIN commission_advances a ON a.id = aa.advance_id WHERE aa.barbearia_id = ? AND aa.criado_em >= ? AND aa.criado_em < ?' + (selectedProfessional == null ? '' : ' AND a.profissional_id = ?'), paymentPeriodParams);
  const openingBalance = numberValue(openingEntryRows[0]?.amount) - numberValue(openingPaymentRows[0]?.amount) - numberValue(openingAdvanceRows[0]?.amount);
  const ledgerRows = [
    ...ledger.map((row) => ({ ...row, amount: numberValue(row.amount), occurred_at: row.effective_at, recorded_at: row.created_at, direction: numberValue(row.amount) >= 0 ? 'credit' : 'debit' })),
    ...paymentRows.map((row) => ({ id: 'payment-' + row.id, kind: 'payment', amount: -numberValue(row.amount), professional_id: row.profissional_id, settlement_id: row.settlement_id, occurred_at: row.paid_at, recorded_at: row.created_at, direction: 'debit', reference: 'commission_payment:' + row.id })),
    ...advanceRows.map((row) => ({ id: 'advance-' + row.id, kind: 'advance_applied', amount: -numberValue(row.amount), professional_id: row.profissional_id, advance_id: row.advance_id, settlement_id: row.settlement_id, occurred_at: row.criado_em, recorded_at: row.criado_em, direction: 'debit', reference: 'commission_advance:' + row.advance_id })),
  ].sort((a, b) => { const time = new Date(a.occurred_at).getTime() - new Date(b.occurred_at).getTime(); return time || String(a.id).localeCompare(String(b.id), undefined, { numeric: true }); });
  let runningBalance = openingBalance;
  for (const row of ledgerRows) { runningBalance += numberValue(row.amount); row.balance = Number(runningBalance.toFixed(2)); }
  const closingBalance = Number(runningBalance.toFixed(2));
  return {
    status: 200,
    period,
    items: items.map((item) => {
      let snapshot = {};
      try { snapshot = item.snapshot_json ? JSON.parse(item.snapshot_json) : {}; } catch (_) { snapshot = {}; }
      const total = numberValue(item.total_commission);
      const released = signed(item.released_amount);
      return {
        ...item,
        base_amount: baseAmount(item),
        pending_amount: Math.max(0, total - released),
        rule: item.rule_id == null ? null : {
          id: item.rule_id,
          type: item.type,
          value: item.value,
          value_bps: item.value_bps,
          base: item.base,
          valid_from: item.valid_from,
          valid_until: item.valid_until,
        },
        snapshot,
      };
    }),
    ledger: ledgerRows,
    opening_balance: Number(openingBalance.toFixed(2)),
    closing_balance: closingBalance,
  };
}

module.exports = { overview, statement, normalizePeriod, addDay };
