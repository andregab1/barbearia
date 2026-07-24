// ==========================================
// CONTROLLER: Usuários
// Editar perfil e alterar senha
// ==========================================
const bcrypt   = require('bcryptjs');
const { pool } = require('../config/database');

// ==========================================
// Buscar dados do usuário logado
// ==========================================
async function buscar(req, res) {
  const { id } = req.params;

  try {
    const [rows] = await pool.query(
      'SELECT id, nome, email, telefone, role FROM usuarios WHERE id = ? AND ativo = 1',
      [id]
    );
    if (rows.length === 0) return res.status(404).json({ erro: 'Usuário não encontrado.' });
    return res.json(rows[0]);
  } catch (err) {
    return res.status(500).json({ erro: 'Erro interno ao buscar usuário.' });
  }
}

// ==========================================
// Atualizar perfil do usuário logado
// ==========================================
async function atualizar(req, res) {
  const { id }                              = req.params;
  const { nome, telefone, senha_atual, nova_senha } = req.body;

  // Garante que só o próprio usuário pode editar
  if (parseInt(id) !== req.usuario.id) {
    return res.status(403).json({ erro: 'Sem permissão para editar este perfil.' });
  }

  try {
    const [rows] = await pool.query(
      'SELECT id, senha_hash, telefone FROM usuarios WHERE id = ? AND ativo = 1',
      [id]
    );
    if (rows.length === 0) return res.status(404).json({ erro: 'Usuário não encontrado.' });

    const usuario = rows[0];
    const campos  = [];
    const valores = [];

    // Atualiza nome
    if (nome && nome.trim()) {
      campos.push('nome = ?');
      valores.push(nome.trim());
    }

    // Atualiza telefone (verifica duplicidade)
    if (telefone && telefone.trim() && telefone.trim() !== usuario.telefone) {
      const [existe] = await pool.query(
        'SELECT id FROM usuarios WHERE telefone = ? AND id != ?',
        [telefone.trim(), id]
      );
      if (existe.length > 0) {
        return res.status(409).json({ erro: 'Telefone já cadastrado por outro usuário.' });
      }
      campos.push('telefone = ?');
      valores.push(telefone.trim());
    }

    // Altera senha se fornecida
    if (nova_senha && senha_atual) {
      const senhaOk = await bcrypt.compare(senha_atual, usuario.senha_hash);
      if (!senhaOk) {
        return res.status(400).json({ erro: 'Senha atual incorreta.' });
      }
      if (nova_senha.length < 6) {
        return res.status(400).json({ erro: 'Nova senha deve ter pelo menos 6 caracteres.' });
      }
      const hash = await bcrypt.hash(nova_senha, 10);
      campos.push('senha_hash = ?');
      valores.push(hash);
    }

    if (campos.length === 0) {
      return res.status(400).json({ erro: 'Nenhum dado para atualizar.' });
    }

    valores.push(id);
    await pool.query(`UPDATE usuarios SET ${campos.join(', ')} WHERE id = ?`, valores);

    return res.json({ mensagem: 'Perfil atualizado com sucesso!' });
  } catch (err) {
    console.error('ERRO ao atualizar usuário:', err.message);
    return res.status(500).json({ erro: 'Erro interno ao atualizar perfil.' });
  }
}

module.exports = { buscar, atualizar };