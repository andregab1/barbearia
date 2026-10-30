const { pool } = require('../config/database');
const { cents, decimal } = require('./financial.service');
const commissionService = require('./commission.service');

// * Servico operacional da tesouraria. As consultas sempre recebem tenantId;
// * os comandos de escrita validam estado, relacionamentos e transacao antes
// * de gerar movimento contabil ou auditoria.
const PAYMENT_METHODS = ['cash', 'pix', 'debit_card', 'credit_card', 'other'];

// * CONSULTAR: normaliza periodo, filtros e paginacao usados por todos os
// * paineis financeiros para que datas e limites tenham uma unica regra.
function parsePeriod(query = {}) {
  const datePattern = /^\d{4}-\d{2}-\d{2}$/;
  const today = new Date().toISOString().slice(0, 10);
  const from = datePattern.test(query.from || '') ? query.from : `${today.slice(0, 7)}-01`;
  const to = datePattern.test(query.to || '') ? query.to : today;
  if (from > to) return null;
  const professionalId = Number.parseInt(query.professional_id, 10);
  const serviceId = Number.parseInt(query.service_id, 10);
  return {
    from, to,
    professionalId: Number.isInteger(professionalId) && professionalId > 0 ? professionalId : null,
    serviceId: Number.isInteger(serviceId) && serviceId > 0 ? serviceId : null,
  };
}

function appointmentScope(filters, alias = 'a') {
  const clauses = [];
  const params = [];
  if (filters.professionalId) { clauses.push(`${alias}.colaborador_id = ?`); params.push(filters.professionalId); }
  if (filters.serviceId) { clauses.push(`${alias}.servico_id = ?`); params.push(filters.serviceId); }
  return { sql: clauses.length ? ` AND ${clauses.join(' AND ')}` : '', params };
}

// * CONSULTAR: consolida entradas, despesas, recebimentos e saldo do tenant.
async function getDashboard(tenantId, query) {
  const filters = parsePeriod(query);
  if (!filters) return { error: 'INVALID_PERIOD' };
  const scope = appointmentScope(filters);
  const appointmentParams = [tenantId, filters.from, filters.to, ...scope.params];
  const [[appointments]] = await pool.query(
    `SELECT
       COALESCE(SUM(CASE WHEN a.status IN ('pendente','confirmado') THEN a.valor_cobrado ELSE 0 END), 0) forecast,
       COALESCE(SUM(CASE WHEN a.status = 'concluido' THEN a.valor_cobrado ELSE 0 END), 0) realized,
       COUNT(*) total,
       SUM(a.status = 'confirmado') confirmed,
       SUM(a.status = 'concluido') completed,
       SUM(a.status = 'cancelado') cancelled
     FROM agendamentos a JOIN colaboradores c ON c.id = a.colaborador_id
     WHERE c.barbearia_id = ? AND DATE(a.data_hora) BETWEEN ? AND ?${scope.sql}`,
    appointmentParams,
  );
  const movementParams = [tenantId, filters.from, filters.to];
  let movementScope = '';
  if (filters.professionalId) { movementScope += ' AND fm.professional_id = ?'; movementParams.push(filters.professionalId); }
  if (filters.serviceId) { movementScope += ' AND a.servico_id = ?'; movementParams.push(filters.serviceId); }
  const [[movements]] = await pool.query(
    `SELECT
       COALESCE(SUM(CASE WHEN fm.movement_type = 'income' THEN fm.amount ELSE 0 END), 0) received,
       COALESCE(SUM(CASE WHEN fm.movement_type = 'expense' THEN fm.amount ELSE 0 END), 0) expenses,
       COALESCE(SUM(CASE WHEN fm.movement_type IN ('refund','reversal') THEN fm.amount ELSE 0 END), 0) refunds
     FROM financial_movements fm
     LEFT JOIN agendamentos a ON a.id = fm.appointment_id
     WHERE fm.barbearia_id = ? AND DATE(fm.movement_date) BETWEEN ? AND ?
       AND fm.status = 'confirmed'${movementScope}`,
    movementParams,
  );
  const [[receivable]] = await pool.query(
    `SELECT COALESCE(SUM(GREATEST(a.valor_cobrado - COALESCE(paid.total, 0), 0)), 0) amount
       FROM agendamentos a JOIN colaboradores c ON c.id = a.colaborador_id
       LEFT JOIN (
         SELECT p.agendamento_id, SUM(p.valor - COALESCE(r.refunded, 0)) total
           FROM payments p
           LEFT JOIN (SELECT payment_id, SUM(valor) refunded FROM refunds WHERE status = 'processed' GROUP BY payment_id) r ON r.payment_id = p.id
          WHERE p.status IN ('paid','partially_refunded','refunded') GROUP BY p.agendamento_id
       ) paid ON paid.agendamento_id = a.id
      WHERE c.barbearia_id = ? AND a.status = 'concluido'
        AND DATE(a.data_hora) BETWEEN ? AND ?${scope.sql}`,
    appointmentParams,
  );
  const [evolution] = await pool.query(
    `SELECT DATE(fm.movement_date) date,
            SUM(CASE WHEN fm.movement_type = 'income' THEN fm.amount ELSE 0 END) income,
            SUM(CASE WHEN fm.movement_type IN ('expense','refund','reversal') THEN fm.amount ELSE 0 END) expense
       FROM financial_movements fm LEFT JOIN agendamentos a ON a.id = fm.appointment_id
      WHERE fm.barbearia_id = ? AND DATE(fm.movement_date) BETWEEN ? AND ? AND fm.status = 'confirmed'${movementScope}
      GROUP BY DATE(fm.movement_date) ORDER BY date`, movementParams,
  );
  const [professionals] = await pool.query(
    `SELECT c.id professional_id, u.nome professional,
            COUNT(DISTINCT a.id) total,
            COUNT(DISTINCT CASE WHEN a.status = 'confirmado' THEN a.id END) confirmed,
            COUNT(DISTINCT CASE WHEN a.status = 'concluido' THEN a.id END) completed,
            COUNT(DISTINCT CASE WHEN a.status = 'cancelado' THEN a.id END) cancelled,
            COALESCE(SUM(CASE WHEN a.status = 'concluido' THEN a.valor_cobrado ELSE 0 END), 0) realized,
            COALESCE((SELECT SUM(fm.amount) FROM financial_movements fm
              WHERE fm.barbearia_id = c.barbearia_id AND fm.professional_id = c.id
                AND fm.movement_type = 'income' AND fm.status = 'confirmed'
                AND DATE(fm.movement_date) BETWEEN ? AND ?), 0) received
       FROM colaboradores c JOIN usuarios u ON u.id = c.usuario_id
       LEFT JOIN agendamentos a ON a.colaborador_id = c.id AND DATE(a.data_hora) BETWEEN ? AND ?
        ${filters.serviceId ? 'AND a.servico_id = ?' : ''}
      WHERE c.barbearia_id = ? AND c.ativo = 1
      GROUP BY c.id, u.nome ORDER BY realized DESC`,
    [filters.from, filters.to, filters.from, filters.to, ...(filters.serviceId ? [filters.serviceId] : []), tenantId],
  );
  const latest = await listMovements(tenantId, { ...query, limit: 5 });
  const realized = Number(appointments.realized || 0);
  const received = Number(movements.received || 0);
  const expenses = Number(movements.expenses || 0);
  const refunds = Number(movements.refunds || 0);
  const completed = Number(appointments.completed || 0);
  return {
    period: { from: filters.from, to: filters.to }, forecast: Number(appointments.forecast || 0),
    realized, received, expenses, refunds, receivable: Number(receivable.amount || 0),
    balance: received - expenses - refunds, averageTicket: completed ? realized / completed : 0,
    appointments: { total: Number(appointments.total || 0), confirmed: Number(appointments.confirmed || 0), completed, cancelled: Number(appointments.cancelled || 0) },
    evolution: evolution.map((row) => ({ date: row.date, income: Number(row.income), expense: Number(row.expense) })),
    professionals: professionals.map((row) => ({ ...row, average_ticket: Number(row.completed) ? Number(row.realized) / Number(row.completed) : 0 })),
    latestMovements: latest,
  };
}

