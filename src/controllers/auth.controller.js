// ==========================================
// CONTROLLER: Autenticação de Usuários
// RF01 - Cadastro | RF02 - Login
// ==========================================
const bcrypt     = require('bcryptjs');
const jwt        = require('jsonwebtoken');
const { pool }   = require('../config/database');

function gerarTokens(payload) {
  const access  = jwt.sign(payload, process.env.JWT_SECRET,         { expiresIn: process.env.JWT_EXPIRES_IN });
  const refresh = jwt.sign(payload, process.env.JWT_REFRESH_SECRET, { expiresIn: process.env.JWT_REFRESH_EXPIRES_IN });
  return { access, refresh };
}

// ==========================================
// RF01: Cadastro de novo usuário (cliente)
// ==========================================
async function cadastrar(req, res) {
  const { nome, email, telefone, senha } = req.body;

  if (!nome || !telefone || !senha) {
    return res.status(400).json({ erro: 'Nome, telefone e senha são obrigatórios.' });
  }

  try {
    const [existente] = await pool.query(
      'SELECT id FROM usuarios WHERE email = ? OR telefone = ?',
      [email || null, telefone]
    );
    if (existente.length > 0) {
      return res.status(409).json({ erro: 'E-mail ou telefone já cadastrado.' });
    }

    const hash = await bcrypt.hash(senha, 10);
    const [result] = await pool.query(
      'INSERT INTO usuarios (nome, email, telefone, senha_hash, role) VALUES (?, ?, ?, ?, ?)',
      [nome, email || null, telefone, hash, 'cliente']
    );

    return res.status(201).json({ mensagem: 'Cadastro realizado com sucesso!', id: result.insertId });
  } catch (err) {
    return res.status(500).json({ erro: 'Erro interno ao cadastrar usuário.' });
  }
}

// ==========================================
// RF02: Login de usuário
// ==========================================
async function login(req, res) {
  const { login: loginInput, senha } = req.body;

  if (!loginInput || !senha) {
    return res.status(400).json({ erro: 'Login e senha são obrigatórios.' });
  }

  try {
    const [rows] = await pool.query(
      'SELECT * FROM usuarios WHERE (email = ? OR telefone = ?) AND ativo = 1',
      [loginInput, loginInput]
    );
    if (rows.length === 0) {
      return res.status(401).json({ erro: 'Credenciais inválidas.' });
    }

    const usuario = rows[0];
    const senhaOk = await bcrypt.compare(senha, usuario.senha_hash);
    if (!senhaOk) {
      return res.status(401).json({ erro: 'Credenciais inválidas.' });
    }

    // Busca colaborador_id se for barbeiro ou admin
    let colaboradorId = null;
    if (usuario.role === 'barbeiro' || usuario.role === 'admin') {
      const [colab] = await pool.query(
        'SELECT id FROM colaboradores WHERE usuario_id = ? AND ativo = 1 LIMIT 1',
        [usuario.id]
      );
      if (colab.length > 0) colaboradorId = colab[0].id;
    }

    const payload = { id: usuario.id, nome: usuario.nome, role: usuario.role };
    const { access, refresh } = gerarTokens(payload);

    const expira = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
    await pool.query(
      'INSERT INTO refresh_tokens (usuario_id, token, expira_em) VALUES (?, ?, ?)',
      [usuario.id, refresh, expira]
    );

    return res.json({
      access_token:   access,
      refresh_token:  refresh,
      usuario:        payload,
      colaborador_id: colaboradorId,
    });
  } catch (err) {
    return res.status(500).json({ erro: 'Erro interno ao realizar login.' });
  }
}

// ==========================================
// RNF01: Renovar access token via refresh
// ==========================================
async function refreshToken(req, res) {
  const { refresh_token } = req.body;
  if (!refresh_token) return res.status(400).json({ erro: 'Refresh token não fornecido.' });

  try {
    const payload = jwt.verify(refresh_token, process.env.JWT_REFRESH_SECRET);
    const [rows]  = await pool.query(
      'SELECT * FROM refresh_tokens WHERE token = ? AND expira_em > NOW()',
      [refresh_token]
    );
    if (rows.length === 0) return res.status(401).json({ erro: 'Refresh token inválido ou expirado.' });

    const novoPayload = { id: payload.id, nome: payload.nome, role: payload.role };
    const { access }  = gerarTokens(novoPayload);

    return res.json({ access_token: access });
  } catch {
    return res.status(401).json({ erro: 'Refresh token inválido.' });
  }
}

// ==========================================
// RNF01: Logout - invalidar refresh token
// ==========================================
async function logout(req, res) {
  const { refresh_token } = req.body;
  if (refresh_token) {
    await pool.query('DELETE FROM refresh_tokens WHERE token = ?', [refresh_token]);
  }
  return res.json({ mensagem: 'Logout realizado com sucesso.' });
}

module.exports = { cadastrar, login, refreshToken, logout };