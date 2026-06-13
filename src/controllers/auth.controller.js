// ==========================================
// CONTROLLER: Autenticação
// RF01 - Cadastro | RF02 - Login | RF03 - Logout
// ==========================================
const bcrypt = require('bcryptjs');
const jwt    = require('jsonwebtoken');
const { pool } = require('../config/database');

function gerarTokens(usuario) {
  const payload = { id: usuario.id, nome: usuario.nome, role: usuario.role };
  const access  = jwt.sign(payload, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRES_IN || '8h',
  });
  const refresh = jwt.sign({ id: usuario.id }, process.env.JWT_REFRESH_SECRET, {
    expiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '7d',
  });
  return { access, refresh };
}

// ==========================================
// RF01: Cadastro de cliente
// ==========================================
async function cadastrar(req, res) {
  const { nome, telefone, senha, email } = req.body;
  if (!nome || !telefone || !senha) {
    return res.status(400).json({ erro: 'Nome, telefone e senha são obrigatórios.' });
  }
  try {
    const [existe] = await pool.query(
      'SELECT id FROM usuarios WHERE telefone = ?', [telefone]
    );
    if (existe.length > 0) {
      return res.status(409).json({ erro: 'Telefone já cadastrado.' });
    }
    const hash = await bcrypt.hash(senha, 10);
    await pool.query(
      'INSERT INTO usuarios (nome, email, telefone, senha_hash, role) VALUES (?, ?, ?, ?, ?)',
      [nome, email || null, telefone, hash, 'cliente']
    );
    return res.status(201).json({ mensagem: 'Cadastro realizado com sucesso!' });
  } catch (err) {
    console.error('ERRO cadastrar:', err.message, err.sql || '');
    return res.status(500).json({ erro: 'Erro interno ao cadastrar.' });
  }
}

// ==========================================
// RF02: Login
// ==========================================
async function login(req, res) {
  const { email, telefone, senha } = req.body;
  if (!senha || (!email && !telefone)) {
    return res.status(400).json({ erro: 'Informe email ou telefone e senha.' });
  }
  try {
    // 1. Busca usuário
    const [rows] = await pool.query(
      `SELECT id, nome, email, telefone, senha_hash, role, ativo
       FROM usuarios WHERE (email = ? OR telefone = ?) LIMIT 1`,
      [email || null, telefone || null]
    );
    if (rows.length === 0) {
      return res.status(401).json({ erro: 'Usuário não encontrado.' });
    }
    const usuario = rows[0];
    if (!usuario.ativo) {
      return res.status(401).json({ erro: 'Conta desativada.' });
    }

    // 2. Verifica senha
    const senhaOk = await bcrypt.compare(senha, usuario.senha_hash);
    if (!senhaOk) {
      return res.status(401).json({ erro: 'Senha incorreta.' });
    }

    // 3. Busca colaborador_id
    let colaboradorId = null;
    if (usuario.role === 'barbeiro' || usuario.role === 'admin') {
      const [colab] = await pool.query(
        'SELECT id FROM colaboradores WHERE usuario_id = ? AND ativo = 1 LIMIT 1',
        [usuario.id]
      );
      if (colab.length > 0) colaboradorId = colab[0].id;
    }

    // 4. Gera tokens
    const { access, refresh } = gerarTokens(usuario);

    // 5. Salva refresh token
    const expira = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
    const expiraStr = expira.toISOString().slice(0, 19).replace('T', ' ');
    await pool.query(
      'INSERT INTO refresh_tokens (usuario_id, token, expira_em) VALUES (?, ?, ?)',
      [usuario.id, refresh, expiraStr]
    );

    // 6. Busca tema da barbearia
    let corPrimaria = '#C9A84C';
    let logoUrl     = null;
    try {
      const [barbearia] = await pool.query(
        'SELECT cor_primaria, logo_url FROM barbearias WHERE id = 1 LIMIT 1'
      );
      if (barbearia.length > 0) {
        corPrimaria = barbearia[0].cor_primaria || corPrimaria;
        logoUrl     = barbearia[0].logo_url;
      }
    } catch (e) {
      console.error('AVISO: erro ao buscar barbearia no login:', e.message);
    }

    return res.json({
      access_token:  access,
      refresh_token: refresh,
      colaborador_id: colaboradorId,
      usuario: {
        id:    usuario.id,
        nome:  usuario.nome,
        email: usuario.email,
        role:  usuario.role,
      },
      barbearia: { cor_primaria: corPrimaria, logo_url: logoUrl },
    });
  } catch (err) {
    console.error('ERRO login:', err.message, err.sql || '');
    return res.status(500).json({ erro: 'Erro interno ao fazer login.' });
  }
}

// ==========================================
// RF03: Logout
// ==========================================
async function logout(req, res) {
  const { refresh_token } = req.body;
  try {
    if (refresh_token) {
      await pool.query('DELETE FROM refresh_tokens WHERE token = ?', [refresh_token]);
    }
    return res.json({ mensagem: 'Logout realizado.' });
  } catch (err) {
    console.error('ERRO logout:', err.message);
    return res.json({ mensagem: 'Logout realizado.' }); // não falha o logout
  }
}

// ==========================================
// RF02: Refresh token
// ==========================================
async function refresh(req, res) {
  const { refresh_token } = req.body;
  if (!refresh_token) {
    return res.status(400).json({ erro: 'Refresh token obrigatório.' });
  }
  try {
    const payload = jwt.verify(refresh_token, process.env.JWT_REFRESH_SECRET);
    const [rows]  = await pool.query(
      'SELECT id FROM refresh_tokens WHERE token = ? AND expira_em > NOW()',
      [refresh_token]
    );
    if (rows.length === 0) {
      return res.status(401).json({ erro: 'Token inválido ou expirado.' });
    }
    const [usuarios] = await pool.query(
      'SELECT id, nome, role FROM usuarios WHERE id = ?', [payload.id]
    );
    if (usuarios.length === 0) {
      return res.status(401).json({ erro: 'Usuário não encontrado.' });
    }
    const { access } = gerarTokens(usuarios[0]);
    return res.json({ access_token: access });
  } catch (err) {
    console.error('ERRO refresh:', err.message);
    return res.status(401).json({ erro: 'Token inválido.' });
  }
}

module.exports = { cadastrar, login, logout, refresh };