// * CONSULTAR: lista o livro de movimentacoes sem alterar dados persistidos.
async function listMovements(tenantId, query = {}) {
  const filters = parsePeriod(query);
  if (!filters) return [];
  const page = Math.max(1, Number.parseInt(query.page, 10) || 1);
  const limit = Math.min(100, Math.max(1, Number.parseInt(query.limit, 10) || 25));
  const where = ['fm.barbearia_id = ?', 'DATE(fm.movement_date) BETWEEN ? AND ?'];
  const params = [tenantId, filters.from, filters.to];
  if (filters.professionalId) { where.push('fm.professional_id = ?'); params.push(filters.professionalId); }
  if (filters.serviceId) { where.push('a.servico_id = ?'); params.push(filters.serviceId); }
  if (['income','expense','refund','reversal','adjustment'].includes(query.type)) { where.push('fm.movement_type = ?'); params.push(query.type); }
  if (['confirmed','reversed','cancelled'].includes(query.status)) { where.push('fm.status = ?'); params.push(query.status); }
  if (PAYMENT_METHODS.includes(query.payment_method)) { where.push('p.metodo = ?'); params.push(query.payment_method); }
  const accountId = Number.parseInt(query.account_id, 10);
  if (accountId > 0) { where.push('fm.financial_account_id = ?'); params.push(accountId); }
  const categoryId = Number.parseInt(query.category_id, 10);
  if (categoryId > 0) { where.push('fm.category_id = ?'); params.push(categoryId); }
  const search = String(query.search || '').trim();
  if (search) { where.push('(fm.description LIKE ? OR client.nome LIKE ? OR professional.nome LIKE ?)'); params.push(`%${search}%`, `%${search}%`, `%${search}%`); }
  const fromSql = `FROM financial_movements fm
    LEFT JOIN agendamentos a ON a.id = fm.appointment_id
    LEFT JOIN usuarios client ON client.id = fm.client_id
    LEFT JOIN colaboradores c ON c.id = fm.professional_id
    LEFT JOIN usuarios professional ON professional.id = c.usuario_id
    LEFT JOIN payments p ON p.id = fm.payment_id
    LEFT JOIN financial_accounts fa ON fa.id = fm.financial_account_id
    LEFT JOIN financial_categories fc ON fc.id = fm.category_id
    LEFT JOIN usuarios creator ON creator.id = fm.created_by
    WHERE ${where.join(' AND ')}`;
  const [rows] = await pool.query(
    `SELECT fm.id, fm.movement_type type, fm.operation, fm.origin_type, fm.origin_id,
            fm.appointment_id, fm.payment_id, fm.expense_id, fm.amount, fm.movement_date,
            fm.description, fm.status, client.nome client, professional.nome professional,
            p.metodo payment_method, fa.nome account, fc.nome category, creator.nome created_by
       ${fromSql} ORDER BY fm.movement_date DESC, fm.id DESC LIMIT ? OFFSET ?`,
    [...params, limit, (page - 1) * limit],
  );
  if (query.limit && Number(query.limit) <= 5 && !query.page) return rows;
  const [[count]] = await pool.query(`SELECT COUNT(*) total ${fromSql}`, params);
  return { rows, pagination: { page, limit, total: Number(count.total), pages: Math.ceil(Number(count.total) / limit) } };
}

