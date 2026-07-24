// ==========================================
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
  const { cor_primaria, cor_secundaria, logo_base64 } = req.body;

  try {
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