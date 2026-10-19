const { pool } = require('../config/database');
const { errorBody } = require('./request.middleware');

const CAPABILITIES = Object.freeze({
  owner: ['appointments.read.all', 'employees.read.all', 'financial.read.all', 'financial.create.expense', 'financial.dashboard.read', 'financial.movements.read', 'financial.expenses.read', 'financial.expenses.create', 'financial.expenses.update', 'financial.expenses.pay', 'financial.receivables.read', 'financial.payments.create', 'financial.categories.read', 'financial.categories.manage', 'finance.commission.view', 'finance.commission.manage', 'finance.commission.close', 'finance.commission.pay', 'finance.commission.advance', 'finance.commission.adjust', 'finance.commission.reverse', 'financial.reports.read', 'payments.read.all', 'payments.create', 'reports.read.all', 'fiscal.read', 'fiscal.issue', 'accounting.read'],
  manager: ['appointments.read.all', 'employees.read.all', 'financial.read.all', 'financial.create.expense', 'financial.dashboard.read', 'financial.movements.read', 'financial.expenses.read', 'financial.expenses.create', 'financial.expenses.update', 'financial.expenses.pay', 'financial.receivables.read', 'financial.payments.create', 'financial.categories.read', 'financial.categories.manage', 'finance.commission.reverse', 'financial.reports.read', 'payments.read.all', 'payments.create', 'reports.read.all', 'fiscal.read', 'fiscal.issue', 'accounting.read'],
  receptionist: ['appointments.read.all', 'employees.read.all'],
  professional: ['appointments.read.own', 'commission.own.view', 'commission.own.history'],
});

async function tenantContext(req, res, next) {
  try {
    const [memberships] = await pool.query(
      `SELECT m.barbearia_id, m.papel, c.id AS colaborador_id
         FROM memberships m
         JOIN barbearias b ON b.id = m.barbearia_id AND b.ativa = 1
         LEFT JOIN colaboradores c ON c.barbearia_id = m.barbearia_id
          AND c.usuario_id = m.usuario_id AND c.ativo = 1
        WHERE m.usuario_id = ? AND m.ativo = 1
        ORDER BY FIELD(m.papel, 'owner', 'manager', 'receptionist', 'professional')
        LIMIT 1`,
      [req.usuario.id],
    );
    let context = memberships[0];
    if (!context && req.usuario.role === 'admin') {
      const [shops] = await pool.query(
        `SELECT b.id AS barbearia_id, 'owner' AS papel, NULL AS colaborador_id
           FROM barbearias b WHERE b.admin_id = ? AND b.ativa = 1 ORDER BY b.id LIMIT 1`,
        [req.usuario.id],
      );
      context = shops[0];
    }
    if (!context) return res.status(403).json(errorBody(req, 'TENANT_FORBIDDEN', 'Usuário sem vínculo ativo com uma barbearia.'));
    req.tenant = {
      id: Number(context.barbearia_id),
      membershipRole: context.papel,
      professionalId: context.colaborador_id == null ? null : Number(context.colaborador_id),
      capabilities: new Set(CAPABILITIES[context.papel] || []),
    };
    return next();
  } catch (error) {
    return next(error);
  }
}

function requireCapability(capability) {
  return (req, res, next) => {
    if (!req.tenant?.capabilities?.has(capability)) {
      return res.status(403).json(errorBody(req, 'CAPABILITY_FORBIDDEN', 'Permissão insuficiente para esta operação.'));
    }
    return next();
  };
}

function requireAdmin(req, res, next) {
  if (req.tenant?.membershipRole !== 'owner') {
    return res.status(403).json(errorBody(req, 'ADMIN_FORBIDDEN', 'Acesso restrito ao administrador da barbearia.'));
  }
  return next();
}

module.exports = { CAPABILITIES, tenantContext, requireCapability, requireAdmin };