// * CONSULTAR: variante usada pelo painel quando precisa incluir pendencias.
async function listMovementsWithPending(tenantId, query = {}) {
  const filters = parsePeriod(query);
  if (!filters) return [];
  const page = Math.max(1, Number.parseInt(query.page, 10) || 1);
  const limit = Math.min(100, Math.max(1, Number.parseInt(query.limit, 10) || 25));
  const movementWhere = ['fm.barbearia_id = ?', 'DATE(fm.movement_date) BETWEEN ? AND ?'];
  const movementParams = [tenantId, filters.from, filters.to];
  if (filters.professionalId) { movementWhere.push('fm.professional_id = ?'); movementParams.push(filters.professionalId); }
  if (filters.serviceId) { movementWhere.push('a.servico_id = ?'); movementParams.push(filters.serviceId); }
  if (['income','expense','refund','reversal','adjustment'].includes(query.type)) { movementWhere.push('fm.movement_type = ?'); movementParams.push(query.type); }
  if (query.status === 'pending') movementWhere.push('1 = 0');
  else if (['confirmed','reversed','cancelled'].includes(query.status)) { movementWhere.push('fm.status = ?'); movementParams.push(query.status); }
  if (PAYMENT_METHODS.includes(query.payment_method)) { movementWhere.push('p.metodo = ?'); movementParams.push(query.payment_method); }
  const accountId = Number.parseInt(query.account_id, 10);
  if (accountId > 0) { movementWhere.push('fm.financial_account_id = ?'); movementParams.push(accountId); }
  const categoryId = Number.parseInt(query.category_id, 10);
  if (categoryId > 0) { movementWhere.push('fm.category_id = ?'); movementParams.push(categoryId); }
  const search = String(query.search || '').trim();
  if (search) { movementWhere.push('(fm.description LIKE ? OR client.nome LIKE ? OR professional.nome LIKE ?)'); movementParams.push(`%${search}%`, `%${search}%`, `%${search}%`); }
  const movementFromSql = `FROM financial_movements fm
    LEFT JOIN agendamentos a ON a.id = fm.appointment_id
    LEFT JOIN usuarios client ON client.id = fm.client_id
    LEFT JOIN colaboradores c ON c.id = fm.professional_id
    LEFT JOIN usuarios professional ON professional.id = c.usuario_id
    LEFT JOIN payments p ON p.id = fm.payment_id
    LEFT JOIN financial_accounts fa ON fa.id = fm.financial_account_id
    LEFT JOIN financial_categories fc ON fc.id = fm.category_id
    LEFT JOIN usuarios creator ON creator.id = fm.created_by
    WHERE ${movementWhere.join(' AND ')}`;

  const expenseWhere = ['e.barbearia_id = ?', 'e.data_competencia BETWEEN ? AND ?', "e.status = 'pending'"];
  const expenseParams = [tenantId, filters.from, filters.to];
  if (filters.professionalId || filters.serviceId || PAYMENT_METHODS.includes(query.payment_method)) expenseWhere.push('1 = 0');
  if (query.status && query.status !== 'pending') expenseWhere.push('1 = 0');
  if (query.type && query.type !== 'expense') expenseWhere.push('1 = 0');
  if (accountId > 0) { expenseWhere.push('e.financial_account_id = ?'); expenseParams.push(accountId); }
  if (categoryId > 0) { expenseWhere.push('e.category_id = ?'); expenseParams.push(categoryId); }
  if (search) { expenseWhere.push('(e.descricao LIKE ? OR fc.nome LIKE ? OR responsible.nome LIKE ?)'); expenseParams.push(`%${search}%`, `%${search}%`, `%${search}%`); }
  const expenseFromSql = `FROM expenses e
    JOIN financial_categories fc ON fc.id = e.category_id
    LEFT JOIN financial_accounts fa ON fa.id = e.financial_account_id
    JOIN usuarios responsible ON responsible.id = e.responsible_user_id
    JOIN usuarios creator ON creator.id = e.criado_por
    WHERE ${expenseWhere.join(' AND ')}`;
  const fetchLimit = (page - 1) * limit + limit;
  const [movementRows] = await pool.query(
    `SELECT fm.id, fm.movement_type type, fm.operation, fm.origin_type, fm.origin_id,
            fm.appointment_id, fm.payment_id, fm.expense_id, fm.amount, fm.movement_date,
            fm.description, fm.status, client.nome client, professional.nome professional,
            p.metodo payment_method, fa.nome account, fc.nome category, creator.nome created_by
       ${movementFromSql} ORDER BY fm.movement_date DESC, fm.id DESC LIMIT ? OFFSET 0`,
    [...movementParams, fetchLimit],
  );
  const [expenseRows] = await pool.query(
    `SELECT -e.id id, 'expense' type, 'expense_registered' operation, 'expense' origin_type, e.id origin_id,
            NULL appointment_id, NULL payment_id, e.id expense_id, e.valor amount,
            TIMESTAMP(e.data_competencia, '12:00:00') movement_date,
            e.descricao description, 'pending' status, NULL client, NULL professional,
            NULL payment_method, fa.nome account, fc.nome category, creator.nome created_by
       ${expenseFromSql} ORDER BY e.data_competencia DESC, e.id DESC LIMIT ? OFFSET 0`,
    [...expenseParams, fetchLimit],
  );
  const [[movementCount]] = await pool.query(`SELECT COUNT(*) total ${movementFromSql}`, movementParams);
  const [[expenseCount]] = await pool.query(`SELECT COUNT(*) total ${expenseFromSql}`, expenseParams);
  const rows = [...movementRows, ...expenseRows]
    .sort((left, right) => {
      const dateDiff = new Date(right.movement_date).getTime() - new Date(left.movement_date).getTime();
      return dateDiff || Number(right.id) - Number(left.id);
    })
    .slice((page - 1) * limit, page * limit);
  if (query.limit && Number(query.limit) <= 5 && !query.page) return rows;
  const total = Number(movementCount.total) + Number(expenseCount.total);
  return { rows, pagination: { page, limit, total, pages: Math.ceil(total / limit) } };
}

// * CONSULTAR: detalha um movimento somente se ele pertence ao tenant atual.
async function movementDetail(tenantId, id) {
  const [rows] = await pool.query(
    `SELECT fm.*, client.nome client, professional.nome professional, fa.nome account,
            fc.nome category, creator.nome created_by
       FROM financial_movements fm
       LEFT JOIN usuarios client ON client.id = fm.client_id
       LEFT JOIN colaboradores c ON c.id = fm.professional_id
       LEFT JOIN usuarios professional ON professional.id = c.usuario_id
       JOIN financial_accounts fa ON fa.id = fm.financial_account_id AND fa.barbearia_id = fm.barbearia_id
       LEFT JOIN financial_categories fc ON fc.id = fm.category_id AND fc.barbearia_id = fm.barbearia_id
       JOIN usuarios creator ON creator.id = fm.created_by
      WHERE fm.id = ? AND fm.barbearia_id = ? LIMIT 1`, [id, tenantId],
  );
  return rows[0] || null;
}

// * CONSULTAR: lista contas a pagar e calcula resumo/paginacao para a tela.
async function listExpenses(tenantId, query = {}) {
  const filters = parsePeriod(query);
  if (!filters) return { rows: [], pagination: { page: 1, limit: 25, total: 0, pages: 0 } };
  const page = Math.max(1, Number.parseInt(query.page, 10) || 1);
  const limit = Math.min(100, Math.max(1, Number.parseInt(query.limit, 10) || 25));
  const where = ['e.barbearia_id = ?', 'e.data_competencia BETWEEN ? AND ?'];
  const params = [tenantId, filters.from, filters.to];
  if (['pending','paid','cancelled'].includes(query.status)) { where.push('e.status = ?'); params.push(query.status); }
  for (const [field, column] of [['category_id','e.category_id'],['account_id','e.financial_account_id'],['responsible_user_id','e.responsible_user_id']]) {
    const id = Number.parseInt(query[field], 10); if (id > 0) { where.push(`${column} = ?`); params.push(id); }
  }
  const fromSql = `FROM expenses e JOIN financial_categories fc ON fc.id = e.category_id
    LEFT JOIN financial_accounts fa ON fa.id = e.financial_account_id
    JOIN usuarios responsible ON responsible.id = e.responsible_user_id WHERE ${where.join(' AND ')}`;
  const [rows] = await pool.query(
    `SELECT e.id, e.descricao description, e.valor amount, e.data_competencia competence_date,
            e.data_vencimento due_date, e.pago_em paid_at, e.status, e.observacao notes,
            fc.id category_id, fc.nome category, fa.id account_id, fa.nome account,
            responsible.id responsible_user_id, responsible.nome responsible
       ${fromSql} ORDER BY e.data_vencimento DESC, e.id DESC LIMIT ? OFFSET ?`,
    [...params, limit, (page - 1) * limit],
  );
  const [[count]] = await pool.query(`SELECT COUNT(*) total ${fromSql}`, params);
  const [[summary]] = await pool.query(
    `SELECT COALESCE(SUM(CASE WHEN status='paid' THEN valor ELSE 0 END),0) paid,
            COALESCE(SUM(CASE WHEN status='pending' THEN valor ELSE 0 END),0) pending,
            COALESCE(SUM(CASE WHEN status<>'cancelled' THEN valor ELSE 0 END),0) period_total
       FROM expenses WHERE barbearia_id=? AND data_competencia BETWEEN ? AND ?`, [tenantId, filters.from, filters.to],
  );
  return { rows, summary: { paid: Number(summary.paid), pending: Number(summary.pending), periodTotal: Number(summary.period_total), balanceImpact: -Number(summary.paid) }, pagination: { page, limit, total: Number(count.total), pages: Math.ceil(Number(count.total) / limit) } };
}

