const { pool } = require('../config/database');

const TAX_TYPES = new Set([
  'das_simples_nacional',
  'das_mei',
  'iss_municipal',
  'inss_cpp_folha',
  'icms_mercadorias',
  'taxas_licencas_municipais',
  'outro',
]);
const TAX_REGIMES = new Set([
  'nao_informado',
  'simples_nacional',
  'mei',
  'lucro_presumido',
  'lucro_real',
  'outro',
]);

function period(query = {}) {
  const valid = (value) => /^\d{4}-\d{2}-\d{2}$/.test(value || '');
  const today = new Date().toISOString().slice(0, 10);
  const from = valid(query.from) ? query.from : `${today.slice(0, 7)}-01`;
  const to = valid(query.to) ? query.to : today;
  return from <= to ? { from, to } : null;
}

function taxPayload(body = {}) {
  const type = String(body.type || '');
  const regime = String(body.regime || 'nao_informado');
  const calculationType = String(body.calculation_type || 'fixed');
  const value = Number(body.value ?? body.amount);
  const competenceDate = String(body.competence_date || '');
  const serviceIds = Array.isArray(body.service_ids)
    ? [...new Set(body.service_ids.map(Number).filter((id) => Number.isInteger(id) && id > 0))]
    : [];
  const valueValid = calculationType === 'percentage'
    ? Number.isFinite(value) && value > 0 && value <= 100
    : Number.isFinite(value) && value > 0 && value <= 999999999;
  if (!TAX_TYPES.has(type) || !TAX_REGIMES.has(regime) || !['fixed', 'percentage'].includes(calculationType) || !/^\d{4}-\d{2}-\d{2}$/.test(competenceDate) || !valueValid) return null;
  return {
    type,
    regime,
    calculationType,
    value: value.toFixed(4),
    competenceDate,
    serviceIds,
    note: String(body.note || '').trim().slice(0, 240) || null,
  };
}

function roundCurrency(value) {
  return Math.round((Number(value) + Number.EPSILON) * 100) / 100;
}

async function taxRowsForPeriod(tenantId, from, to) {
  const [rows] = await pool.query(
    `SELECT ate.id, ate.tipo type, ate.regime, ate.modo_calculo calculation_type,
            ate.valor value, ate.data_competencia competence_date, ate.observacao note,
            ate.criado_em created_at, ats.servico_id service_id, s.nome service_name
       FROM accounting_tax_entries ate
       LEFT JOIN accounting_tax_entry_services ats
         ON ats.accounting_tax_entry_id = ate.id AND ats.barbearia_id = ate.barbearia_id
       LEFT JOIN servicos s ON s.id = ats.servico_id AND s.barbearia_id = ate.barbearia_id
      WHERE ate.barbearia_id = ? AND ate.data_competencia BETWEEN ? AND ?
      ORDER BY ate.data_competencia DESC, ate.id DESC, s.nome ASC`,
    [tenantId, from, to],
  );
  const [basisRows] = await pool.query(
    `SELECT a.servico_id service_id,
            COALESCE(SUM(fm.amount), 0) revenue,
            COUNT(DISTINCT fm.appointment_id) service_count
       FROM financial_movements fm
       JOIN agendamentos a ON a.id = fm.appointment_id
      WHERE fm.barbearia_id = ? AND fm.movement_type = 'income'
        AND fm.status = 'confirmed' AND fm.movement_date BETWEEN ? AND ?
      GROUP BY a.servico_id`,
    [tenantId, `${from} 00:00:00`, `${to} 23:59:59`],
  );
  const basisByService = new Map(basisRows.map((row) => [
    Number(row.service_id),
    { revenue: Number(row.revenue || 0), count: Number(row.service_count || 0) },
  ]));
  const totalBasis = basisRows.reduce((sum, row) => sum + Number(row.revenue || 0), 0);
  const totalServiceCount = basisRows.reduce((sum, row) => sum + Number(row.service_count || 0), 0);
  const grouped = new Map();
  for (const row of rows) {
    if (!grouped.has(row.id)) {
      grouped.set(row.id, {
        id: row.id,
        type: row.type,
        regime: row.regime,
        calculation_type: row.calculation_type,
        value: Number(row.value || 0),
        competence_date: row.competence_date,
        note: row.note,
        created_at: row.created_at,
        service_ids: [],
        service_names: [],
      });
    }
    const item = grouped.get(row.id);
    if (row.service_id != null) {
      item.service_ids.push(Number(row.service_id));
      item.service_names.push(row.service_name || `Serviço #${row.service_id}`);
    }
  }
  return [...grouped.values()].map((item) => {
    const selectedIds = item.service_ids;
    const basis = selectedIds.length
      ? selectedIds.reduce((sum, serviceId) => sum + (basisByService.get(serviceId)?.revenue || 0), 0)
      : totalBasis;
    const serviceCount = selectedIds.length
      ? selectedIds.reduce((sum, serviceId) => sum + (basisByService.get(serviceId)?.count || 0), 0)
      : totalServiceCount;
    const amount = item.calculation_type === 'percentage'
      ? basis * item.value / 100
      : selectedIds.length ? serviceCount * item.value : item.value;
    return {
      ...item,
      basis_amount: roundCurrency(basis),
      service_count: serviceCount,
      amount: roundCurrency(amount),
    };
  });
}

async function accounts(req, res, next) {
  try {
    const [rows] = await pool.query(
      `SELECT id, parent_id, codigo code, nome name, natureza nature, ativo active
         FROM accounting_accounts WHERE barbearia_id = ? ORDER BY codigo`, [req.tenant.id],
    );
    return res.json({ data: rows, requestId: req.requestId });
  } catch (error) { return next(error); }
}

