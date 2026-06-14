// ==========================================
// CONTROLLER: Colaboradores
// RF14 - Gestão Multiusuário
// ==========================================
const bcrypt   = require('bcryptjs');
const { pool } = require('../config/database');

// ==========================================
// RF14: Listar colaboradores da barbearia
// ==========================================
async function listar(req, res) {
  const { barbearia_id } = req.params;

  try {
    const [rows] = await pool.query(
      `SELECT c.id, u.nome, u.email, u.telefone, c.ativo
       FROM colaboradores c
       JOIN usuarios u ON u.id = c.usuario_id
       WHERE c.barbearia_id = ? AND c.ativo = 1 AND u.ativo = 1
       ORDER BY u.nome ASC`,
      [barbearia_id]
    );
    return res.json(rows);
  } catch (err) {
    return res.status(500).json({ erro: 'Erro interno ao listar colaboradores.' });
  }
}

// ==========================================
// RF14: Cadastrar novo colaborador
// ==========================================
async function cadastrar(req, res) {
  const { barbearia_id }                = req.params;
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
    const [usuario] = await pool.query(
      'INSERT INTO usuarios (nome, email, telefone, senha_hash, role) VALUES (?, ?, ?, ?, ?)',
      [nome, email || null, telefone, hash, 'barbeiro']
    );

    await pool.query(
      'INSERT INTO colaboradores (barbearia_id, usuario_id) VALUES (?, ?)',
      [barbearia_id, usuario.insertId]
    );

    return res.status(201).json({ mensagem: 'Colaborador cadastrado!', id: usuario.insertId });
  } catch (err) {
    return res.status(500).json({ erro: 'Erro interno ao cadastrar colaborador.' });
  }
}

// ==========================================
// RF14: Ativar ou desativar colaborador
// ==========================================
async function alterarStatus(req, res) {
  const { id }    = req.params;
  const { ativo } = req.body;

  if (ativo === undefined) {
    return res.status(400).json({ erro: 'Campo ativo é obrigatório.' });
  }

  try {
    const [colab] = await pool.query('SELECT id FROM colaboradores WHERE id = ?', [id]);
    if (colab.length === 0) return res.status(404).json({ erro: 'Colaborador não encontrado.' });

    await pool.query('UPDATE colaboradores SET ativo = ? WHERE id = ?', [ativo ? 1 : 0, id]);
    return res.json({ mensagem: `Colaborador ${ativo ? 'ativado' : 'desativado'}!` });
  } catch (err) {
    return res.status(500).json({ erro: 'Erro interno ao alterar status.' });
  }
}

// ==========================================
// RF14: Remover colaborador (soft delete)
// ==========================================
async function remover(req, res) {
  const { id } = req.params;

  try {
    const [colab] = await pool.query(
      'SELECT c.id, c.usuario_id FROM colaboradores c WHERE c.id = ?', [id]
    );
    if (colab.length === 0) return res.status(404).json({ erro: 'Colaborador não encontrado.' });

    // Verifica agendamentos futuros confirmados
    const [agendamentos] = await pool.query(
      `SELECT id FROM agendamentos
       WHERE colaborador_id = ? AND status = 'confirmado' AND data_hora > NOW()`,
      [id]
    );
    if (agendamentos.length > 0) {
      return res.status(409).json({
        erro: `Não é possível excluir. Existem ${agendamentos.length} agendamento(s) futuro(s) confirmado(s).`
      });
    }

    // Soft delete: desativa colaborador e usuário
    await pool.query('UPDATE colaboradores SET ativo = 0 WHERE id = ?', [id]);
    await pool.query('UPDATE usuarios SET ativo = 0 WHERE id = ?', [colab[0].usuario_id]);

    return res.json({ mensagem: 'Colaborador removido com sucesso!' });
  } catch (err) {
    console.error('ERRO ao remover colaborador:', err.message);
    return res.status(500).json({ erro: 'Erro interno ao remover colaborador.' });
  }
}

// ==========================================
// RF03: Buscar colaborador pelo usuario_id
// ==========================================
async function buscarPorUsuario(req, res) {
  const { usuario_id } = req.params;

  try {
    const [rows] = await pool.query(
      'SELECT id FROM colaboradores WHERE usuario_id = ? AND ativo = 1 LIMIT 1',
      [usuario_id]
    );
    if (rows.length === 0) return res.status(404).json({ erro: 'Colaborador não encontrado.' });
    return res.json({ id: rows[0].id });
  } catch (err) {
    return res.status(500).json({ erro: 'Erro interno.' });
  }
}

module.exports = { listar, cadastrar, alterarStatus, remover, buscarPorUsuario };