// * VALIDAR: confirma que categoria, conta e responsavel pertencem ao tenant
// * antes de qualquer INSERT/UPDATE de despesa.
async function validateExpenseRelations(connection, tenantId, categoryId, accountId, responsibleUserId, requireAccount) {
  const [[category]] = await connection.query(`SELECT id FROM financial_categories WHERE id=? AND barbearia_id=? AND tipo='expense' AND ativo=1`, [categoryId, tenantId]);
  const [[responsible]] = await connection.query(`SELECT u.id FROM usuarios u WHERE u.id=? AND u.ativo=1 AND (EXISTS (SELECT 1 FROM memberships m WHERE m.usuario_id=u.id AND m.barbearia_id=? AND m.ativo=1) OR EXISTS (SELECT 1 FROM barbearias b WHERE b.id=? AND b.admin_id=u.id AND b.ativa=1))`, [responsibleUserId, tenantId, tenantId]);
  let account = null;
  if (accountId) [[account]] = await connection.query(`SELECT id FROM financial_accounts WHERE id=? AND barbearia_id=? AND ativo=1`, [accountId, tenantId]);
  return !!category && !!responsible && (!accountId || !!account) && (!requireAccount || !!account);
}

// * ADICIONAR: cria uma despesa pendente, registra o ator e preserva o
// * relacionamento com categoria/conta sem aceitar IDs de outra barbearia.
async function createExpense({ tenantId, actorId, data, requestId }) {
  const amount = cents(data.amount);
  const categoryId = Number.parseInt(data.category_id, 10);
  const accountId = data.account_id == null ? null : Number.parseInt(data.account_id, 10);
  const responsibleUserId = Number.parseInt(data.responsible_user_id, 10);
  const description = String(data.description || '').trim();
  const notes = String(data.notes || '').trim() || null;
  const date = /^\d{4}-\d{2}-\d{2}$/;
  if (amount == null || amount <= 0n || !description || description.length > 240 || notes?.length > 500 || !date.test(data.competence_date || '') || !date.test(data.due_date || '')) return { status: 422, code: 'VALIDATION_ERROR' };
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    if (!await validateExpenseRelations(connection, tenantId, categoryId, accountId, responsibleUserId, false)) { await connection.rollback(); return { status: 422, code: 'INVALID_RELATION' }; }
    const [result] = await connection.query(
      `INSERT INTO expenses (barbearia_id,category_id,financial_account_id,responsible_user_id,descricao,valor,data_competencia,data_vencimento,observacao,criado_por)
       VALUES (?,?,?,?,?,?,?,?,?,?)`, [tenantId, categoryId, accountId, responsibleUserId, description, decimal(amount), data.competence_date, data.due_date, notes, actorId],
    );
    await connection.query(`INSERT INTO audit_logs (barbearia_id,usuario_id,acao,recurso,recurso_id,request_id,detalhes) VALUES (?,?,'expense.created','expense',?,?,JSON_OBJECT('amount',?,'status','pending'))`, [tenantId, actorId, String(result.insertId), requestId, decimal(amount)]);
    await connection.commit(); return { status: 201, id: result.insertId };
  } catch (error) { await connection.rollback().catch(()=>{}); throw error; } finally { connection.release(); }
}

// * EDITAR: altera os campos permitidos enquanto a despesa ainda esta pendente.
async function updateExpense({ tenantId, actorId, expenseId, data, requestId }) {
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const [[current]] = await connection.query('SELECT * FROM expenses WHERE id=? AND barbearia_id=? FOR UPDATE', [expenseId, tenantId]);
    if (!current) { await connection.rollback(); return { status: 404, code: 'EXPENSE_NOT_FOUND' }; }
    if (current.status !== 'pending') { await connection.rollback(); return { status: 409, code: 'EXPENSE_NOT_EDITABLE' }; }
    const merged = { amount: data.amount ?? current.valor, category_id: data.category_id ?? current.category_id, account_id: data.account_id ?? current.financial_account_id, responsible_user_id: data.responsible_user_id ?? current.responsible_user_id, description: data.description ?? current.descricao, competence_date: data.competence_date ?? current.data_competencia, due_date: data.due_date ?? current.data_vencimento, notes: data.notes ?? current.observacao };
    const amount = cents(merged.amount); const description = String(merged.description || '').trim();
    if (amount == null || amount <= 0n || !description) { await connection.rollback(); return { status: 422, code: 'VALIDATION_ERROR' }; }
    if (!await validateExpenseRelations(connection, tenantId, Number(merged.category_id), merged.account_id ? Number(merged.account_id) : null, Number(merged.responsible_user_id), false)) { await connection.rollback(); return { status: 422, code: 'INVALID_RELATION' }; }
    await connection.query(`UPDATE expenses SET category_id=?,financial_account_id=?,responsible_user_id=?,descricao=?,valor=?,data_competencia=?,data_vencimento=?,observacao=? WHERE id=?`, [merged.category_id, merged.account_id || null, merged.responsible_user_id, description, decimal(amount), merged.competence_date, merged.due_date, merged.notes || null, expenseId]);
    await connection.query(`INSERT INTO audit_logs (barbearia_id,usuario_id,acao,recurso,recurso_id,request_id,detalhes) VALUES (?,?,'expense.updated','expense',?,?,JSON_OBJECT('beforeAmount',?,'afterAmount',?))`, [tenantId, actorId, String(expenseId), requestId, current.valor, decimal(amount)]);
    await connection.commit(); return { status: 200, id: expenseId };
  } catch (error) { await connection.rollback().catch(()=>{}); throw error; } finally { connection.release(); }
}

// * EDITAR ESTADO: pagamento individual delega para o fluxo em lote para
// * manter as mesmas regras de conta, idempotencia e transacao.
async function payExpense(args) {
  const result = await payExpenses({ ...args, expenseIds: [args.expenseId] });
  if (result.status === 201 && result.ids?.length) return { ...result, id: result.ids[0] };
  if (result.status === 200 && result.ids?.length) return { ...result, id: result.ids[0] };
  return result;
}