async function entries(req, res, next) {
  try {
    const [rows] = await pool.query(
      `SELECT ae.id, ae.descricao description, ae.data_competencia competence_date, ae.status,
              ae.source_type, ae.source_id,
              JSON_ARRAYAGG(JSON_OBJECT('accountId', aa.id, 'code', aa.codigo, 'account', aa.nome,
                'type', ael.tipo, 'amount', ael.valor)) lines
         FROM accounting_entries ae
         JOIN accounting_entry_lines ael ON ael.entry_id = ae.id
         JOIN accounting_accounts aa ON aa.id = ael.account_id AND aa.barbearia_id = ae.barbearia_id
        WHERE ae.barbearia_id = ?
        GROUP BY ae.id ORDER BY ae.data_competencia DESC, ae.id DESC LIMIT 100`, [req.tenant.id],
    );
    return res.json({ data: rows, requestId: req.requestId });
  } catch (error) { return next(error); }
}

async function result(req, res, next) {
  const dates = period(req.query);
  if (!dates) return res.status(422).json({ code: 'INVALID_PERIOD', erro: 'Periodo invalido.', requestId: req.requestId });
  const { from, to } = dates;
  try {
    const [[financial]] = await pool.query(
      `SELECT
          COALESCE(SUM(CASE WHEN movement_type = 'income' THEN amount ELSE 0 END), 0) sales,
          COALESCE(SUM(CASE WHEN movement_type IN ('expense','refund','reversal') THEN amount ELSE 0 END), 0) expenses
         FROM financial_movements
        WHERE barbearia_id = ? AND movement_date BETWEEN ? AND ? AND status = 'confirmed'`,
      [req.tenant.id, `${from} 00:00:00`, `${to} 23:59:59`],
    );
    const taxRows = await taxRowsForPeriod(req.tenant.id, from, to);
    const sales = Number(financial.sales || 0);
    const expenses = Number(financial.expenses || 0);
    const taxAmount = taxRows.reduce((sum, tax) => sum + Number(tax.amount || 0), 0);
    return res.json({ data: { from, to, sales, revenue: sales, expenses, taxes: taxAmount, result: sales - taxAmount - expenses, label: 'Resultado gerencial' }, requestId: req.requestId });
  } catch (error) { return next(error); }
}

async function taxes(req, res, next) {
  const dates = period(req.query);
  if (!dates) return res.status(422).json({ code: 'INVALID_PERIOD', erro: 'Periodo invalido.', requestId: req.requestId });
  try {
    const rows = await taxRowsForPeriod(req.tenant.id, dates.from, dates.to);
    return res.json({ data: rows, requestId: req.requestId });
  } catch (error) { return next(error); }
}

async function createTax(req, res, next) {
  const payload = taxPayload(req.body);
  if (!payload) return res.status(422).json({ code: 'VALIDATION_ERROR', erro: 'Informe tipo, competencia e um valor de imposto valido.', requestId: req.requestId });
  const connection = await pool.getConnection();
  try {
    if (payload.serviceIds.length > 0) {
      const placeholders = payload.serviceIds.map(() => '?').join(',');
      const [services] = await connection.query(
        `SELECT id FROM servicos WHERE barbearia_id = ? AND ativo = 1 AND id IN (${placeholders})`,
        [req.tenant.id, ...payload.serviceIds],
      );
      if (services.length !== payload.serviceIds.length) {
        return res.status(422).json({ code: 'INVALID_TAX_SERVICES', erro: 'Um ou mais serviços não pertencem a esta barbearia.', requestId: req.requestId });
      }
    }
    await connection.beginTransaction();
    const [result] = await connection.query(
      `INSERT INTO accounting_tax_entries
        (barbearia_id, tipo, regime, modo_calculo, valor, data_competencia, observacao, criado_por)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [req.tenant.id, payload.type, payload.regime, payload.calculationType, payload.value, payload.competenceDate, payload.note, req.usuario.id],
    );
    if (payload.serviceIds.length > 0) {
      await connection.query(
        `INSERT INTO accounting_tax_entry_services (accounting_tax_entry_id, barbearia_id, servico_id)
         VALUES ${payload.serviceIds.map(() => '(?, ?, ?)').join(', ')}`,
        payload.serviceIds.flatMap((serviceId) => [result.insertId, req.tenant.id, serviceId]),
      );
    }
    await connection.commit();
    return res.status(201).json({ data: { id: result.insertId, ...payload }, message: 'Imposto cadastrado com sucesso.', requestId: req.requestId });
  } catch (error) {
    await connection.rollback().catch(() => {});
    return next(error);
  }
  finally { connection.release(); }
}

async function deleteTax(req, res, next) {
  const id = Number.parseInt(req.params.id, 10);
  if (!Number.isInteger(id) || id <= 0) return res.status(422).json({ code: 'VALIDATION_ERROR', erro: 'Lancamento invalido.', requestId: req.requestId });
  try {
    const [result] = await pool.query('DELETE FROM accounting_tax_entries WHERE id = ? AND barbearia_id = ?', [id, req.tenant.id]);
    if (!result.affectedRows) return res.status(404).json({ code: 'TAX_NOT_FOUND', erro: 'Imposto nao encontrado.', requestId: req.requestId });
    return res.json({ message: 'Imposto removido com sucesso.', requestId: req.requestId });
  } catch (error) { return next(error); }
}

module.exports = { accounts, entries, result, taxes, createTax, deleteTax };
