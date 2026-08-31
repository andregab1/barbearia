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

  if (Number.parseInt(id, 10) !== req.usuario.id) {
    return res.status(403).json({ code: 'PROFILE_FORBIDDEN', erro: 'Sem permissao para acessar este perfil.' });
  }

  try {
    const [rows] = await pool.query(
      `SELECT id, nome, email, username, telefone, data_nascimento, bio, role, foto_url, criado_em
         FROM usuarios WHERE id = ? AND ativo = 1`,
      [id]
    );
    if (rows.length === 0) return res.status(404).json({ erro: 'Usuário não encontrado.' });
    return res.json(rows[0]);
  } catch (err) {
    return res.status(500).json({ erro: 'Erro interno ao buscar usuário.' });
  }
}

async function alterarSenha(req, res) {
  const { senha_atual, nova_senha } = req.body;
  if (!senha_atual || !nova_senha) {
    return res.status(400).json({ code: 'PASSWORD_REQUIRED', erro: 'Informe a senha atual e a nova senha.' });
  }
  if (String(nova_senha).length < 8) {
    return res.status(400).json({ code: 'PASSWORD_TOO_SHORT', erro: 'A nova senha deve ter pelo menos 8 caracteres.' });
  }
  try {
    const [rows] = await pool.query('SELECT senha_hash FROM usuarios WHERE id = ? AND ativo = 1', [req.usuario.id]);
    if (rows.length === 0) return res.status(404).json({ erro: 'Usuario nao encontrado.' });
    const senhaOk = await bcrypt.compare(senha_atual, rows[0].senha_hash);
    if (!senhaOk) return res.status(400).json({ code: 'CURRENT_PASSWORD_INVALID', erro: 'Senha atual incorreta.' });
    const hash = await bcrypt.hash(nova_senha, 10);
    const connection = await pool.getConnection();
    try {
      await connection.beginTransaction();
      await connection.query('UPDATE usuarios SET senha_hash = ? WHERE id = ?', [hash, req.usuario.id]);
      await connection.query('DELETE FROM refresh_tokens WHERE usuario_id = ?', [req.usuario.id]);
      await connection.commit();
    } catch (error) {
      await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
    return res.json({ mensagem: 'Senha alterada com sucesso. Entre novamente.' });
  } catch (err) {
    console.error('ERRO ao alterar senha:', err.message);
    return res.status(500).json({ erro: 'Erro interno ao alterar senha.' });
  }
}

// ==========================================
// Atualizar perfil do usuário logado
// ==========================================
async function atualizar(req, res) {
  const { id }                              = req.params;
  const { nome, email, username, telefone, data_nascimento, bio, foto_url, senha_atual, nova_senha } = req.body;

  // Garante que só o próprio usuário pode editar
  if (parseInt(id) !== req.usuario.id) {
    return res.status(403).json({ erro: 'Sem permissão para editar este perfil.' });
  }

  try {
    const [rows] = await pool.query(
      'SELECT id, senha_hash, email, username, telefone FROM usuarios WHERE id = ? AND ativo = 1',
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

    if (email !== undefined) {
      const emailNormalizado = String(email || '').trim().toLowerCase();
      if (emailNormalizado && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(emailNormalizado)) {
        return res.status(400).json({ code: 'INVALID_EMAIL', erro: 'E-mail inválido.' });
      }
      if (emailNormalizado && emailNormalizado !== usuario.email) {
        const [existe] = await pool.query('SELECT id FROM usuarios WHERE email = ? AND id != ?', [emailNormalizado, id]);
        if (existe.length > 0) return res.status(409).json({ erro: 'E-mail já cadastrado.' });
      }
      campos.push('email = ?');
      valores.push(emailNormalizado || null);
    }

    if (username !== undefined) {
      const usernameNormalizado = String(username || '').trim().toLowerCase();
      if (usernameNormalizado && !/^[a-z0-9._]{3,30}$/.test(usernameNormalizado)) {
        return res.status(400).json({ code: 'INVALID_USERNAME', erro: 'Nome de usuário inválido.' });
      }
      if (usernameNormalizado && usernameNormalizado !== usuario.username) {
        const [existe] = await pool.query('SELECT id FROM usuarios WHERE username = ? AND id != ?', [usernameNormalizado, id]);
        if (existe.length > 0) return res.status(409).json({ erro: 'Nome de usuário já está em uso.' });
      }
      campos.push('username = ?');
      valores.push(usernameNormalizado || null);
    }

    if (data_nascimento !== undefined) {
      const nascimento = String(data_nascimento || '').trim();
      if (nascimento && !/^\d{4}-\d{2}-\d{2}$/.test(nascimento)) {
        return res.status(400).json({ code: 'INVALID_BIRTH_DATE', erro: 'Data de nascimento inválida.' });
      }
      campos.push('data_nascimento = ?');
      valores.push(nascimento || null);
    }

    if (bio !== undefined) {
      const descricao = String(bio || '').trim();
      if (descricao.length > 280) return res.status(400).json({ code: 'BIO_TOO_LONG', erro: 'A bio deve ter no máximo 280 caracteres.' });
      campos.push('bio = ?');
      valores.push(descricao || null);
    }

    if (foto_url !== undefined) {
      const foto = String(foto_url || '').trim();
      if (foto && !/^data:image\/(png|jpe?g|webp);base64,/i.test(foto)) {
        return res.status(400).json({ code: 'INVALID_PROFILE_IMAGE', erro: 'Formato de imagem invalido.' });
      }
      if (foto.length > 2_800_000) {
        return res.status(413).json({ code: 'PROFILE_IMAGE_TOO_LARGE', erro: 'A imagem deve ter no maximo 2 MB.' });
      }
      campos.push('foto_url = ?');
      valores.push(foto || null);
    }

    // Altera senha se fornecida
    if (nova_senha && senha_atual) {
      const senhaOk = await bcrypt.compare(senha_atual, usuario.senha_hash);
      if (!senhaOk) {
        return res.status(400).json({ erro: 'Senha atual incorreta.' });
      }
      if (nova_senha.length < 8) {
        return res.status(400).json({ erro: 'Nova senha deve ter pelo menos 8 caracteres.' });
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

    const [atualizado] = await pool.query(
      `SELECT id, nome, email, username, telefone, data_nascimento, bio, role, foto_url, criado_em
         FROM usuarios WHERE id = ?`,
      [id],
    );
    return res.json({ mensagem: 'Perfil atualizado com sucesso!', usuario: atualizado[0] });
  } catch (err) {
    console.error('ERRO ao atualizar usuário:', err.message);
    return res.status(500).json({ erro: 'Erro interno ao atualizar perfil.' });
  }
}

module.exports = { buscar, atualizar, alterarSenha };
