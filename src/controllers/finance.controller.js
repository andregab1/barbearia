const { pool } = require('../config/database');
const { obterBarbeariaAdministrada } = require('../utils/access');
const { errorBody } = require('../middlewares/request.middleware');

function validDate(value) {
  return /^\d{4}-\d{2}-\d{2}$/.test(String(value || ''));
}

async function tenant(req, res) {
  const value = await obterBarbeariaAdministrada(req.usuario.id, req.params.barbearia_id);
  if (!value) res.status(403).json(errorBody(req, 'FORBIDDEN', 'Acesso não permitido.'));
  return value;
}

async function summary(req, res) {
  const shop = await tenant(req, res);
  if (!shop) return;
  const from = validDate(req.query.from) ? req.query.from : new Date().toISOString().slice(0, 7) + '-01';
  const to = validDate(req.query.to) ? req.query.to : new Date().toISOString().slice(0, 10);
  const [rows] = await pool.query(
    `SELECT
       COALESCE(SUM(CASE WHEN tipo = 'income' THEN valor ELSE 0 END), 0) AS income,
       COALESCE(SUM(CASE WHEN tipo IN ('expense','refund','commission') THEN valor ELSE 0 END), 0) AS expenses,
       COUNT(*) AS entries
     FROM cash_entries
     WHERE barbearia_id = ? AND ocorrido_em >= ? AND ocorrido_em < DATE_ADD(?, INTERVAL 1 DAY)`,
    [shop.id, from, to],
  );
  const income = Number(rows[0].income);
  const expenses = Number(rows[0].expenses);
  return res.json({ data: { from, to, income, expenses, balance: income - expenses, entries: Number(rows[0].entries) }, requestId: req.requestId });
}

async function entries(req, res) {
  const shop = await tenant(req, res);
  if (!shop) return;
  const page = Math.max(1, Number.parseInt(req.query.page, 10) || 1);
  const limit = Math.min(100, Math.max(1, Number.parseInt(req.query.limit, 10) || 25));
  const offset = (page - 1) * limit;
  const [rows] = await pool.query(
    `SELECT id, tipo, categoria, descricao, valor, ocorrido_em, criado_em
     FROM cash_entries WHERE barbearia_id = ? ORDER BY ocorrido_em DESC, id DESC LIMIT ? OFFSET ?`,
    [shop.id, limit, offset],
  );
  const [[count]] = await pool.query('SELECT COUNT(*) AS total FROM cash_entries WHERE barbearia_id = ?', [shop.id]);
  return res.json({ data: rows, pagination: { page, limit, total: Number(count.total), pages: Math.ceil(Number(count.total) / limit) }, requestId: req.requestId });
}

async function createExpense(req, res) {
  const shop = await tenant(req, res);
  if (!shop) return;
  const category = typeof req.body.category === 'string' ? req.body.category.trim() : '';
  const description = req.body.description == null
    ? null
    : typeof req.body.description === 'string' ? req.body.description.trim() || null : undefined;
  const amount = typeof req.body.amount === 'number' || typeof req.body.amount === 'string'
    ? Number(req.body.amount) : Number.NaN;
  const occurredAt = req.body.occurred_at ? new Date(req.body.occurred_at) : new Date();
  const validCategory = /^[\p{L}\p{N}][\p{L}\p{N}\s&+.,()/-]{1,59}$/u.test(category);
  if (!validCategory || description === undefined || (description && description.length > 240) || !Number.isFinite(amount) || amount <= 0 || amount > 99999999 || Number.isNaN(occurredAt.getTime())) {
    return res.status(422).json(errorBody(req, 'VALIDATION_ERROR', 'Categoria, valor e data são obrigatórios e devem ser válidos.'));
  }
  const [result] = await pool.query(
    `INSERT INTO cash_entries (barbearia_id, criado_por, tipo, categoria, descricao, valor, ocorrido_em)
     VALUES (?, ?, 'expense', ?, ?, ?, ?)`,
    [shop.id, req.usuario.id, category, description, amount, occurredAt],
  );
  await pool.query(
    `INSERT INTO audit_logs (barbearia_id, usuario_id, acao, recurso, recurso_id, request_id, detalhes)
     VALUES (?, ?, 'expense.created', 'cash_entry', ?, ?, JSON_OBJECT('amount', ?, 'category', ?))`,
    [shop.id, req.usuario.id, String(result.insertId), req.requestId, amount, category],
  );
  return res.status(201).json({ data: { id: result.insertId }, message: 'Despesa registrada.', requestId: req.requestId });
}

module.exports = { summary, entries, createExpense };