// * ADICIONAR MOVIMENTO: paga uma ou varias despesas em uma transacao e grava
// * os lancamentos de caixa/auditoria correspondentes.
async function payExpenses({ tenantId, actorId, expenseIds, accountId, paidAt, idempotencyKey, requestId }) {
  const key = String(idempotencyKey || '').trim();
  const ids = Array.isArray(expenseIds)
    ? [...new Set(expenseIds.map((id) => Number.parseInt(id, 10)).filter((id) => Number.isInteger(id) && id > 0))].sort((a, b) => a - b)
    : [];
  if (!ids.length || ids.length > 100 || !/^[a-zA-Z0-9._:-]{8,100}$/.test(key) || !/^\d{4}-\d{2}-\d{2}$/.test(paidAt || '')) return { status: 422, code: 'VALIDATION_ERROR' };
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const movements = [];
    for (const expenseId of ids) {
      const [[expense]] = await connection.query('SELECT * FROM expenses WHERE id=? AND barbearia_id=? FOR UPDATE', [expenseId, tenantId]);
      if (!expense) { await connection.rollback(); return { status: 404, code: 'EXPENSE_NOT_FOUND' }; }
      const [[existing]] = await connection.query(`SELECT id FROM financial_movements WHERE barbearia_id=? AND origin_type='expense' AND origin_id=? AND operation='expense_paid' FOR UPDATE`, [tenantId, expenseId]);
      if (existing && expense.status === 'paid') { movements.push(existing.id); continue; }
      if (expense.status !== 'pending') { await connection.rollback(); return { status: 409, code: 'EXPENSE_STATE_CONFLICT' }; }
      if (!await validateExpenseRelations(connection, tenantId, expense.category_id, Number(accountId), expense.responsible_user_id, true)) { await connection.rollback(); return { status: 422, code: 'INVALID_ACCOUNT' }; }
      const movementKey = ids.length === 1 ? key : `${key}-${expenseId}`;
      const [movement] = await connection.query(
        `INSERT INTO financial_movements (barbearia_id,movement_type,operation,origin_type,origin_id,idempotency_key,financial_account_id,category_id,expense_id,amount,movement_date,description,status,created_by)
         VALUES (?,'expense','expense_paid','expense',?,?,?,?,?,?,?,?,'confirmed',?)`,
        [tenantId, expenseId, movementKey, accountId, expense.category_id, expenseId, expense.valor, `${paidAt} 12:00:00`, expense.descricao, actorId],
      );
      await connection.query(`UPDATE expenses SET status='paid',financial_account_id=?,pago_em=? WHERE id=?`, [accountId, `${paidAt} 12:00:00`, expenseId]);
      await connection.query(`INSERT INTO audit_logs (barbearia_id,usuario_id,acao,recurso,recurso_id,request_id,detalhes) VALUES (?,?,'expense.paid','expense',?,?,JSON_OBJECT('movementId',?,'amount',?,'idempotencyKey',?))`, [tenantId, actorId, String(expenseId), requestId, movement.insertId, expense.valor, movementKey]);
      movements.push(movement.insertId);
    }
    await connection.commit();
    return { status: movements.length && movements.every((id) => id) ? 201 : 200, ids: movements, idempotent: movements.length === ids.length && movements.every((id) => id) };
  } catch (error) { await connection.rollback().catch(()=>{}); if (error.code === 'ER_DUP_ENTRY' || error.code === 'ER_LOCK_DEADLOCK') return { status: 409, code: 'EXPENSE_PAYMENT_CONFLICT' }; throw error; } finally { connection.release(); }
}

// * EXCLUIR LOGICAMENTE: cancela uma despesa pendente sem apagar historico.
async function cancelExpense({ tenantId, actorId, expenseId, reason, requestId }) {
  const cleanReason = String(reason || '').trim(); if (cleanReason.length < 3 || cleanReason.length > 240) return { status: 422, code: 'VALIDATION_ERROR' };
  const connection = await pool.getConnection();
  try { await connection.beginTransaction(); const [[expense]] = await connection.query('SELECT status FROM expenses WHERE id=? AND barbearia_id=? FOR UPDATE', [expenseId, tenantId]);
    if (!expense) { await connection.rollback(); return { status: 404, code: 'EXPENSE_NOT_FOUND' }; }
    if (expense.status === 'paid') { await connection.rollback(); return { status: 409, code: 'PAID_EXPENSE_CANNOT_CANCEL' }; }
    if (expense.status === 'cancelled') { await connection.commit(); return { status: 200, idempotent: true }; }
    await connection.query(`UPDATE expenses SET status='cancelled',cancelado_por=?,cancelado_em=NOW(),motivo_cancelamento=? WHERE id=?`, [actorId, cleanReason, expenseId]);
    await connection.query(`INSERT INTO audit_logs (barbearia_id,usuario_id,acao,recurso,recurso_id,request_id,detalhes) VALUES (?,?,'expense.cancelled','expense',?,?,JSON_OBJECT('reason',?))`, [tenantId, actorId, String(expenseId), requestId, cleanReason]);
    await connection.commit(); return { status: 200 };
  } catch(error){await connection.rollback().catch(()=>{});throw error;} finally{connection.release();}
}

// * EXCLUIR LOGICAMENTE EM LOTE: aplica o mesmo cancelamento aos IDs validos.
async function cancelExpenses({ tenantId, actorId, expenseIds, reason, requestId }) {
  const cleanReason = String(reason || '').trim();
  const ids = Array.isArray(expenseIds)
    ? [...new Set(expenseIds.map((id) => Number.parseInt(id, 10)).filter((id) => Number.isInteger(id) && id > 0))].sort((a, b) => a - b)
    : [];
  if (!ids.length || ids.length > 100 || cleanReason.length < 3 || cleanReason.length > 240) return { status: 422, code: 'VALIDATION_ERROR' };
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    for (const expenseId of ids) {
      const [[expense]] = await connection.query('SELECT status FROM expenses WHERE id=? AND barbearia_id=? FOR UPDATE', [expenseId, tenantId]);
      if (!expense) { await connection.rollback(); return { status: 404, code: 'EXPENSE_NOT_FOUND' }; }
      if (expense.status === 'paid') { await connection.rollback(); return { status: 409, code: 'PAID_EXPENSE_CANNOT_CANCEL' }; }
      if (expense.status === 'cancelled') continue;
      await connection.query(`UPDATE expenses SET status='cancelled',cancelado_por=?,cancelado_em=NOW(),motivo_cancelamento=? WHERE id=?`, [actorId, cleanReason, expenseId]);
      await connection.query(`INSERT INTO audit_logs (barbearia_id,usuario_id,acao,recurso,recurso_id,request_id,detalhes) VALUES (?,?,'expense.cancelled','expense',?,?,JSON_OBJECT('reason',?))`, [tenantId, actorId, String(expenseId), requestId, cleanReason]);
    }
    await connection.commit();
    return { status: 200, ids };
  } catch (error) { await connection.rollback().catch(()=>{}); throw error; } finally { connection.release(); }
}

