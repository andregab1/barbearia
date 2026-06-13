// ==========================================
// CONTROLLER: Serviços e Preços
// RF12 - Gestão de Serviços e Preços
// ==========================================
const { pool } = require('../config/database');

// ==========================================
// RF12: Listar serviços da barbearia
// ==========================================
async function listar(req, res) {
  const { barbearia_id } = req.params;

  try {
    const [rows] = await pool.query(
      `SELECT id, nome, descricao, preco, duracao_min, ativo
       FROM servicos
       WHERE barbearia_id = ? AND ativo = 1
       ORDER BY nome ASC`,
      [barbearia_id]
    );
    return res.json(rows);
  } catch (err) {
    return res.status(500).json({ erro: 'Erro interno ao listar serviços.' });
  }
}

// ==========================================
// RF12: Criar novo serviço
// ==========================================
async function criar(req, res) {
  const { barbearia_id }                    = req.params;
  const { nome, descricao, preco, duracao_min } = req.body;

  if (!nome || !preco || !duracao_min) {
    return res.status(400).json({ erro: 'Nome, preço e duração são obrigatórios.' });
  }
  if (preco <= 0) {
    return res.status(400).json({ erro: 'Preço deve ser maior que zero.' });
  }

  try {
    const [result] = await pool.query(
      `INSERT INTO servicos (barbearia_id, nome, descricao, preco, duracao_min)
       VALUES (?, ?, ?, ?, ?)`,
      [barbearia_id, nome, descricao || null, preco, duracao_min]
    );
    return res.status(201).json({ mensagem: 'Serviço criado com sucesso!', id: result.insertId });
  } catch (err) {
    return res.status(500).json({ erro: 'Erro interno ao criar serviço.' });
  }
}

// ==========================================
// RF12: Atualizar serviço existente
// ==========================================
async function atualizar(req, res) {
  const { id }                                  = req.params;
  const { nome, descricao, preco, duracao_min } = req.body;

  if (preco !== undefined && preco <= 0) {
    return res.status(400).json({ erro: 'Preço deve ser maior que zero.' });
  }

  try {
    const [servico] = await pool.query('SELECT id FROM servicos WHERE id = ?', [id]);
    if (servico.length === 0) return res.status(404).json({ erro: 'Serviço não encontrado.' });

    await pool.query(
      `UPDATE servicos SET nome = ?, descricao = ?, preco = ?, duracao_min = ?
       WHERE id = ?`,
      [nome, descricao || null, preco, duracao_min, id]
    );
    return res.json({ mensagem: 'Serviço atualizado com sucesso!' });
  } catch (err) {
    return res.status(500).json({ erro: 'Erro interno ao atualizar serviço.' });
  }
}

// ==========================================
// RF12: Desativar serviço (soft delete)
// ==========================================
async function desativar(req, res) {
  const { id } = req.params;

  try {
    const [servico] = await pool.query('SELECT id FROM servicos WHERE id = ?', [id]);
    if (servico.length === 0) return res.status(404).json({ erro: 'Serviço não encontrado.' });

    await pool.query('UPDATE servicos SET ativo = 0 WHERE id = ?', [id]);
    return res.json({ mensagem: 'Serviço desativado com sucesso!' });
  } catch (err) {
    return res.status(500).json({ erro: 'Erro interno ao desativar serviço.' });
  }
}

module.exports = { listar, criar, atualizar, desativar };