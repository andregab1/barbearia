// ==========================================
// CONTROLLER: Autenticação
// RF01 - Cadastro | RF02 - Login | RF03 - Logout
// ==========================================
const bcrypt = require('bcryptjs');
const jwt    = require('jsonwebtoken');
const crypto = require('crypto');
const { pool } = require('../config/database');

function hashToken(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

function duracaoEmMs(valor = '7d') {
  const match = String(valor).trim().match(/^(\d+)([smhd])$/i);
  if (!match) return 7 * 24 * 60 * 60 * 1000;
  const fatores = { s: 1000, m: 60000, h: 3600000, d: 86400000 };
  return Number(match[1]) * fatores[match[2].toLowerCase()];
}

function gerarTokens(usuario) {
  const payload = { id: usuario.id, nome: usuario.nome, role: usuario.role };
  const access  = jwt.sign(payload, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRES_IN || '8h',
  });
  const refresh = jwt.sign(
    { id: usuario.id, jti: crypto.randomUUID() },
    process.env.JWT_REFRESH_SECRET,
    { expiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '7d' },
  );
  return { access, refresh };
}

// ==========================================
// RF01: Cadastro de cliente
// ==========================================
async function cadastrar(req, res) {
  const nome = String(req.body.nome || '').trim();
  const telefone = String(req.body.telefone || '').replace(/\D/g, '');
  const senha = String(req.body.senha || '');
  const email = String(req.body.email || '').trim().toLowerCase() || null;
  const username = String(req.body.username || '').trim().toLowerCase() || null;
  if (!nome || !telefone || !senha) {
    return res.status(400).json({ erro: 'Nome, telefone e senha são obrigatórios.' });
  }
  if (nome.length < 2 || nome.length > 100 || telefone.length < 10 || telefone.length > 15 || senha.length < 8) {
    return res.status(400).json({ code: 'INVALID_REGISTRATION', erro: 'Confira nome, telefone e senha (mínimo de 8 caracteres).' });
  }
  if (email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return res.status(400).json({ code: 'INVALID_EMAIL', erro: 'E-mail inválido.' });
  }
  if (username && !/^[a-z0-9._]{3,30}$/.test(username)) {
    return res.status(400).json({ code: 'INVALID_USERNAME', erro: 'Nome de usuário deve ter de 3 a 30 caracteres, usando letras, números, ponto ou sublinhado.' });
  }
  try {
    const [existe] = await pool.query(
      'SELECT id FROM usuarios WHERE telefone = ? OR (? IS NOT NULL AND username = ?)', [telefone, username, username]
    );
    if (existe.length > 0) {
      return res.status(409).json({ erro: 'Telefone já cadastrado.' });
    }
    const hash = await bcrypt.hash(senha, 10);
    await pool.query(
      'INSERT INTO usuarios (nome, email, username, telefone, senha_hash, role) VALUES (?, ?, ?, ?, ?, ?)',
      [nome, email, username, telefone, hash, 'cliente']
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
  const { login, email, telefone, senha } = req.body;

  // Flutter envia 'login' — detecta se é email ou telefone
  const emailFinal    = email    || (login && login.includes('@') ? login : null);
  const telefoneFinal = telefone || (login && !login.includes('@') ? login : null);

  if (!senha || (!emailFinal && !telefoneFinal)) {
    return res.status(400).json({ erro: 'Informe email ou telefone e senha.' });
  }
  try {
    // 1. Busca usuário
    const [rows] = await pool.query(
      `SELECT id, nome, email, telefone, senha_hash, role, ativo
       FROM usuarios WHERE (email = ? OR telefone = ?) LIMIT 1`,
      [emailFinal || null, telefoneFinal || null]
    );
    if (rows.length === 0) {
      return res.status(401).json({ erro: 'Credenciais inválidas.' });
    }
    const usuario = rows[0];
    if (!usuario.ativo) {
      return res.status(401).json({ erro: 'Conta desativada.' });
    }

    // 2. Verifica senha
    const senhaOk = await bcrypt.compare(senha, usuario.senha_hash);
    if (!senhaOk) {
      return res.status(401).json({ erro: 'Credenciais inválidas.' });
    }

    // 3. Busca colaborador_id
    let colaboradorId = null;
    let barbeariaId = null;
    const [memberships] = await pool.query(
      `SELECT m.barbearia_id, m.papel, c.id AS colaborador_id
         FROM memberships m
         LEFT JOIN colaboradores c ON c.barbearia_id = m.barbearia_id
          AND c.usuario_id = m.usuario_id AND c.ativo = 1
        WHERE m.usuario_id = ? AND m.ativo = 1
        ORDER BY FIELD(m.papel, 'owner', 'manager', 'receptionist', 'professional')
        LIMIT 1`,
      [usuario.id],
    );
    if (memberships.length > 0) {
      const membership = memberships[0];
      barbeariaId = membership.barbearia_id;
      colaboradorId = membership.colaborador_id;
      usuario.role = membership.papel === 'professional' ? 'barbeiro' : 'admin';
    }
    if (usuario.role === 'barbeiro' || usuario.role === 'admin') {
      if (!barbeariaId) {
        const [colab] = await pool.query(
          'SELECT id, barbearia_id FROM colaboradores WHERE usuario_id = ? AND ativo = 1 LIMIT 1',
          [usuario.id]
        );
        if (colab.length > 0) {
          colaboradorId = colab[0].id;
          barbeariaId = colab[0].barbearia_id;
        }
      }
    }
    if (!barbeariaId && usuario.role === 'admin') {
      const [administradas] = await pool.query(
        'SELECT id FROM barbearias WHERE admin_id = ? AND ativa = 1 ORDER BY id LIMIT 1',
        [usuario.id],
      );
      if (administradas.length > 0) barbeariaId = administradas[0].id;
    }
    if (!barbeariaId) {
      const [ativas] = await pool.query('SELECT id FROM barbearias WHERE ativa = 1 ORDER BY id LIMIT 1');
      if (ativas.length > 0) barbeariaId = ativas[0].id;
    }

    // 4. Gera tokens
    const { access, refresh } = gerarTokens(usuario);

    // 5. Salva refresh token
    const expira = new Date(Date.now() + duracaoEmMs(process.env.JWT_REFRESH_EXPIRES_IN));
    const expiraStr = expira.toISOString().slice(0, 19).replace('T', ' ');
    await pool.query(
      'INSERT INTO refresh_tokens (usuario_id, token, expira_em) VALUES (?, ?, ?)',
      [usuario.id, hashToken(refresh), expiraStr]
    );

    // 6. Busca tema da barbearia
    let corPrimaria = '#C9A84C';
    let logoUrl     = null;
    try {
      const [barbearia] = await pool.query(
        'SELECT cor_primaria, logo_url FROM barbearias WHERE id = ? LIMIT 1',
        [barbeariaId],
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
      barbearia_id: barbeariaId,
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
      await pool.query('DELETE FROM refresh_tokens WHERE token = ?', [hashToken(refresh_token)]);
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
    const tokenHash = hashToken(refresh_token);
    const [rows]  = await pool.query(
      'SELECT id FROM refresh_tokens WHERE token = ? AND expira_em > NOW()',
      [tokenHash]
    );
    if (rows.length === 0) {
      return res.status(401).json({ erro: 'Token inválido ou expirado.' });
    }
    const [usuarios] = await pool.query(
      'SELECT id, nome, role FROM usuarios WHERE id = ? AND ativo = 1', [payload.id]
    );
    if (usuarios.length === 0) {
      return res.status(401).json({ erro: 'Usuário não encontrado.' });
    }
    const [membership] = await pool.query(
      `SELECT papel FROM memberships WHERE usuario_id = ? AND ativo = 1
       ORDER BY FIELD(papel, 'owner', 'manager', 'receptionist', 'professional') LIMIT 1`,
      [usuarios[0].id],
    );
    if (membership.length > 0) {
      usuarios[0].role = membership[0].papel === 'professional' ? 'barbeiro' : 'admin';
    }
    const { access, refresh: novoRefresh } = gerarTokens(usuarios[0]);
    const expira = new Date(Date.now() + duracaoEmMs(process.env.JWT_REFRESH_EXPIRES_IN));
    const expiraStr = expira.toISOString().slice(0, 19).replace('T', ' ');
    const connection = await pool.getConnection();
    try {
      await connection.beginTransaction();
      const [removido] = await connection.query(
        'DELETE FROM refresh_tokens WHERE id = ? AND token = ?',
        [rows[0].id, tokenHash],
      );
      if (removido.affectedRows !== 1) {
        await connection.rollback();
        return res.status(401).json({ erro: 'Token já utilizado.' });
      }
      await connection.query(
        'INSERT INTO refresh_tokens (usuario_id, token, expira_em) VALUES (?, ?, ?)',
        [usuarios[0].id, hashToken(novoRefresh), expiraStr],
      );
      await connection.commit();
    } catch (error) {
      await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
    return res.json({ access_token: access, refresh_token: novoRefresh });
  } catch (err) {
    console.error('ERRO refresh:', err.message);
    return res.status(401).json({ erro: 'Token inválido.' });
  }
}

module.exports = { cadastrar, login, logout, refresh };