// * CONSULTAR: lista contas a receber geradas pelos atendimentos concluidos.
async function listReceivables(tenantId, query = {}) {
  const filters = parsePeriod(query); if (!filters) return { rows: [], pagination: { page:1,limit:25,total:0,pages:0 } };
  const page=Math.max(1,Number.parseInt(query.page,10)||1), limit=Math.min(100,Math.max(1,Number.parseInt(query.limit,10)||25)); const scope=appointmentScope(filters);
  const baseParams=[tenantId,filters.from,filters.to,...scope.params];
  const sql=`FROM agendamentos a JOIN colaboradores c ON c.id=a.colaborador_id JOIN barbearias b ON b.id=c.barbearia_id JOIN usuarios client ON client.id=a.cliente_id JOIN usuarios professional ON professional.id=c.usuario_id JOIN servicos s ON s.id=a.servico_id
    LEFT JOIN (SELECT agendamento_id,SUM(preco_cobrado) subtotal,COUNT(*) service_count FROM agendamento_servicos GROUP BY agendamento_id) aps ON aps.agendamento_id=a.id
    LEFT JOIN financial_receivable_exclusions fre ON fre.barbearia_id=c.barbearia_id AND fre.agendamento_id=a.id
    LEFT JOIN (SELECT p.agendamento_id,SUM(p.valor) paid,GROUP_CONCAT(DISTINCT p.metodo ORDER BY p.pago_em DESC SEPARATOR ', ') payment_methods,MAX(p.pago_em) paid_at FROM payments p WHERE p.status IN ('paid','partially_refunded','refunded') GROUP BY p.agendamento_id) pay ON pay.agendamento_id=a.id
    WHERE c.barbearia_id=? AND a.status='concluido' AND DATE(a.data_hora) BETWEEN ? AND ?
      AND fre.id IS NULL AND a.valor_cobrado > COALESCE(pay.paid,0)${scope.sql}`;
  const [rows]=await pool.query(`SELECT a.id appointment_id,a.data_hora service_date,a.valor_cobrado total_amount,COALESCE(aps.subtotal,s.preco,a.valor_cobrado) subtotal_amount,GREATEST(COALESCE(aps.subtotal,s.preco,a.valor_cobrado)-a.valor_cobrado,0) discount_amount,COALESCE(aps.service_count,1) service_count,COALESCE(pay.paid,0) paid_amount,GREATEST(a.valor_cobrado-COALESCE(pay.paid,0),0) outstanding_amount,client.nome client,client.telefone client_phone,professional.nome professional,CASE WHEN COALESCE(aps.service_count,1)>1 THEN CONCAT(s.nome,' + ',aps.service_count-1,' outro(s)') ELSE s.nome END service,s.descricao service_description,a.observacao observation,b.nome barbearia_name,b.endereco barbearia_address,b.telefone barbearia_phone,pay.payment_methods,pay.paid_at,CASE WHEN COALESCE(pay.paid,0)=0 THEN IF(DATE(a.data_hora)<CURRENT_DATE,'overdue','open') WHEN pay.paid<a.valor_cobrado THEN 'partial' ELSE 'paid' END status ${sql} ORDER BY a.data_hora DESC LIMIT ? OFFSET ?`,[...baseParams,limit,(page-1)*limit]);
  const [[count]]=await pool.query(`SELECT COUNT(*) total ${sql}`,baseParams); return {rows,pagination:{page,limit,total:Number(count.total),pages:Math.ceil(Number(count.total)/limit)}};
}

// * ADICIONAR MOVIMENTO: registra pagamento integral do atendimento com chave
// * de idempotencia e revalidacao de saldo dentro da transacao.
async function registerPayment({ tenantId, actorId, appointmentId, data, idempotencyKey, requestId }) {
  const amount=cents(data.amount), accountId=Number.parseInt(data.account_id,10), method=String(data.method||''), key=String(idempotencyKey||'').trim(), notes=String(data.notes||'').trim()||null;
  if(amount==null||amount<=0n||!PAYMENT_METHODS.includes(method)||!accountId||!/^\d{4}-\d{2}-\d{2}$/.test(data.paid_at||'')||!/^[a-zA-Z0-9._:-]{8,100}$/.test(key)||notes?.length>500)return{status:422,code:'VALIDATION_ERROR'};
  const connection=await pool.getConnection();
  try{await connection.beginTransaction();const [[existing]]=await connection.query('SELECT id,agendamento_id FROM payments WHERE idempotency_key=? FOR UPDATE',[key]);if(existing){if(Number(existing.agendamento_id)!==Number(appointmentId)){await connection.rollback();return{status:409,code:'IDEMPOTENCY_CONFLICT'};}await connection.commit();return{status:200,id:existing.id,idempotent:true};}
    const [[appointment]]=await connection.query(`SELECT a.id,a.status,a.valor_cobrado,a.cliente_id,a.colaborador_id,c.barbearia_id FROM agendamentos a JOIN colaboradores c ON c.id=a.colaborador_id WHERE a.id=? AND c.barbearia_id=? FOR UPDATE`,[appointmentId,tenantId]);
    if(!appointment){await connection.rollback();return{status:404,code:'RECEIVABLE_NOT_FOUND'};}if(appointment.status!=='concluido'){await connection.rollback();return{status:409,code:'APPOINTMENT_NOT_COMPLETED'};}
    const [[account]]=await connection.query('SELECT id FROM financial_accounts WHERE id=? AND barbearia_id=? AND ativo=1',[accountId,tenantId]);if(!account){await connection.rollback();return{status:422,code:'INVALID_ACCOUNT'};}
    const [[paid]]=await connection.query(`SELECT COALESCE(SUM(valor),0) total FROM payments WHERE barbearia_id=? AND agendamento_id=? AND status IN ('paid','partially_refunded','refunded')`,[tenantId,appointmentId]);const outstanding=cents(appointment.valor_cobrado)-cents(paid.total);if(amount>outstanding){await connection.rollback();return{status:422,code:'PAYMENT_EXCEEDS_BALANCE',outstanding:decimal(outstanding)};}
    const [payment]=await connection.query(`INSERT INTO payments (barbearia_id,agendamento_id,financial_account_id,usuario_id,criado_por,provedor,idempotency_key,tipo,metodo,status,valor,observacao,pago_em) VALUES (?,?,?,?,?,'manual',?,'service',?,'paid',?,?,?)`,[tenantId,appointmentId,accountId,appointment.cliente_id,actorId,key,method,decimal(amount),notes,`${data.paid_at} 12:00:00`]);
    const [movement]=await connection.query(`INSERT INTO financial_movements (barbearia_id,movement_type,operation,origin_type,origin_id,appointment_id,client_id,professional_id,financial_account_id,payment_id,amount,movement_date,description,status,created_by) VALUES (?,'income','payment_received','payment',?,?,?,?,?,?,?,?,?,'confirmed',?)`,[tenantId,payment.insertId,appointmentId,appointment.cliente_id,appointment.colaborador_id,accountId,payment.insertId,decimal(amount),`${data.paid_at} 12:00:00`,`Pagamento do atendimento #${appointmentId}`,actorId]);
    await connection.query(`UPDATE financial_transactions SET status=?,pago_em=? WHERE barbearia_id=? AND agendamento_id=? AND tipo='income'`,[amount===outstanding?'paid':'partially_paid',`${data.paid_at} 12:00:00`,tenantId,appointmentId]);
    await commissionService.reconcileAppointment(connection, { tenantId, appointmentId, actorId });
    await connection.query(`INSERT INTO audit_logs (barbearia_id,usuario_id,acao,recurso,recurso_id,request_id,detalhes) VALUES (?,?,'payment.registered','payment',?,?,JSON_OBJECT('appointmentId',?,'movementId',?,'amount',?,'method',?))`,[tenantId,actorId,String(payment.insertId),requestId,appointmentId,movement.insertId,decimal(amount),method]);
    await connection.commit();return{status:201,id:payment.insertId,movementId:movement.insertId};
  }catch(error){await connection.rollback().catch(()=>{});if(error.code==='ER_DUP_ENTRY'||error.code==='ER_LOCK_DEADLOCK')return{status:409,code:'PAYMENT_CONFLICT'};throw error;}finally{connection.release();}
}

