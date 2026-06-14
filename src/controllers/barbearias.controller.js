// ==========================================
// CONTROLLER: Barbearias
// RF03 - Cadastro | RF04 - Personalização
// ==========================================
const { pool } = require('../config/database');
const path     = require('path');
const fs       = require('fs');

// ==========================================
// RF03: Cadastrar nova barbearia
// ==========================================
async function cadastrar(req, res) {
  const { nome, descricao, telefone, endereco } = req.body;
  const admin_id = req.usuario.id;

  if (!nome) return res.status(400).json({ erro: 'Nome da barbearia é obrigatório.' });

  try {
    const [existente] = await pool.query(
      'SELECT id FROM barbearias WHERE admin_id = ?',
      [admin_id]
    );
    if (existente.length > 0) {
      return res.status(409).json({ erro: 'Você já possui uma barbearia cadastrada.' });
    }

    const [result] = await pool.query(
      `INSERT INTO barbearias (admin_id, nome, descricao, telefone, endereco)
       VALUES (?, ?, ?, ?, ?)`,
      [admin_id, nome, descricao || null, telefone || null, endereco || null]
    );

    return res.status(201).json({ mensagem: 'Barbearia cadastrada com sucesso!', id: result.insertId });
  } catch (err) {
    return res.status(500).json({ erro: 'Erro interno ao cadastrar barbearia.' });
  }
}

// ==========================================
// RF03: Buscar dados da barbearia
// ==========================================
async function buscar(req, res) {
  const { id } = req.params;

  try {
    const [rows] = await pool.query(
      `SELECT b.id, b.nome, b.descricao, b.telefone, b.endereco,
              b.cor_primaria, b.cor_secundaria,
              -- RF04: URL da logo usada como background na tela mobile do cliente
              b.logo_url
       FROM barbearias b
       WHERE b.id = ? AND b.ativa = 1`,
      [id]
    );
    if (rows.length === 0) return res.status(404).json({ erro: 'Barbearia não encontrada.' });

    return res.json(rows[0]);
  } catch (err) {
    return res.status(500).json({ erro: 'Erro interno ao buscar barbearia.' });
  }
}

// ==========================================
// RF04: Personalizar identidade visual
// Cores + logo PNG usada como background na tela mobile
// ==========================================
async function personalizar(req, res) {
  const { id }                          = req.params;
  const { cor_primaria, cor_secundaria } = req.body;
  const admin_id                         = req.usuario.id;

  try {
    const [barbearia] = await pool.query(
      'SELECT id, logo_url FROM barbearias WHERE id = ? AND admin_id = ?',
      [id, admin_id]
    );
    if (barbearia.length === 0) {
      return res.status(403).json({ erro: 'Barbearia não encontrada ou sem permissão.' });
    }

    // RF04: Processa upload do logo PNG para uso como background mobile
    let logo_url = barbearia[0].logo_url;
    if (req.file) {
      if (logo_url) {
        const logoAntigo = path.join(__dirname, '..', 'uploads', path.basename(logo_url));
        if (fs.existsSync(logoAntigo)) fs.unlinkSync(logoAntigo);
      }
      logo_url = `/uploads/${req.file.filename}`;
    }

    const campos = [];
    const valores = [];

    if (cor_primaria)   { campos.push('cor_primaria = ?');   valores.push(cor_primaria); }
    if (cor_secundaria) { campos.push('cor_secundaria = ?'); valores.push(cor_secundaria); }
    if (logo_url)       { campos.push('logo_url = ?');       valores.push(logo_url); }

    if (campos.length === 0) {
      return res.status(400).json({ erro: 'Nenhum dado para atualizar.' });
    }

    valores.push(id);
    await pool.query(`UPDATE barbearias SET ${campos.join(', ')} WHERE id = ?`, valores);

    return res.json({ mensagem: 'Identidade visual atualizada com sucesso!', logo_url });
  } catch (err) {
    return res.status(500).json({ erro: 'Erro interno ao personalizar barbearia.' });
  }
}

// ==========================================
// RF03: Atualizar dados gerais da barbearia
// ==========================================
async function atualizar(req, res) {
  const { id }                              = req.params;
  const { nome, descricao, telefone, endereco } = req.body;
  const admin_id                             = req.usuario.id;

  try {// ==========================================
// CONTROLLER: Barbearias
// RF03 - Cadastro | RF04 - Personalização
// Logo armazenada como base64 no banco
// ==========================================
const { pool } = require('../config/database');

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
  const { cor_primaria, cor_secundaria } = req.body;

  try {
    const [barbearia] = await pool.query(
      'SELECT id FROM barbearias WHERE id = ?', [id]
    );
    if (barbearia.length === 0) {
      return res.status(404).json({ erro: 'Barbearia não encontrada.' });
    }

    const campos  = [];
    const valores = [];

    // Salva logo como base64 no banco (sem filesystem)
    let logoUrl = null;
    if (req.file) {
      const base64 = req.file.buffer.toString('base64');
      const mime   = req.file.mimetype;
      logoUrl      = `data:${mime};base64,${base64}`;
      campos.push('logo_url = ?');
      valores.push(logoUrl);
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
    await pool.query(`UPDATE barbearias SET ${campos.join(', ')} WHERE id = ?`, valores);

    return res.json({
      mensagem: 'Identidade visual atualizada!',
      logo_url: logoUrl,
      cor_primaria,
    });
  } catch (err) {
    console.error('ERRO personalizar:', err.message);
    return res.status(500).json({ erro: 'Erro interno ao personalizar barbearia.' });
  }
}

async function atualizar(req, res) {
  const { id } = req.params;
  const { nome, telefone, email } = req.body;
  try {
    await pool.query(
      'UPDATE barbearias SET nome = ?, telefone = ?, email = ? WHERE id = ?',
      [nome, telefone || null, email || null, id]
    );
    return res.json({ mensagem: 'Barbearia atualizada!' });
  } catch (err) {
    return res.status(500).json({ erro: 'Erro interno.' });
  }
}

module.exports = { cadastrar, buscar, personalizar, atualizar };
    const [barbearia] = await pool.query(
      'SELECT id FROM barbearias WHERE id = ? AND admin_id = ?',
      [id, admin_id]
    );
    if (barbearia.length === 0) {
      return res.status(403).json({ erro: 'Barbearia não encontrada ou sem permissão.' });
    }

    await pool.query(
      `UPDATE barbearias SET nome = ?, descricao = ?, telefone = ?, endereco = ?
       WHERE id = ?`,
      [nome, descricao || null, telefone || null, endereco || null, id]
    );

    return res.json({ mensagem: 'Barbearia atualizada com sucesso!' });
  } catch (err) {
    return res.status(500).json({ erro: 'Erro interno ao atualizar barbearia.' });
  }
}

module.exports = { cadastrar, buscar, personalizar, atualizar };
