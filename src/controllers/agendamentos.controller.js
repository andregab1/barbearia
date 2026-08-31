// ==========================================
// CONTROLLER: Agendamentos
// RF06 - Agendar | RF07 - Cancelar | RF11 - Bloquear
// ==========================================
const { pool } = require('../config/database');
const { obterColaboradorAcessivel } = require('../utils/access');

// ==========================================
// RF06: Criar novo agendamento
// ==========================================
async function criar(req, res) {
  const { colaborador_id, servico_id, servicos_ids, data_hora, observacao } = req.body;
  const cliente_id = req.usuario.id;

  if (!colaborador_id || !servico_id || !data_hora) {
    return res.status(400).json({ erro: 'Colaborador, serviço e data/hora são obrigatórios.' });
  }
  const colaboradorId = Number.parseInt(colaborador_id, 10);
  const idsRecebidos = Array.isArray(servicos_ids) && servicos_ids.length > 0
    ? servicos_ids
    : [servico_id];
  const servicoIds = [...new Set(idsRecebidos.map((id) => Number.parseInt(id, 10)))];
  const servicoId = servicoIds[0];
  const dataInicio = new Date(String(data_hora).replace(' ', 'T'));
  if (!Number.isInteger(colaboradorId) || colaboradorId <= 0 ||
      servicoIds.length === 0 || servicoIds.length > 10 ||
      servicoIds.some((id) => !Number.isInteger(id) || id <= 0) ||
      Number.isNaN(dataInicio.getTime()) || dataInicio <= new Date()) {
    return res.status(400).json({ code: 'INVALID_APPOINTMENT', erro: 'Informe serviço, profissional e uma data futura válida.' });
  }
  if (observacao != null && String(observacao).length > 1000) {
    return res.status(400).json({ code: 'NOTE_TOO_LONG', erro: 'A observação deve ter no máximo 1000 caracteres.' });
  }

  const pad = (value) => String(value).padStart(2, '0');
  const formatar = (value) => `${value.getFullYear()}-${pad(value.getMonth() + 1)}-${pad(value.getDate())} ${pad(value.getHours())}:${pad(value.getMinutes())}:${pad(value.getSeconds())}`;
  const dataHoraStr = formatar(dataInicio);
  const connection = await pool.getConnection();
  const lockName = `agendamento:${colaboradorId}`;
  let lockAdquirido = false;
  try {
    const [lockRows] = await connection.query('SELECT GET_LOCK(?, 5) AS acquired', [lockName]);
    lockAdquirido = lockRows[0]?.acquired === 1;
    if (!lockAdquirido) {
      return res.status(409).json({ code: 'SCHEDULE_BUSY', erro: 'A agenda está sendo atualizada. Tente novamente.' });
    }
    await connection.beginTransaction();
    const placeholders = servicoIds.map(() => '?').join(', ');
    const [servicos] = await connection.query(
      `SELECT s.id, s.preco, s.duracao_min
         FROM servicos s
         JOIN colaboradores c ON c.id = ? AND c.barbearia_id = s.barbearia_id
         JOIN usuarios u ON u.id = c.usuario_id
         JOIN barbearias b ON b.id = c.barbearia_id
        WHERE s.id IN (${placeholders}) AND s.ativo = 1 AND c.ativo = 1
          AND u.ativo = 1 AND b.ativa = 1
        FOR UPDATE`,
      [colaboradorId, ...servicoIds],
    );
    if (servicos.length !== servicoIds.length) {
      await connection.rollback();
      return res.status(404).json({ erro: 'Serviço ou profissional indisponível.' });
    }
    const duracaoFinal = servicos.reduce((total, item) => total + Number(item.duracao_min), 0);
    const valorFinal = servicos.reduce((total, item) => total + Number(item.preco), 0);
    const dataFim = new Date(dataInicio.getTime() + duracaoFinal * 60000);
    const dataFimStr = formatar(dataFim);
    const [expediente] = await connection.query(
      `SELECT id FROM horarios_funcionamento
        WHERE colaborador_id = ? AND dia_semana = DAYOFWEEK(?) - 1 AND ativo = 1
          AND TIMESTAMP(DATE(?), hora_inicio) <= ?
          AND TIMESTAMP(DATE(?), hora_fim) >= ?
        LIMIT 1 FOR UPDATE`,
      [colaboradorId, dataHoraStr, dataHoraStr, dataHoraStr, dataHoraStr, dataFimStr],
    );
    if (expediente.length === 0) {
      await connection.rollback();
      return res.status(409).json({
        code: 'SCHEDULE_UNAVAILABLE',
        erro: 'Horário fora do expediente do profissional.',
      });
    }
    const [conflitos] = await connection.query(
      `SELECT id FROM agendamentos
        WHERE colaborador_id = ? AND status IN ('confirmado', 'pendente')
          AND data_hora < ? AND DATE_ADD(data_hora, INTERVAL duracao_min MINUTE) > ?
        LIMIT 1 FOR UPDATE`,
      [colaboradorId, dataFimStr, dataHoraStr],
    );
    const [bloqueios] = await connection.query(
      `SELECT id FROM horarios_bloqueados
        WHERE colaborador_id = ? AND data_hora_ini < ? AND data_hora_fim > ?
        LIMIT 1 FOR UPDATE`,
      [colaboradorId, dataFimStr, dataHoraStr],
    );
    if (conflitos.length > 0 || bloqueios.length > 0) {
      await connection.rollback();
      return res.status(409).json({ code: 'APPOINTMENT_CONFLICT', erro: 'Horário indisponível. Escolha outro horário.' });
    }
    const [result] = await connection.query(
      `INSERT INTO agendamentos
         (cliente_id, colaborador_id, servico_id, data_hora, duracao_min, valor_cobrado, observacao)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [cliente_id, colaboradorId, servicoId, dataHoraStr, duracaoFinal, valorFinal, String(observacao || '').trim() || null],
    );
    await connection.query(
      `INSERT INTO agendamento_servicos
         (agendamento_id, servico_id, preco_cobrado, duracao_min)
       VALUES ?`,
      [servicos.map((item) => [result.insertId, item.id, item.preco, item.duracao_min])],
    );
    await connection.query(
      `INSERT INTO notificacoes (usuario_id, agendamento_id, tipo, titulo, mensagem, agendada_para)
       VALUES (?, ?, 'confirmacao', 'Agendamento confirmado!', 'Seu horário foi reservado com sucesso.', NOW())`,
      [cliente_id, result.insertId],
    );
    const lembrete = new Date(dataInicio.getTime() - 2 * 60 * 60 * 1000);
    if (lembrete > new Date()) {
      await connection.query(
        `INSERT INTO notificacoes (usuario_id, agendamento_id, tipo, titulo, mensagem, agendada_para)
         VALUES (?, ?, 'lembrete', 'Lembrete de agendamento', 'Você tem um horário marcado em 2 horas!', ?)`,
        [cliente_id, result.insertId, formatar(lembrete)],
      );
    }
    await connection.commit();
    return res.status(201).json({ mensagem: 'Agendamento realizado com sucesso!', id: result.insertId });
  } catch (err) {
    await connection.rollback().catch(() => {});
    console.error('ERRO ao criar agendamento:', err.message);
    return res.status(500).json({ erro: 'Erro interno ao criar agendamento.' });
  } finally {
    if (lockAdquirido) await connection.query('SELECT RELEASE_LOCK(?)', [lockName]).catch(() => {});
    connection.release();
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
             u.nome AS barbeiro,
             b.nome AS barbearia
      FROM agendamentos a
      JOIN servicos s      ON s.id = a.servico_id
      JOIN colaboradores c ON c.id = a.colaborador_id
      JOIN usuarios u      ON u.id = c.usuario_id
      JOIN barbearias b     ON b.id = c.barbearia_id
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
    const colaborador = await obterColaboradorAcessivel(req.usuario, colaborador_id);
    if (!colaborador) return res.status(403).json({ code: 'AGENDA_FORBIDDEN', erro: 'Sem permissao para acessar esta agenda.' });
    let query = `
      SELECT a.id, a.data_hora, a.status, a.valor_cobrado, a.duracao_min,
             s.nome AS servico, a.observacao,
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
  const connection = await pool.getConnection();

  try {
    await connection.beginTransaction();
    const [agendamento] = await connection.query(
      `SELECT id, cliente_id, colaborador_id, data_hora, status
         FROM agendamentos WHERE id = ? FOR UPDATE`,
      [id]
    );
    if (agendamento.length === 0) {
      await connection.rollback();
      return res.status(404).json({ erro: 'Agendamento não encontrado.' });
    }

    const ag = agendamento[0];

    if (ag.status === 'cancelado') {
      await connection.rollback();
      return res.status(409).json({ code: 'APPOINTMENT_ALREADY_CANCELED', erro: 'Agendamento já foi cancelado.' });
    }
    if (ag.status === 'concluido') {
      await connection.rollback();
      return res.status(409).json({ code: 'APPOINTMENT_ALREADY_COMPLETED', erro: 'Não é possível cancelar um agendamento concluído.' });
    }

    if (usuario.role === 'cliente' && ag.cliente_id !== usuario.id) {
      await connection.rollback();
      return res.status(403).json({ erro: 'Sem permissão para cancelar este agendamento.' });
    }

    if (usuario.role !== 'cliente') {
      const colaborador = await obterColaboradorAcessivel(usuario, ag.colaborador_id);
      if (!colaborador) {
        await connection.rollback();
        return res.status(403).json({ code: 'APPOINTMENT_FORBIDDEN', erro: 'Sem permissao para cancelar este atendimento.' });
      }
    }

    const agora     = new Date();
    const dataAgend = new Date(ag.data_hora);
    const diffHoras = (dataAgend - agora) / (1000 * 60 * 60);

    if (usuario.role === 'cliente' && diffHoras < 1) {
      await connection.rollback();
      return res.status(400).json({ erro: 'Cancelamento não permitido com menos de 1 hora de antecedência.' });
    }

    const [updated] = await connection.query(
      `UPDATE agendamentos SET status = 'cancelado'
        WHERE id = ? AND status IN ('confirmado', 'pendente')`,
      [id],
    );
    if (updated.affectedRows !== 1) {
      await connection.rollback();
      return res.status(409).json({ code: 'APPOINTMENT_STATE_CONFLICT', erro: 'O agendamento já foi atualizado.' });
    }

    await connection.query(
      `INSERT INTO notificacoes (usuario_id, agendamento_id, tipo, titulo, mensagem, agendada_para)
       VALUES (?, ?, 'cancelamento', 'Agendamento cancelado',
               'Seu agendamento foi cancelado.', NOW())`,
      [ag.cliente_id, id]
    );

    await connection.commit();
    return res.json({ mensagem: 'Agendamento cancelado com sucesso!' });
  } catch (err) {
    await connection.rollback().catch(() => {});
    console.error('ERRO ao cancelar:', err.message);
    return res.status(500).json({ erro: 'Erro interno ao cancelar agendamento.' });
  } finally {
    connection.release();
  }
}

// ==========================================
// RF03: Marcar agendamento como concluído
// ==========================================
async function concluir(req, res) {
  const { id } = req.params;

  try {
    const [agendamento] = await pool.query(
      `SELECT a.id, a.status, a.colaborador_id, a.valor_cobrado, c.barbearia_id,
              s.nome AS servico
         FROM agendamentos a
         JOIN colaboradores c ON c.id = a.colaborador_id
         JOIN servicos s ON s.id = a.servico_id
        WHERE a.id = ?`, [id]
    );
    if (agendamento.length === 0) return res.status(404).json({ erro: 'Agendamento não encontrado.' });
    const colaborador = await obterColaboradorAcessivel(req.usuario, agendamento[0].colaborador_id);
    if (!colaborador) return res.status(403).json({ code: 'APPOINTMENT_FORBIDDEN', erro: 'Sem permissao para alterar este atendimento.' });
    if (agendamento[0].status !== 'confirmado') {
      return res.status(400).json({ erro: 'Apenas agendamentos confirmados podem ser concluídos.' });
    }

    const connection = await pool.getConnection();
    try {
      await connection.beginTransaction();
      const [updated] = await connection.query(
        `UPDATE agendamentos SET status = 'concluido'
          WHERE id = ? AND status = 'confirmado'`,
        [id],
      );
      if (updated.affectedRows !== 1) {
        await connection.rollback();
        return res.status(409).json({ erro: 'O atendimento já foi atualizado.' });
      }
      await connection.query(
        `INSERT IGNORE INTO cash_entries
          (barbearia_id, appointment_id, criado_por, tipo, categoria, descricao, valor, ocorrido_em)
         VALUES (?, ?, ?, 'income', 'Atendimento', ?, ?, NOW())`,
        [agendamento[0].barbearia_id, id, req.usuario.id,
          agendamento[0].servico, agendamento[0].valor_cobrado],
      );
      await connection.commit();
    } catch (error) {
      await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
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
    const colaborador = await obterColaboradorAcessivel(req.usuario, colaborador_id);
    if (!colaborador) return res.status(403).json({ code: 'BLOCK_FORBIDDEN', erro: 'Sem permissao para bloquear esta agenda.' });
    const inicio = new Date(String(data_hora_ini).replace(' ', 'T'));
    const fim = new Date(String(data_hora_fim).replace(' ', 'T'));
    if (Number.isNaN(inicio.getTime()) || Number.isNaN(fim.getTime()) || fim <= inicio) {
      return res.status(400).json({ code: 'INVALID_BLOCK_PERIOD', erro: 'O horario final deve ser posterior ao inicial.' });
    }
    const [bloqueios] = await pool.query(
      `SELECT id FROM horarios_bloqueados
       WHERE colaborador_id = ? AND data_hora_ini < ? AND data_hora_fim > ?`,
      [colaborador_id, data_hora_fim, data_hora_ini]
    );
    if (bloqueios.length > 0) {
      return res.status(409).json({ code: 'BLOCK_CONFLICT', erro: 'Ja existe um bloqueio neste periodo.' });
    }
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

async function preverBloqueio(req, res) {
  const { colaborador_id, data_hora_ini, data_hora_fim } = req.body;
  if (!colaborador_id || !data_hora_ini || !data_hora_fim) {
    return res.status(400).json({ code: 'BLOCK_DATA_REQUIRED', erro: 'Colaborador, inicio e fim sao obrigatorios.' });
  }
  try {
    const colaborador = await obterColaboradorAcessivel(req.usuario, colaborador_id);
    if (!colaborador) return res.status(403).json({ code: 'BLOCK_FORBIDDEN', erro: 'Sem permissao para acessar esta agenda.' });
    const inicio = new Date(String(data_hora_ini).replace(' ', 'T'));
    const fim = new Date(String(data_hora_fim).replace(' ', 'T'));
    if (Number.isNaN(inicio.getTime()) || Number.isNaN(fim.getTime()) || fim <= inicio) {
      return res.status(400).json({ code: 'INVALID_BLOCK_PERIOD', erro: 'O horario final deve ser posterior ao inicial.' });
    }
    const [appointments] = await pool.query(
      `SELECT id, data_hora AS startTime,
              DATE_ADD(data_hora, INTERVAL duracao_min MINUTE) AS endTime
         FROM agendamentos
        WHERE colaborador_id = ? AND status IN ('confirmado','pendente')
          AND data_hora < ? AND DATE_ADD(data_hora, INTERVAL duracao_min MINUTE) > ?`,
      [colaborador_id, data_hora_fim, data_hora_ini],
    );
    const [blocks] = await pool.query(
      `SELECT id, data_hora_ini AS startTime, data_hora_fim AS endTime
         FROM horarios_bloqueados
        WHERE colaborador_id = ? AND data_hora_ini < ? AND data_hora_fim > ?`,
      [colaborador_id, data_hora_fim, data_hora_ini],
    );
    const conflicts = [
      ...appointments.map((item) => ({ ...item, type: 'APPOINTMENT' })),
      ...blocks.map((item) => ({ ...item, type: 'BLOCK' })),
    ];
    return res.json({
      valid: conflicts.length === 0,
      durationMinutes: Math.round((fim.getTime() - inicio.getTime()) / 60000),
      affectedAppointments: appointments.length,
      conflicts,
    });
  } catch (err) {
    console.error('ERRO preview bloqueio:', err.message);
    return res.status(500).json({ code: 'BLOCK_PREVIEW_ERROR', erro: 'Nao foi possivel validar o periodo.' });
  }
}

async function bloquearRecorrente(req, res) {
  const { colaborador_id, data_hora_ini, data_hora_fim, motivo, dias } = req.body;
  const totalDias = Number.parseInt(dias, 10);
  if (!colaborador_id || !data_hora_ini || !data_hora_fim || !Number.isInteger(totalDias) || totalDias < 1 || totalDias > 90) {
    return res.status(400).json({ code: 'INVALID_RECURRENCE', erro: 'Informe um periodo valido e recorrencia entre 1 e 90 dias.' });
  }
  try {
    const colaborador = await obterColaboradorAcessivel(req.usuario, colaborador_id);
    if (!colaborador) return res.status(403).json({ code: 'BLOCK_FORBIDDEN', erro: 'Sem permissao para bloquear esta agenda.' });
    const inicioBase = new Date(String(data_hora_ini).replace(' ', 'T'));
    const fimBase = new Date(String(data_hora_fim).replace(' ', 'T'));
    if (Number.isNaN(inicioBase.getTime()) || Number.isNaN(fimBase.getTime()) || fimBase <= inicioBase) {
      return res.status(400).json({ code: 'INVALID_BLOCK_PERIOD', erro: 'O horario final deve ser posterior ao inicial.' });
    }
    const pad = (value) => String(value).padStart(2, '0');
    const format = (value) => `${value.getFullYear()}-${pad(value.getMonth() + 1)}-${pad(value.getDate())} ${pad(value.getHours())}:${pad(value.getMinutes())}:00`;
    const periods = Array.from({ length: totalDias }, (_, index) => ({
      start: new Date(inicioBase.getTime() + index * 86400000),
      end: new Date(fimBase.getTime() + index * 86400000),
    }));
    const connection = await pool.getConnection();
    try {
      await connection.beginTransaction();
      for (const period of periods) {
        const start = format(period.start);
        const end = format(period.end);
        const [conflicts] = await connection.query(
          `SELECT id FROM agendamentos WHERE colaborador_id = ? AND status IN ('confirmado','pendente')
             AND data_hora < ? AND DATE_ADD(data_hora, INTERVAL duracao_min MINUTE) > ?
           UNION ALL
           SELECT id FROM horarios_bloqueados WHERE colaborador_id = ? AND data_hora_ini < ? AND data_hora_fim > ?`,
          [colaborador_id, end, start, colaborador_id, end, start],
        );
        if (conflicts.length > 0) {
          const error = new Error(`Conflito em ${start.substring(0, 10)}.`);
          error.code = 'BLOCK_CONFLICT';
          throw error;
        }
        await connection.query(
          'INSERT INTO horarios_bloqueados (colaborador_id, data_hora_ini, data_hora_fim, motivo) VALUES (?, ?, ?, ?)',
          [colaborador_id, start, end, motivo || null],
        );
      }
      await connection.commit();
      return res.status(201).json({ mensagem: `${periods.length} bloqueio(s) criado(s) com sucesso.`, created: periods.length });
    } catch (error) {
      await connection.rollback();
      if (error.code === 'BLOCK_CONFLICT') return res.status(409).json({ code: error.code, erro: error.message });
      throw error;
    } finally {
      connection.release();
    }
  } catch (err) {
    console.error('ERRO bloqueio recorrente:', err.message);
    return res.status(500).json({ code: 'BLOCK_CREATE_ERROR', erro: 'Nao foi possivel criar os bloqueios.' });
  }
}

// ==========================================
// RF11: Listar bloqueios do colaborador
// ==========================================
async function listarBloqueios(req, res) {
  const { colaborador_id } = req.params;
  const { data_ini, data_fim } = req.query;

  try {
    const colaborador = await obterColaboradorAcessivel(req.usuario, colaborador_id);
    if (!colaborador) return res.status(403).json({ code: 'BLOCK_FORBIDDEN', erro: 'Sem permissao para acessar estes bloqueios.' });
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
      'SELECT id, colaborador_id FROM horarios_bloqueados WHERE id = ?', [id]
    );
    if (bloqueio.length === 0) return res.status(404).json({ erro: 'Bloqueio não encontrado.' });
    const colaborador = await obterColaboradorAcessivel(req.usuario, bloqueio[0].colaborador_id);
    if (!colaborador) return res.status(403).json({ code: 'BLOCK_FORBIDDEN', erro: 'Sem permissao para remover este bloqueio.' });

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
    const usuarioId = req.usuario.id;

    // Busca o colaborador_id do barbeiro logado
    const [colab] = await pool.query(
      'SELECT id FROM colaboradores WHERE usuario_id = ? AND ativo = 1 LIMIT 1',
      [usuarioId]
    );

    if (colab.length === 0) {
      return res.json([]); // barbeiro sem colaborador vinculado
    }

    const colaboradorId = colab[0].id;

    // Retorna apenas os clientes com agendamento confirmado DESTE barbeiro
    const [rows] = await pool.query(
      `SELECT DISTINCT u.telefone
       FROM agendamentos a
       JOIN usuarios u ON u.id = a.cliente_id
       WHERE a.status = 'confirmado'
         AND a.data_hora >= NOW()
         AND a.colaborador_id = ?
         AND u.telefone IS NOT NULL
         AND u.telefone != ''`,
      [colaboradorId]
    );
    return res.json(rows);
  } catch (err) {
    console.error('ERRO clientesAtivos:', err.message);
    return res.status(500).json({ erro: 'Erro interno.' });
  }
}

async function listarClientesProfissional(req, res) {
  const busca = String(req.query.busca || '').trim();
  try {
    const [colabs] = await pool.query(
      'SELECT id FROM colaboradores WHERE usuario_id = ? AND ativo = 1 LIMIT 1',
      [req.usuario.id],
    );
    if (colabs.length === 0) return res.json([]);

    const params = [colabs[0].id];
    let filtro = '';
    if (busca) {
      filtro = ' AND (u.nome LIKE ? OR u.telefone LIKE ? OR u.email LIKE ?)';
      const termo = `%${busca}%`;
      params.push(termo, termo, termo);
    }
    const [rows] = await pool.query(
      `SELECT u.id, u.nome, u.telefone, u.email,
              COUNT(a.id) AS total_atendimentos,
              MAX(CASE WHEN a.status = 'concluido' THEN a.data_hora END) AS ultima_visita,
              MIN(CASE WHEN a.status = 'confirmado' AND a.data_hora >= NOW() THEN a.data_hora END) AS proximo_agendamento
         FROM agendamentos a
         JOIN usuarios u ON u.id = a.cliente_id
        WHERE a.colaborador_id = ?${filtro}
        GROUP BY u.id, u.nome, u.telefone, u.email
        ORDER BY proximo_agendamento IS NULL, proximo_agendamento ASC, u.nome ASC
        LIMIT 200`,
      params,
    );
    return res.json(rows);
  } catch (err) {
    console.error('ERRO listar clientes do profissional:', err.message);
    return res.status(500).json({ erro: 'Erro interno ao listar clientes.' });
  }
}

module.exports = { criar, listarCliente, listarBarbeiro, cancelar, concluir, bloquearHorario, preverBloqueio, bloquearRecorrente, removerBloqueio, listarBloqueios, clientesAtivos, listarClientesProfissional };
