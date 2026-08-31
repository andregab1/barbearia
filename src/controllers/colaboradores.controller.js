// ==========================================
// CONTROLLER: Colaboradores
// RF14 - Gestão Multiusuário
// ==========================================
const bcrypt   = require('bcryptjs');
const { pool } = require('../config/database');
const { obterBarbeariaAdministrada, obterColaboradorAcessivel } = require('../utils/access');

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

// Lista administrativa, incluindo profissionais inativos.
async function listarGerenciamento(req, res) {
  const { barbearia_id } = req.params;
  try {
    const barbearia = await obterBarbeariaAdministrada(req.usuario.id, barbearia_id);
    if (!barbearia) return res.status(403).json({ code: 'TENANT_FORBIDDEN', erro: 'Sem permissão para gerenciar esta barbearia.' });
    const [rows] = await pool.query(
      `SELECT c.id, c.usuario_id, u.nome, u.email, u.telefone, c.ativo
       FROM colaboradores c
       JOIN usuarios u ON u.id = c.usuario_id
       WHERE c.barbearia_id = ?
       ORDER BY c.ativo DESC, u.nome ASC`,
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
  const { barbearia_id }     = req.params;
  const { nome, telefone, senha } = req.body;

  if (!nome || !telefone || !senha) {
    return res.status(400).json({ erro: 'Nome, telefone e senha são obrigatórios.' });
  }

  try {
    const barbearia = await obterBarbeariaAdministrada(req.usuario.id, barbearia_id);
    if (!barbearia) return res.status(403).json({ code: 'TENANT_FORBIDDEN', erro: 'Sem permissão para gerenciar esta barbearia.' });
    // Verificar se já existe usuário com esse telefone nesta barbearia
    const [existente] = await pool.query(
      `SELECT u.id, c.id AS colab_id, c.ativo AS colab_ativo
       FROM usuarios u
       LEFT JOIN colaboradores c ON c.usuario_id = u.id AND c.barbearia_id = ?
       WHERE u.telefone = ?`,
      [barbearia_id, telefone]
    );

    if (existente.length > 0) {
      const u = existente[0];

      // Colaborador ativo → bloquear
      if (u.colab_ativo === 1) {
        return res.status(409).json({ erro: 'Telefone já cadastrado como colaborador ativo.' });
      }

      // Colaborador existente mas inativo → reativar e atualizar dados
      if (u.colab_id) {
        const hash = await bcrypt.hash(senha, 10);
        await pool.query(
          'UPDATE usuarios SET nome = ?, senha_hash = ?, ativo = 1 WHERE id = ?',
          [nome, hash, u.id]
        );
        await pool.query(
          'UPDATE colaboradores SET ativo = 1 WHERE id = ?',
          [u.colab_id]
        );
        return res.status(201).json({ mensagem: 'Colaborador reativado!', id: u.id });
      }

      // Usuário já existe, mas ainda não é colaborador desta barbearia →
      // reutiliza o usuário e cria apenas o vínculo (evita erro de telefone duplicado)
      const hash = await bcrypt.hash(senha, 10);
      await pool.query(
        'UPDATE usuarios SET nome = ?, senha_hash = ?, ativo = 1, role = ? WHERE id = ?',
        [nome, hash, 'barbeiro', u.id]
      );
      await pool.query(
        'INSERT INTO colaboradores (barbearia_id, usuario_id) VALUES (?, ?)',
        [barbearia_id, u.id]
      );
      return res.status(201).json({ mensagem: 'Colaborador cadastrado!', id: u.id });
    }

    // Novo colaborador — criar usuário e vínculo
    const hash = await bcrypt.hash(senha, 10);
    const [usuario] = await pool.query(
      'INSERT INTO usuarios (nome, telefone, senha_hash, role) VALUES (?, ?, ?, ?)',
      [nome, telefone, hash, 'barbeiro']
    );
    await pool.query(
      'INSERT INTO colaboradores (barbearia_id, usuario_id) VALUES (?, ?)',
      [barbearia_id, usuario.insertId]
    );

    return res.status(201).json({ mensagem: 'Colaborador cadastrado!', id: usuario.insertId });
  } catch (err) {
    console.error('ERRO cadastrar colaborador:', err.message);
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
    const acesso = await obterColaboradorAcessivel(req.usuario, id);
    if (!acesso) return res.status(403).json({ code: 'COLLABORATOR_FORBIDDEN', erro: 'Sem permissão para alterar este colaborador.' });
    const [colab] = await pool.query('SELECT id FROM colaboradores WHERE id = ?', [id]);
    if (colab.length === 0) return res.status(404).json({ erro: 'Colaborador não encontrado.' });

    await pool.query('UPDATE colaboradores SET ativo = ? WHERE id = ?', [ativo ? 1 : 0, id]);
    return res.json({ mensagem: `Colaborador ${ativo ? 'ativado' : 'desativado'}!` });
  } catch (err) {
    return res.status(500).json({ erro: 'Erro interno ao alterar status.' });
  }
}

async function atualizar(req, res) {
  const { id } = req.params;
  const nome = String(req.body.nome || '').trim();
  const telefone = String(req.body.telefone || '').trim();
  const email = req.body.email == null ? null : String(req.body.email).trim().toLowerCase();

  if (nome.length < 2 || telefone.length < 8) {
    return res.status(400).json({ erro: 'Informe nome e telefone válidos.' });
  }

  try {
    const acesso = await obterColaboradorAcessivel(req.usuario, id);
    if (!acesso) return res.status(403).json({ code: 'COLLABORATOR_FORBIDDEN', erro: 'Sem permissão para editar este colaborador.' });
    const [rows] = await pool.query('SELECT usuario_id FROM colaboradores WHERE id = ?', [id]);
    if (rows.length === 0) return res.status(404).json({ erro: 'Colaborador não encontrado.' });
    await pool.query(
      'UPDATE usuarios SET nome = ?, telefone = ?, email = ? WHERE id = ?',
      [nome, telefone, email || null, rows[0].usuario_id]
    );
    return res.json({ mensagem: 'Colaborador atualizado com sucesso.' });
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY') return res.status(409).json({ erro: 'Telefone ou e-mail já utilizado por outra conta.' });
    return res.status(500).json({ erro: 'Erro interno ao atualizar colaborador.' });
  }
}

// ==========================================
// RF14: Remover colaborador (soft delete)
// ==========================================
async function remover(req, res) {
  const { id } = req.params;

  try {
    const acesso = await obterColaboradorAcessivel(req.usuario, id);
    if (!acesso) return res.status(403).json({ code: 'COLLABORATOR_FORBIDDEN', erro: 'Sem permissão para remover este colaborador.' });
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
    const connection = await pool.getConnection();
    try {
      await connection.beginTransaction();
      await connection.query('UPDATE colaboradores SET ativo = 0 WHERE id = ?', [id]);
      await connection.query('UPDATE usuarios SET ativo = 0 WHERE id = ?', [colab[0].usuario_id]);
      await connection.query('DELETE FROM refresh_tokens WHERE usuario_id = ?', [colab[0].usuario_id]);
      await connection.commit();
    } catch (error) {
      await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }

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

  if (req.usuario.role !== 'admin' && Number.parseInt(usuario_id, 10) !== req.usuario.id) {
    return res.status(403).json({ code: 'COLLABORATOR_FORBIDDEN', erro: 'Sem permissão para consultar este colaborador.' });
  }

  try {
    const [rows] = await pool.query(
      'SELECT id FROM colaboradores WHERE usuario_id = ? AND ativo = 1 LIMIT 1',
      [usuario_id]
    );
    if (rows.length === 0) return res.status(404).json({ erro: 'Colaborador não encontrado.' });
    if (req.usuario.role === 'admin') {
      const acesso = await obterColaboradorAcessivel(req.usuario, rows[0].id);
      if (!acesso) return res.status(403).json({ code: 'COLLABORATOR_FORBIDDEN', erro: 'Sem permissão para consultar este colaborador.' });
    }
    return res.json({ id: rows[0].id });
  } catch (err) {
    return res.status(500).json({ erro: 'Erro interno.' });
  }
}

module.exports = { listar, listarGerenciamento, cadastrar, atualizar, alterarStatus, remover, buscarPorUsuario };
