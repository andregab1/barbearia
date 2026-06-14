// ==========================================
// CONTROLLER: Agendamentos
// RF06 - Agendar | RF07 - Cancelar | RF11 - Bloquear
// ==========================================
const { pool } = require('../config/database');

// ==========================================
// RF06: Criar novo agendamento
// ==========================================
async function criar(req, res) {
  const { colaborador_id, servico_id, data_hora, observacao, duracao_override, valor_override } = req.body;
  const cliente_id = req.usuario.id;

  if (!colaborador_id || !servico_id || !data_hora) {
    return res.status(400).json({ erro: 'Colaborador, serviço e data/hora são obrigatórios.' });
  }

  try {
    const [servico] = await pool.query(
      'SELECT preco, duracao_min FROM servicos WHERE id = ? AND ativo = 1',
      [servico_id]
    );
    if (servico.length === 0) return res.status(404).json({ erro: 'Serviço não encontrado.' });

    const { preco, duracao_min } = servico[0];

    // Suporta duração e valor customizados (múltiplos serviços)
    const duracaoFinal = duracao_override ? parseInt(duracao_override) : duracao_min;
    const valorFinal   = valor_override   ? parseFloat(valor_override) : preco;

    // Usa string diretamente para evitar conversão de timezone pelo mysql2
    const dataHoraStr = data_hora.replace('T', ' ').substring(0, 19);
    const dataInicio  = new Date(data_hora.replace(' ', 'T'));
    const dataFimStr  = (() => {
      const d = new Date(dataInicio.getTime() + duracaoFinal * 60000);
      const pad = n => String(n).padStart(2, '0');
      return `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`;
    })();

    const [conflito] = await pool.query(
      `SELECT id FROM agendamentos
       WHERE colaborador_id = ?
         AND status IN ('confirmado', 'pendente')
         AND data_hora < ? AND DATE_ADD(data_hora, INTERVAL duracao_min MINUTE) > ?`,
      [colaborador_id, dataFimStr, dataHoraStr]
    );
    if (conflito.length > 0) {
      return res.status(409).json({ erro: 'Horário indisponível. Escolha outro horário.' });
    }

    const [bloqueio] = await pool.query(
      `SELECT id FROM horarios_bloqueados
       WHERE colaborador_id = ?
         AND data_hora_ini < ? AND data_hora_fim > ?`,
      [colaborador_id, dataFimStr, dataHoraStr]
    );
    if (bloqueio.length > 0) {
      return res.status(409).json({ erro: 'Horário bloqueado pelo profissional.' });
    }

    const [result] = await pool.query(
      `INSERT INTO agendamentos
         (cliente_id, colaborador_id, servico_id, data_hora, duracao_min, valor_cobrado, observacao)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [cliente_id, colaborador_id, servico_id, dataHoraStr, duracaoFinal, valorFinal, observacao || null]
    );

    await pool.query(
      `INSERT INTO notificacoes (usuario_id, agendamento_id, tipo, titulo, mensagem, agendada_para)
       VALUES (?, ?, 'confirmacao', 'Agendamento confirmado!',
               'Seu horário foi reservado com sucesso.', NOW())`,
      [cliente_id, result.insertId]
    );

    const lembrete = new Date(dataInicio.getTime() - 2 * 60 * 60 * 1000);
    if (lembrete > new Date()) {
      await pool.query(
        `INSERT INTO notificacoes (usuario_id, agendamento_id, tipo, titulo, mensagem, agendada_para)
         VALUES (?, ?, 'lembrete', 'Lembrete de agendamento',
                 'Você tem um horário marcado em 2 horas!', ?)`,
        [cliente_id, result.insertId, lembrete]
      );
    }

    return res.status(201).json({ mensagem: 'Agendamento realizado com sucesso!', id: result.insertId });
  } catch (err) {
    console.error('ERRO ao criar agendamento:', err.message);
    return res.status(500).json({ erro: 'Erro interno ao criar agendamento.' });
  }
}

// ==========================================
// RF06: Listar agendamentos do cliente
// tipo=agenda → confirmados futuros
// tipo=historico → concluidos e cancelados
// ==========================================
async function listarCliente(req, res) {
  const cliente_id = req.usuario.id;
  const { tipo }   = req.query;

  try {
    let query = `
      SELECT a.id, a.data_hora, a.status, a.valor_cobrado, a.observacao, a.duracao_min,
             s.nome AS servico,
             u.nome AS barbeiro
      FROM agendamentos a
      JOIN servicos s      ON s.id = a.servico_id
      JOIN colaboradores c ON c.id = a.colaborador_id
      JOIN usuarios u      ON u.id = c.usuario_id
      WHERE a.cliente_id = ?`;

    if (tipo === 'agenda') {
      query += ` AND a.status = 'confirmado'
                 AND a.data_hora >= NOW()
                 ORDER BY a.data_hora ASC`;
    } else if (tipo === 'historico') {
      query += ` AND a.status IN ('concluido', 'cancelado')
                 ORDER BY a.data_hora DESC`;
    } else {
      query += ' ORDER BY a.data_hora DESC';
    }

    const [rows] = await pool.query(query, [cliente_id]);
    return res.json(rows);
  } catch (err) {
    return res.status(500).json({ erro: 'Erro interno ao listar agendamentos.' });
  }
}

// ==========================================
// RF05: Listar agendamentos futuros do barbeiro
// Sem data = todos os próximos 30 dias
// ==========================================
async function listarBarbeiro(req, res) {
  const { colaborador_id } = req.params;
  const { data }           = req.query;

  try {
    let query = `
      SELECT a.id, a.data_hora, a.status, a.valor_cobrado, a.duracao_min,
             s.nome AS servico,
             u.nome AS cliente, u.telefone AS cliente_telefone
      FROM agendamentos a
      JOIN servicos s ON s.id = a.servico_id
      JOIN usuarios u ON u.id = a.cliente_id
      WHERE a.colaborador_id = ?`;

    const params = [colaborador_id];

    if (data) {
      // Filtro por dia específico
      query += ' AND DATE(a.data_hora) = ?';
      params.push(data);
    } else {
      // Sem filtro: próximos 30 dias a partir de hoje
      query += ' AND a.data_hora >= CURDATE() AND a.data_hora < DATE_ADD(CURDATE(), INTERVAL 30 DAY)';
      query += ' AND a.status IN (\'confirmado\', \'pendente\')';
    }

    query += ' ORDER BY a.data_hora ASC';

    const [rows] = await pool.query(query, params);
    return res.json(rows);
  } catch (err) {
    console.error('ERRO ao listar agenda:', err.message);
    return res.status(500).json({ erro: 'Erro interno ao listar agenda.' });
  }
}

// ==========================================
// RF07: Cancelar agendamento
// ==========================================
async function cancelar(req, res) {
  const { id }  = req.params;
  const usuario = req.usuario;

  try {
    const [agendamento] = await pool.query(
      'SELECT id, cliente_id, colaborador_id, data_hora, status FROM agendamentos WHERE id = ?',
      [id]
    );
    if (agendamento.length === 0) return res.status(404).json({ erro: 'Agendamento não encontrado.' });

    const ag = agendamento[0];

    if (ag.status === 'cancelado') return res.status(400).json({ erro: 'Agendamento já foi cancelado.' });
    if (ag.status === 'concluido') return res.status(400).json({ erro: 'Não é possível cancelar um agendamento concluído.' });

    const agora     = new Date();
    const dataAgend = new Date(ag.data_hora);
    const diffHoras = (dataAgend - agora) / (1000 * 60 * 60);

    if (usuario.role === 'cliente' && diffHoras < 1) {
      return res.status(400).json({ erro: 'Cancelamento não permitido com menos de 1 hora de antecedência.' });
    }

    if (usuario.role === 'cliente' && ag.cliente_id !== usuario.id) {
      return res.status(403).json({ erro: 'Sem permissão para cancelar este agendamento.' });
    }

    await pool.query('UPDATE agendamentos SET status = ? WHERE id = ?', ['cancelado', id]);

    await pool.query(
      `INSERT INTO notificacoes (usuario_id, agendamento_id, tipo, titulo, mensagem, agendada_para)
       VALUES (?, ?, 'cancelamento', 'Agendamento cancelado',
               'Seu agendamento foi cancelado.', NOW())`,
      [ag.cliente_id, id]
    );

    return res.json({ mensagem: 'Agendamento cancelado com sucesso!' });
  } catch (err) {
    console.error('ERRO ao cancelar:', err.message);
    return res.status(500).json({ erro: 'Erro interno ao cancelar agendamento.' });
  }
}

// ==========================================
// RF03: Marcar agendamento como concluído
// ==========================================
async function concluir(req, res) {
  const { id } = req.params;

  try {
    const [agendamento] = await pool.query(
      'SELECT id, status FROM agendamentos WHERE id = ?', [id]
    );
    if (agendamento.length === 0) return res.status(404).json({ erro: 'Agendamento não encontrado.' });
    if (agendamento[0].status !== 'confirmado') {
      return res.status(400).json({ erro: 'Apenas agendamentos confirmados podem ser concluídos.' });
    }

    await pool.query('UPDATE agendamentos SET status = ? WHERE id = ?', ['concluido', id]);
    return res.json({ mensagem: 'Agendamento concluído com sucesso!' });
  } catch (err) {
    return res.status(500).json({ erro: 'Erro interno ao concluir agendamento.' });
  }
}

// ==========================================
// RF11: Bloquear horário na agenda
// ==========================================
async function bloquearHorario(req, res) {
  const { colaborador_id, data_hora_ini, data_hora_fim, motivo } = req.body;

  if (!colaborador_id || !data_hora_ini || !data_hora_fim) {
    return res.status(400).json({ erro: 'Colaborador, início e fim são obrigatórios.' });
  }

  try {
    const [agendamentos] = await pool.query(
      `SELECT id FROM agendamentos
       WHERE colaborador_id = ?
         AND status IN ('confirmado', 'pendente')
         AND data_hora < ? AND DATE_ADD(data_hora, INTERVAL duracao_min MINUTE) > ?`,
      [colaborador_id, data_hora_fim, data_hora_ini]
    );
    if (agendamentos.length > 0) {
      return res.status(409).json({
        erro: 'Existem agendamentos neste período. Cancele-os antes de bloquear.'
      });
    }

    const [result] = await pool.query(
      'INSERT INTO horarios_bloqueados (colaborador_id, data_hora_ini, data_hora_fim, motivo) VALUES (?, ?, ?, ?)',
      [colaborador_id, data_hora_ini, data_hora_fim, motivo || null]
    );

    return res.status(201).json({ mensagem: 'Horário bloqueado com sucesso!', id: result.insertId });
  } catch (err) {
    return res.status(500).json({ erro: 'Erro interno ao bloquear horário.' });
  }
}

// ==========================================
// RF11: Listar bloqueios do colaborador
// ==========================================
async function listarBloqueios(req, res) {
  const { colaborador_id } = req.params;
  const { data_ini, data_fim } = req.query;

  try {
    let query = `SELECT id, data_hora_ini, data_hora_fim, motivo
                 FROM horarios_bloqueados
                 WHERE colaborador_id = ?`;
    const params = [colaborador_id];

    if (data_ini) { query += ' AND DATE(data_hora_ini) >= ?'; params.push(data_ini); }
    if (data_fim) { query += ' AND DATE(data_hora_ini) <= ?'; params.push(data_fim); }

    query += ' ORDER BY data_hora_ini ASC';

    const [rows] = await pool.query(query, params);
    return res.json(rows);
  } catch (err) {
    return res.status(500).json({ erro: 'Erro interno ao listar bloqueios.' });
  }
}

// ==========================================
// RF11: Remover bloqueio de horário
// ==========================================
async function removerBloqueio(req, res) {
  const { id } = req.params;

  try {
    const [bloqueio] = await pool.query(
      'SELECT id FROM horarios_bloqueados WHERE id = ?', [id]
    );
    if (bloqueio.length === 0) return res.status(404).json({ erro: 'Bloqueio não encontrado.' });

    await pool.query('DELETE FROM horarios_bloqueados WHERE id = ?', [id]);
    return res.json({ mensagem: 'Bloqueio removido com sucesso!' });
  } catch (err) {
    return res.status(500).json({ erro: 'Erro interno ao remover bloqueio.' });
  }
}

// ==========================================
// RF09: Clientes com agendamentos confirmados futuros
// Usado para indicador verde nos contatos do barbeiro
// ==========================================
async function clientesAtivos(req, res) {
  try {
    // Só retorna telefones de clientes com agendamentos confirmados no futuro
    const [rows] = await pool.query(
      `SELECT DISTINCT u.telefone
       FROM agendamentos a
       JOIN usuarios u ON u.id = a.cliente_id
       WHERE a.status = 'confirmado'
         AND a.data_hora >= NOW()
         AND u.telefone IS NOT NULL
         AND u.telefone != ''`
    );
    return res.json(rows);
  } catch (err) {
    return res.status(500).json({ erro: 'Erro interno.' });
  }
}

module.exports = { criar, listarCliente, listarBarbeiro, cancelar, concluir, bloquearHorario, removerBloqueio, listarBloqueios, clientesAtivos };