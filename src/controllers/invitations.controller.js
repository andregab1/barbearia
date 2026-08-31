const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const { pool } = require('../config/database');
const { obterBarbeariaAdministrada } = require('../utils/access');
const { normalizeEmail, normalizePhone } = require('../utils/validation');
const { errorBody } = require('../middlewares/request.middleware');

function hashToken(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

async function list(req, res) {
  const tenant = await obterBarbeariaAdministrada(req.usuario.id, req.params.barbearia_id);
  if (!tenant) return res.status(403).json(errorBody(req, 'FORBIDDEN', 'Acesso não permitido.'));
  const [rows] = await pool.query(
    `SELECT id, email, telefone, papel, expira_em, aceito_em, criado_em
       FROM invitations WHERE barbearia_id = ? ORDER BY criado_em DESC LIMIT 100`,
    [tenant.id],
  );
  return res.json({ data: rows, requestId: req.requestId });
}

async function create(req, res) {
  const tenant = await obterBarbeariaAdministrada(req.usuario.id, req.params.barbearia_id);
  if (!tenant) return res.status(403).json(errorBody(req, 'FORBIDDEN', 'Acesso não permitido.'));
  const email = normalizeEmail(req.body.email) || null;
  const phone = normalizePhone(req.body.phone) || null;
  const role = String(req.body.role || 'professional');
  if ((!email && !phone) || !['manager', 'receptionist', 'professional'].includes(role)) {
    return res.status(422).json(errorBody(req, 'VALIDATION_ERROR', 'Informe contato e papel válidos.'));
  }
  const token = crypto.randomBytes(32).toString('base64url');
  await pool.query(
    `INSERT INTO invitations (barbearia_id, email, telefone, papel, token_hash, expira_em, convidado_por)
     VALUES (?, ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL 7 DAY), ?)`,
    [tenant.id, email, phone, role, hashToken(token), req.usuario.id],
  );
  return res.status(201).json({
    data: { token, expires_in_days: 7 },
    message: 'Convite criado. O token é exibido apenas nesta resposta.',
    requestId: req.requestId,
  });
}

async function accept(req, res) {
  const token = String(req.body.token || '');
  const name = String(req.body.name || '').trim();
  const password = String(req.body.password || '');
  if (!token || name.length < 2 || password.length < 8 || !/[A-Za-z]/.test(password) || !/\d/.test(password)) {
    return res.status(422).json(errorBody(req, 'VALIDATION_ERROR', 'Token, nome e senha segura são obrigatórios.'));
  }
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const [invitations] = await connection.query(
      `SELECT id, barbearia_id, email, telefone, papel FROM invitations
       WHERE token_hash = ? AND aceito_em IS NULL AND expira_em > NOW() LIMIT 1 FOR UPDATE`,
      [hashToken(token)],
    );
    if (invitations.length === 0) {
      await connection.rollback();
      return res.status(410).json(errorBody(req, 'INVITATION_INVALID', 'Convite inválido ou expirado.'));
    }
    const invitation = invitations[0];
    const [existing] = await connection.query(
      'SELECT id FROM usuarios WHERE email = ? OR telefone = ? LIMIT 1 FOR UPDATE',
      [invitation.email, invitation.telefone],
    );
    let userId;
    if (existing.length > 0) {
      userId = existing[0].id;
    } else {
      const passwordHash = await bcrypt.hash(password, 12);
      const [created] = await connection.query(
        `INSERT INTO usuarios (nome, email, telefone, senha_hash, role)
         VALUES (?, ?, ?, ?, ?)`,
        [name, invitation.email, invitation.telefone, passwordHash,
          invitation.papel === 'professional' ? 'barbeiro' : 'admin'],
      );
      userId = created.insertId;
    }
    await connection.query(
      `INSERT INTO memberships (barbearia_id, usuario_id, papel) VALUES (?, ?, ?)
       ON DUPLICATE KEY UPDATE papel = VALUES(papel), ativo = 1`,
      [invitation.barbearia_id, userId, invitation.papel],
    );
    if (invitation.papel === 'professional') {
      await connection.query(
        `INSERT INTO colaboradores (barbearia_id, usuario_id, ativo) VALUES (?, ?, 1)
         ON DUPLICATE KEY UPDATE ativo = 1`,
        [invitation.barbearia_id, userId],
      );
    }
    await connection.query('UPDATE invitations SET aceito_em = NOW() WHERE id = ?', [invitation.id]);
    await connection.query(
      `INSERT INTO audit_logs (barbearia_id, usuario_id, acao, recurso, recurso_id, request_id)
       VALUES (?, ?, 'invitation.accepted', 'invitation', ?, ?)`,
      [invitation.barbearia_id, userId, String(invitation.id), req.requestId],
    );
    await connection.commit();
    return res.json({ data: { user_id: userId, role: invitation.papel }, message: 'Convite aceito.', requestId: req.requestId });
  } catch (error) {
    await connection.rollback();
    console.error(JSON.stringify({ level: 'error', event: 'invitation_accept_failed', requestId: req.requestId, error: error.message }));
    return res.status(500).json(errorBody(req, 'INTERNAL_ERROR', 'Não foi possível aceitar o convite.'));
  } finally {
    connection.release();
  }
}

module.exports = { list, create, accept };