// * EDITAR/ESTORNAR: cria a compensacao de um pagamento, sem apagar o evento
// * original, e recalcula o saldo da conta a receber.
async function refundPayment({ tenantId, actorId, paymentId, data, idempotencyKey, requestId }) {
  const amount = cents(data.amount);
  const reason = String(data.reason || '').trim();
  const key = String(idempotencyKey || '').trim();
  if (amount == null || amount <= 0n || reason.length < 3 || reason.length > 240 || !/^[a-zA-Z0-9._:-]{8,100}$/.test(key)) {
    return { status: 422, code: 'VALIDATION_ERROR' };
  }
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const [[existing]] = await connection.query('SELECT id FROM refunds WHERE idempotency_key = ? FOR UPDATE', [key]);
    if (existing) {
      await connection.commit();
      return { status: 200, id: existing.id, idempotent: true };
    }
    const [[payment]] = await connection.query(
      `SELECT p.id, p.valor, p.agendamento_id, p.usuario_id, p.financial_account_id,
              p.status, a.colaborador_id
         FROM payments p
         JOIN agendamentos a ON a.id = p.agendamento_id
         JOIN colaboradores c ON c.id = a.colaborador_id
        WHERE p.id = ? AND p.barbearia_id = ?
          AND p.status IN ('paid', 'partially_refunded')
        FOR UPDATE`,
      [paymentId, tenantId],
    );
    if (!payment) {
      await connection.rollback();
      return { status: 404, code: 'PAYMENT_NOT_FOUND' };
    }
    const [[refunded]] = await connection.query(
      `SELECT COALESCE(SUM(valor), 0) amount
         FROM refunds
        WHERE payment_id = ? AND status = 'processed'`,
      [paymentId],
    );
    const available = cents(payment.valor) - cents(refunded.amount);
    if (amount > available) {
      await connection.rollback();
      return { status: 422, code: 'REFUND_EXCEEDS_PAYMENT' };
    }
    const [refund] = await connection.query(
      `INSERT INTO refunds (payment_id, idempotency_key, status, valor, motivo, processado_em)
       VALUES (?, ?, 'processed', ?, ?, NOW())`,
      [paymentId, key, decimal(amount), reason],
    );
    const finalStatus = amount === available ? 'refunded' : 'partially_refunded';
    await connection.query('UPDATE payments SET status = ? WHERE id = ?', [finalStatus, paymentId]);
    if (payment.financial_account_id) {
      await connection.query(
        `INSERT INTO financial_movements
          (barbearia_id, movement_type, operation, origin_type, origin_id,
           appointment_id, client_id, professional_id, financial_account_id,
           payment_id, amount, movement_date, description, status, created_by)
         VALUES (?, 'refund', 'payment_refunded', 'refund', ?, ?, ?, ?, ?, ?, ?, NOW(), ?, 'confirmed', ?)`,
        [tenantId, refund.insertId, payment.agendamento_id, payment.usuario_id,
          payment.colaborador_id, payment.financial_account_id, paymentId,
          decimal(amount), reason, actorId],
      );
    }
    await connection.query(
      `UPDATE financial_transactions
          SET status = CASE WHEN ? >= valor_liquido THEN 'reversed' ELSE 'partially_paid' END
        WHERE barbearia_id = ? AND agendamento_id = ? AND tipo = 'income'
          AND status IN ('posted', 'partially_paid', 'paid')`,
      [decimal(amount + cents(refunded.amount)), tenantId, payment.agendamento_id],
    );
    await commissionService.reconcileAppointment(connection, {
      tenantId,
      appointmentId: payment.agendamento_id,
      actorId,
    });
    await connection.query(
      `INSERT INTO audit_logs (barbearia_id, usuario_id, acao, recurso, recurso_id, request_id, detalhes)
       VALUES (?, ?, 'payment.refunded', 'refund', ?, ?, JSON_OBJECT('paymentId', ?, 'amount', ?, 'reason', ?))`,
      [tenantId, actorId, String(refund.insertId), requestId, paymentId, decimal(amount), reason],
    );
    await connection.commit();
    return { status: 201, id: refund.insertId, paymentStatus: finalStatus };
  } catch (error) {
    await connection.rollback().catch(() => {});
    if (error.code === 'ER_DUP_ENTRY') return { status: 409, code: 'REFUND_CONFLICT' };
    throw error;
  } finally {
    connection.release();
  }
}

// * ADICIONAR MOVIMENTO EM LOTE: registra varios pagamentos mantendo o mesmo
// * contrato de idempotencia e validacao usado no pagamento individual.
async function registerPayments({ tenantId, actorId, items, accountId, method, paidAt, notes, idempotencyKey, requestId }) {
  const normalized = Array.isArray(items) ? items.map((item) => ({ appointmentId: Number(item.appointment_id), amount: item.amount })).filter((item) => Number.isInteger(item.appointmentId) && item.appointmentId > 0) : [];
  if (!normalized.length || normalized.length > 100 || !/^\d{4}-\d{2}-\d{2}$/.test(paidAt || '') || !/^[a-zA-Z0-9._:-]{8,100}$/.test(String(idempotencyKey || ''))) return { status: 422, code: 'VALIDATION_ERROR' };
  const completed = [];
  for (const item of normalized) {
    const result = await registerPayment({
      tenantId,
      actorId,
      appointmentId: item.appointmentId,
      data: { amount: item.amount, account_id: accountId, method, paid_at: paidAt, notes },
      idempotencyKey: `${idempotencyKey}-${item.appointmentId}`,
      requestId,
    });
    if (result.status >= 400) return { ...result, completed };
    completed.push(item.appointmentId);
  }
  return { status: 201, completed };
}

