const bcrypt = require('bcryptjs');
const { pool } = require('../config/database');
const { validateOwnerRegistration } = require('../utils/validation');
const { errorBody } = require('../middlewares/request.middleware');

async function registerOwner(req, res) {
  const validation = validateOwnerRegistration(req.body);
  if (!validation.valid) {
    return res.status(422).json(errorBody(req, 'VALIDATION_ERROR', 'Revise os campos informados.', validation.fields));
  }
  const { ownerName, shopName, email, phone, password, slug } = validation.data;
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const [existingUsers] = await connection.query(
      'SELECT id FROM usuarios WHERE email = ? OR telefone = ? LIMIT 1 FOR UPDATE',
      [email, phone],
    );
    if (existingUsers.length > 0) {
      await connection.rollback();
      return res.status(409).json(errorBody(req, 'ACCOUNT_EXISTS', 'E-mail ou telefone já cadastrado.'));
    }
    const [existingShops] = await connection.query(
      'SELECT id FROM barbearias WHERE slug = ? LIMIT 1 FOR UPDATE',
      [slug],
    );
    if (existingShops.length > 0) {
      await connection.rollback();
      return res.status(409).json(errorBody(req, 'SLUG_UNAVAILABLE', 'Este endereço público já está em uso.', { slug: 'Escolha outro identificador.' }));
    }
    const passwordHash = await bcrypt.hash(password, 12);
    const [userResult] = await connection.query(
      `INSERT INTO usuarios (nome, email, telefone, senha_hash, role) VALUES (?, ?, ?, ?, 'admin')`,
      [ownerName, email, phone, passwordHash],
    );
    const [shopResult] = await connection.query(
      `INSERT INTO barbearias (admin_id, nome, slug, telefone, email, onboarding_concluido) VALUES (?, ?, ?, ?, ?, 0)`,
      [userResult.insertId, shopName, slug, phone, email],
    );
    await connection.query(
      `INSERT INTO memberships (barbearia_id, usuario_id, papel) VALUES (?, ?, 'owner')`,
      [shopResult.insertId, userResult.insertId],
    );
    await connection.query(
      `INSERT INTO subscriptions (barbearia_id, plan_id, status, periodo_inicio, periodo_fim)
       SELECT ?, id, 'trial', NOW(), DATE_ADD(NOW(), INTERVAL 14 DAY) FROM plans WHERE codigo = 'trial' LIMIT 1`,
      [shopResult.insertId],
    );
    await connection.query(
      `INSERT INTO audit_logs (barbearia_id, usuario_id, acao, recurso, recurso_id, request_id)
       VALUES (?, ?, 'owner.registered', 'barbearia', ?, ?)`,
      [shopResult.insertId, userResult.insertId, String(shopResult.insertId), req.requestId],
    );
    await connection.commit();
    return res.status(201).json({
      data: { user_id: userResult.insertId, barbershop_id: shopResult.insertId, slug, onboarding_completed: false, trial_days: 14 },
      message: 'Barbearia criada. Continue a configuração inicial.',
      requestId: req.requestId,
    });
  } catch (error) {
    await connection.rollback();
    console.error(JSON.stringify({ level: 'error', event: 'owner_registration_failed', requestId: req.requestId, error: error.message }));
    return res.status(500).json(errorBody(req, 'INTERNAL_ERROR', 'Não foi possível criar a barbearia.'));
  } finally {
    connection.release();
  }
}

module.exports = { registerOwner };
