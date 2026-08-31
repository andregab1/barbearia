// ==========================================
// CONTROLLER: Barbearias
// RF03 - Cadastro | RF04 - Personalização
// Logo armazenada como base64 no banco
// ==========================================
const { pool } = require('../config/database');
const { obterBarbeariaAdministrada } = require('../utils/access');

async function listarPublicas(req, res) {
  const busca = String(req.query.busca || '').trim();
  const limite = Math.min(Math.max(Number.parseInt(req.query.limite, 10) || 30, 1), 50);
  try {
    const params = [];
    let filtro = 'WHERE 1 = 1';
    if (busca) {
      filtro += ' AND b.nome LIKE ?';
      params.push(`%${busca}%`);
    }
    params.push(limite);
    const [rows] = await pool.query(
      `SELECT b.id, b.nome, b.telefone, b.email, b.logo_url, b.cor_primaria,
              COUNT(DISTINCT c.id) AS total_profissionais,
              COUNT(DISTINCT s.id) AS total_servicos
         FROM barbearias b
         LEFT JOIN colaboradores c ON c.barbearia_id = b.id AND c.ativo = 1
         LEFT JOIN servicos s ON s.barbearia_id = b.id AND s.ativo = 1
         ${filtro}
        GROUP BY b.id
        ORDER BY b.nome ASC
        LIMIT ?`,
      params,
    );
    return res.json(rows);
  } catch (err) {
    console.error('ERRO listar barbearias:', err.message);
    return res.status(500).json({ erro: 'Erro interno ao listar barbearias.' });
  }
}

async function cadastrar(req, res) {
  const { nome, telefone, email, cnpj } = req.body;
  const admin_id = req.usuario.id;
  try {
    const [result] = await pool.query(
      `INSERT INTO barbearias (nome, telefone, email, cnpj, admin_id)
       VALUES (?, ?, ?, ?, ?)`,
      [nome, telefone || null, email || null, cnpj || null, admin_id]
    );
    return res.status(201).json({ id: result.insertId, mensagem: 'Barbearia cadastrada!' });
  } catch (err) {
    console.error('ERRO cadastrar barbearia:', err.message);
    return res.status(500).json({ erro: 'Erro interno ao cadastrar barbearia.' });
  }
}

async function buscar(req, res) {
  const { id } = req.params;
  try {
    const [rows] = await pool.query(
      `SELECT id, nome, telefone, email, cor_primaria, cor_secundaria, logo_url
       FROM barbearias WHERE id = ?`,
      [id]
    );
    if (rows.length === 0) return res.status(404).json({ erro: 'Barbearia não encontrada.' });
    return res.json(rows[0]);
  } catch (err) {
    return res.status(500).json({ erro: 'Erro interno ao buscar barbearia.' });
  }
}

async function personalizar(req, res) {
  const { id } = req.params;
  const { cor_primaria, cor_secundaria, logo_base64 } = req.body;

  try {
    const acesso = await obterBarbeariaAdministrada(req.usuario.id, id);
    if (!acesso) return res.status(403).json({ code: 'TENANT_FORBIDDEN', erro: 'Sem permissão para personalizar esta barbearia.' });
    const [barbearia] = await pool.query(
      'SELECT id FROM barbearias WHERE id = ?', [id]
    );
    if (barbearia.length === 0) {
      return res.status(404).json({ erro: 'Barbearia não encontrada.' });
    }

    const campos  = [];
    const valores = [];

    // Logo recebida como base64 via JSON
    let logoUrl = null;
    if (logo_base64 && logo_base64.startsWith('data:image')) {
      logoUrl = logo_base64;
      campos.push('logo_url = ?');
      valores.push(logoUrl);
    }

    // Arquivo via multipart (fallback)
    if (!logoUrl && req.file) {
      const base64 = req.file.buffer.toString('base64');
      const mime   = req.file.mimetype;
      logoUrl      = `data:${mime};base64,${base64}`;
      campos.push('logo_url = ?');
      valores.push(logoUrl);
    }

    if (cor_primaria && !/^#[0-9a-f]{6}$/i.test(cor_primaria)) {
      return res.status(400).json({ code: 'INVALID_COLOR', erro: 'Cor primária inválida.' });
    }
    if (cor_secundaria && !/^#[0-9a-f]{6}$/i.test(cor_secundaria)) {
      return res.status(400).json({ code: 'INVALID_COLOR', erro: 'Cor secundária inválida.' });
    }
    if (cor_primaria) {
      campos.push('cor_primaria = ?');
      valores.push(cor_primaria);
    }
    if (cor_secundaria) {
      campos.push('cor_secundaria = ?');
      valores.push(cor_secundaria);
    }

    if (campos.length === 0) {
      return res.status(400).json({ erro: 'Nenhum dado para atualizar.' });
    }

    valores.push(id);
    await pool.query(
      `UPDATE barbearias SET ${campos.join(', ')} WHERE id = ?`,
      valores
    );

    return res.json({
      mensagem:    'Identidade visual atualizada!',
      logo_url:    logoUrl,
      cor_primaria,
    });
  } catch (err) {
    console.error('ERRO personalizar:', err.message);
    return res.status(500).json({ erro: 'Erro interno ao personalizar: ' + err.message });
  }
}

async function atualizar(req, res) {
  const { id } = req.params;
  const { nome, telefone, email } = req.body;
  try {
    const acesso = await obterBarbeariaAdministrada(req.usuario.id, id);
    if (!acesso) return res.status(403).json({ code: 'TENANT_FORBIDDEN', erro: 'Sem permissão para atualizar esta barbearia.' });
    await pool.query(
      'UPDATE barbearias SET nome = ?, telefone = ?, email = ? WHERE id = ?',
      [nome, telefone || null, email || null, id]
    );
    return res.json({ mensagem: 'Barbearia atualizada!' });
  } catch (err) {
    return res.status(500).json({ erro: 'Erro interno.' });
  }
}

module.exports = { listarPublicas, cadastrar, buscar, personalizar, atualizar };