// * EXCLUIR LOGICAMENTE: remove contas a receber da operacao por marcacao de
// * exclusao/cancelamento e gera auditoria para cada atendimento afetado.
async function excludeReceivables({ tenantId, actorId, appointmentIds, requestId }) {
  const ids = [...new Set((Array.isArray(appointmentIds) ? appointmentIds : []).map(Number).filter((id) => Number.isInteger(id) && id > 0))];
  if (!ids.length || ids.length > 100) return { status: 422, code: 'VALIDATION_ERROR' };
  const connection = await pool.getConnection();
  let excluded = 0;
  try {
    await connection.beginTransaction();
    for (const appointmentId of ids) {
      const [[appointment]] = await connection.query(
        `SELECT a.id,a.valor_cobrado,c.barbearia_id
         FROM agendamentos a JOIN colaboradores c ON c.id=a.colaborador_id
         WHERE a.id=? AND c.barbearia_id=? AND a.status='concluido' FOR UPDATE`,
        [appointmentId, tenantId],
      );
      if (!appointment) continue;
      const [[paid]] = await connection.query(
        `SELECT COALESCE(SUM(valor),0) total FROM payments
         WHERE barbearia_id=? AND agendamento_id=? AND status IN ('paid','partially_refunded','refunded')`,
        [tenantId, appointmentId],
      );
      if (Number(paid.total) >= Number(appointment.valor_cobrado)) continue;
      const [inserted] = await connection.query(
        `INSERT IGNORE INTO financial_receivable_exclusions (barbearia_id,agendamento_id,excluido_por,motivo)
         VALUES (?,?,?,'Conta a receber excluida pelo administrador')`,
        [tenantId, appointmentId, actorId],
      );
      if (!inserted.affectedRows) continue;
      await connection.query(
        `UPDATE financial_transactions SET status='cancelled',cancelado_por=?,motivo_cancelamento=?
         WHERE barbearia_id=? AND agendamento_id=? AND tipo='income'
           AND status IN ('pending','posted','partially_paid')`,
        [actorId, 'Conta a receber excluida pelo administrador', tenantId, appointmentId],
      );
      await connection.query(
        `INSERT INTO audit_logs (barbearia_id,usuario_id,acao,recurso,recurso_id,request_id,detalhes)
         VALUES (?,?,'receivable.excluded','appointment',?,?,JSON_OBJECT('appointmentId',?))`,
        [tenantId, actorId, String(appointmentId), requestId, appointmentId],
      );
      excluded += 1;
    }
    await connection.commit();
    return { status: 200, excluded };
  } catch (error) {
    await connection.rollback().catch(() => {});
    throw error;
  } finally {
    connection.release();
  }
}

// * CONSULTAR/REUTILIZAR: garante contas, categorias, profissionais e servicos
// * ativos que alimentam os formularios financeiros.
async function metadata(tenantId) {
  await pool.query(`INSERT IGNORE INTO financial_accounts (barbearia_id,nome,tipo) VALUES (?,'Caixa','cash')`,[tenantId]);
  await pool.query(`INSERT IGNORE INTO financial_categories (barbearia_id,nome,tipo) VALUES (?,'Servicos','income'),(?,'Outras despesas','expense')`,[tenantId,tenantId]);
  const [accounts]=await pool.query(`SELECT id,nome name,tipo type FROM financial_accounts WHERE barbearia_id=? AND ativo=1 ORDER BY nome`,[tenantId]);
  const [categories]=await pool.query(`SELECT id,nome name,tipo type FROM financial_categories WHERE barbearia_id=? AND ativo=1 ORDER BY tipo,nome`,[tenantId]);
  const [professionals]=await pool.query(`SELECT c.id,u.id user_id,u.nome name FROM colaboradores c JOIN usuarios u ON u.id=c.usuario_id WHERE c.barbearia_id=? AND c.ativo=1 ORDER BY u.nome`,[tenantId]);
  const [responsibles]=await pool.query(`SELECT DISTINCT u.id,u.nome name FROM usuarios u WHERE u.ativo=1 AND (EXISTS (SELECT 1 FROM memberships m WHERE m.usuario_id=u.id AND m.barbearia_id=? AND m.ativo=1) OR EXISTS (SELECT 1 FROM barbearias b WHERE b.id=? AND b.admin_id=u.id AND b.ativa=1)) ORDER BY u.nome`,[tenantId,tenantId]);
  const [services]=await pool.query(`SELECT id,nome name FROM servicos WHERE barbearia_id=? AND ativo=1 ORDER BY nome`,[tenantId]);
  return {accounts,categories,professionals,responsibles,services};
}

// * CONSULTAR: lista categorias ativas e inativas para permitir reativacao ou
// * desativacao sem perder lancamentos antigos.
async function listCategories(tenantId) {
  const [rows] = await pool.query(
    `SELECT id, nome name, tipo type, ativo active, criado_em created_at, atualizado_em updated_at
       FROM financial_categories
      WHERE barbearia_id = ?
      ORDER BY ativo DESC, tipo, nome`,
    [tenantId],
  );
  return rows;
}

// * ADICIONAR: cria categoria de receita/despesa validando nome, tipo e tenant.
async function createCategory({ tenantId, data }) {
  const name = String(data?.name || data?.nome || '').trim();
  const type = String(data?.type || data?.tipo || '').trim().toLowerCase();
  if (name.length < 2 || name.length > 80 || !['income', 'expense'].includes(type)) {
    return { status: 422, code: 'VALIDATION_ERROR' };
  }
  try {
    const [result] = await pool.query(
      `INSERT INTO financial_categories (barbearia_id, nome, tipo, ativo) VALUES (?, ?, ?, 1)`,
      [tenantId, name, type],
    );
    return { status: 201, id: result.insertId };
  } catch (error) {
    if (error.code === 'ER_DUP_ENTRY') return { status: 409, code: 'CATEGORY_ALREADY_EXISTS' };
    throw error;
  }
}

// * EDITAR: altera nome/tipo/ativo somente da categoria do tenant informado;
// * nao existe DELETE fisico porque o historico depende dela.
async function updateCategory({ tenantId, categoryId, data }) {
  const name = String(data?.name || data?.nome || '').trim();
  const type = String(data?.type || data?.tipo || '').trim().toLowerCase();
  const active = data?.active ?? data?.ativo;
  if (!Number.isInteger(categoryId) || name.length < 2 || name.length > 80 || !['income', 'expense'].includes(type) || ![true, false, 0, 1].includes(active)) {
    return { status: 422, code: 'VALIDATION_ERROR' };
  }
  try {
    const [result] = await pool.query(
      `UPDATE financial_categories
          SET nome = ?, tipo = ?, ativo = ?, atualizado_em = CURRENT_TIMESTAMP
        WHERE id = ? AND barbearia_id = ?`,
      [name, type, active === true || active === 1 ? 1 : 0, categoryId, tenantId],
    );
    return result.affectedRows ? { status: 200, id: categoryId } : { status: 404, code: 'CATEGORY_NOT_FOUND' };
  } catch (error) {
    if (error.code === 'ER_DUP_ENTRY') return { status: 409, code: 'CATEGORY_ALREADY_EXISTS' };
    throw error;
  }
}

module.exports={parsePeriod,getDashboard,listMovements,movementDetail,listExpenses,createExpense,updateExpense,payExpense,payExpenses,cancelExpense,cancelExpenses,listReceivables,registerPayment,refundPayment,registerPayments,excludeReceivables,metadata,listCategories,createCategory,updateCategory};
