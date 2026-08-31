// ==========================================
// CONTROLLER: Serviços e Preços
// RF12 - Gestão de Serviços e Preços
// ==========================================
const { pool } = require('../config/database');
const { obterBarbeariaAdministrada, obterServicoAdministravel } = require('../utils/access');

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

  const nomeNormalizado = typeof nome === 'string' ? nome.trim() : '';
  const descricaoNormalizada = descricao == null
    ? null
    : typeof descricao === 'string' ? descricao.trim() || null : undefined;
  const precoNormalizado = typeof preco === 'number' || typeof preco === 'string'
    ? Number(preco) : Number.NaN;
  const duracaoNormalizada = typeof duracao_min === 'number' || typeof duracao_min === 'string'
    ? Number(duracao_min) : Number.NaN;
  const nomeValido = /^[\p{L}\p{N}][\p{L}\p{N}\s&+.,()/-]{1,99}$/u.test(nomeNormalizado);
  if (!nomeValido || descricaoNormalizada === undefined ||
      (descricaoNormalizada && descricaoNormalizada.length > 500) ||
      !Number.isFinite(precoNormalizado) || precoNormalizado <= 0 || precoNormalizado > 99999999 ||
      !Number.isInteger(duracaoNormalizada) || duracaoNormalizada < 5 || duracaoNormalizada > 1440) {
    return res.status(400).json({ code: 'INVALID_SERVICE', erro: 'Informe nome, preço e duração válidos.' });
  }

  try {
    const barbearia = await obterBarbeariaAdministrada(req.usuario.id, barbearia_id);
    if (!barbearia) return res.status(403).json({ code: 'TENANT_FORBIDDEN', erro: 'Sem permissão para gerenciar esta barbearia.' });
    const [result] = await pool.query(
      `INSERT INTO servicos (barbearia_id, nome, descricao, preco, duracao_min)
       VALUES (?, ?, ?, ?, ?)`,
      [barbearia_id, nomeNormalizado, descricaoNormalizada, precoNormalizado, duracaoNormalizada]
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

  if (nome !== undefined && (typeof nome !== 'string' || !/^[\p{L}\p{N}][\p{L}\p{N}\s&+.,()/-]{1,99}$/u.test(nome.trim()))) {
    return res.status(400).json({ code: 'INVALID_SERVICE_NAME', erro: 'Nome de serviço inválido.' });
  }
  if (descricao !== undefined && descricao !== null && (typeof descricao !== 'string' || descricao.length > 500)) {
    return res.status(400).json({ code: 'INVALID_SERVICE_DESCRIPTION', erro: 'Descrição inválida.' });
  }
  if (preco !== undefined && (!['number', 'string'].includes(typeof preco) || !Number.isFinite(Number(preco)) || Number(preco) <= 0 || Number(preco) > 99999999)) {
    return res.status(400).json({ code: 'INVALID_SERVICE_PRICE', erro: 'Preço deve ser maior que zero.' });
  }
  if (duracao_min !== undefined && (!['number', 'string'].includes(typeof duracao_min) || !Number.isInteger(Number(duracao_min)) || Number(duracao_min) < 5 || Number(duracao_min) > 1440)) {
    return res.status(400).json({ code: 'INVALID_SERVICE_DURATION', erro: 'Duração inválida.' });
  }

  try {
    const acesso = await obterServicoAdministravel(req.usuario.id, id);
    if (!acesso) return res.status(403).json({ code: 'SERVICE_FORBIDDEN', erro: 'Sem permissão para alterar este serviço.' });
    const [servico] = await pool.query('SELECT id FROM servicos WHERE id = ?', [id]);
    if (servico.length === 0) return res.status(404).json({ erro: 'Serviço não encontrado.' });

    // Atualiza apenas os campos fornecidos (evita gravar NULL em colunas NOT NULL)
    const sets   = [];
    const params = [];
    if (nome !== undefined)        { sets.push('nome = ?');        params.push(nome.trim()); }
    if (descricao !== undefined)   { sets.push('descricao = ?');   params.push(descricao?.trim() || null); }
    if (preco !== undefined)       { sets.push('preco = ?');       params.push(Number(preco)); }
    if (duracao_min !== undefined) { sets.push('duracao_min = ?'); params.push(Number(duracao_min)); }

    if (sets.length === 0) {
      return res.status(400).json({ erro: 'Nenhum campo para atualizar.' });
    }

    params.push(id);
    await pool.query(`UPDATE servicos SET ${sets.join(', ')} WHERE id = ?`, params);
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
    const acesso = await obterServicoAdministravel(req.usuario.id, id);
    if (!acesso) return res.status(403).json({ code: 'SERVICE_FORBIDDEN', erro: 'Sem permissão para desativar este serviço.' });
    const [servico] = await pool.query('SELECT id FROM servicos WHERE id = ?', [id]);
    if (servico.length === 0) return res.status(404).json({ erro: 'Serviço não encontrado.' });

    await pool.query('UPDATE servicos SET ativo = 0 WHERE id = ?', [id]);
    return res.json({ mensagem: 'Serviço desativado com sucesso!' });
  } catch (err) {
    return res.status(500).json({ erro: 'Erro interno ao desativar serviço.' });
  }
}

module.exports = { listar, criar, atualizar, desativar };
