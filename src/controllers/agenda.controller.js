// ==========================================
// CONTROLLER: Agenda e Horários Disponíveis
// RF05 - Visualização | RF10 - Histórico
// ==========================================
const { pool } = require('../config/database');
const { obterColaboradorAcessivel } = require('../utils/access');

async function dashboard(req, res) {
  try {
    const colaborador = await obterColaboradorAcessivel(req.usuario, req.params.colaborador_id);
    if (!colaborador) {
      return res.status(403).json({ code: 'AGENDA_FORBIDDEN', erro: 'Sem permissao para acessar esta agenda.' });
    }

    const id = colaborador.id;
    const dateOnly = (value) => {
      const text = String(value || '').slice(0, 10);
      return /^\d{4}-\d{2}-\d{2}$/.test(text) ? text : null;
    };
    const today = new Date();
    const localToday = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;
    const requestedFrom = dateOnly(req.query.from);
    const requestedTo = dateOnly(req.query.to);
    const fromDate = requestedFrom || localToday;
    const defaultTo = new Date(`${fromDate}T00:00:00`);
    defaultTo.setDate(defaultTo.getDate() + 29);
    const toDate = requestedTo || (requestedFrom ? fromDate : defaultTo.toISOString().slice(0, 10));
    if (toDate < fromDate) {
      return res.status(400).json({ code: 'INVALID_DATE_RANGE', erro: 'Período de agenda inválido.' });
    }
    const [[summaryRows], [appointments], [working], [blocked]] = await Promise.all([
      pool.query(
        `SELECT
           SUM(CASE WHEN DATE(data_hora) = CURDATE() AND status IN ('confirmado','pendente','cliente_chegou','em_atendimento') THEN 1 ELSE 0 END) AS today,
           SUM(CASE WHEN data_hora > NOW() AND status IN ('confirmado','pendente','cliente_chegou','em_atendimento') THEN 1 ELSE 0 END) AS upcoming,
           COUNT(*) AS total
         FROM agendamentos
         WHERE colaborador_id = ?`,
        [id],
      ),
      pool.query(
        `SELECT a.id, a.data_hora, a.status, a.valor_cobrado, a.duracao_min, a.servico_id,
                s.nome AS servico, a.observacao,
                u.nome AS cliente, u.telefone AS cliente_telefone
           FROM agendamentos a
           JOIN servicos s ON s.id = a.servico_id
           JOIN usuarios u ON u.id = a.cliente_id
          WHERE a.colaborador_id = ?
            AND a.data_hora >= ?
            AND a.data_hora < DATE_ADD(?, INTERVAL 1 DAY)
            AND a.status IN ('confirmado','pendente','cliente_chegou','em_atendimento')
          ORDER BY a.data_hora ASC`,
        [id, fromDate, toDate],
      ),
      pool.query(
        `SELECT hora_inicio, hora_fim
           FROM horarios_funcionamento
          WHERE colaborador_id = ? AND dia_semana = DAYOFWEEK(CURDATE()) - 1 AND ativo = 1
          LIMIT 1`,
        [id],
      ),
      pool.query(
        `SELECT COALESCE(SUM(TIMESTAMPDIFF(MINUTE, data_hora_ini, data_hora_fim)), 0) AS minutes
           FROM horarios_bloqueados
          WHERE colaborador_id = ? AND DATE(data_hora_ini) = CURDATE()`,
        [id],
      ),
    ]);

    const todayAppointments = appointments.filter((item) => {
      const value = item.data_hora instanceof Date
        ? item.data_hora
        : new Date(String(item.data_hora).replace(' ', 'T'));
      const now = new Date();
      return value.getFullYear() === now.getFullYear()
        && value.getMonth() === now.getMonth()
        && value.getDate() === now.getDate();
    });
    const bookedMinutes = todayAppointments.reduce((sum, item) => sum + Number(item.duracao_min || 0), 0);
    let availableMinutes = 0;
    if (working[0]) {
      const toMinutes = (value) => {
        const [hour, minute] = String(value).split(':').map(Number);
        return hour * 60 + minute;
      };
      availableMinutes = Math.max(0, toMinutes(working[0].hora_fim) - toMinutes(working[0].hora_inicio) - Number(blocked[0]?.minutes || 0));
    }

    const summary = summaryRows[0] || {};
    return res.json({
      summary: {
        today: Number(summary.today || 0),
        upcoming: Number(summary.upcoming || 0),
        total: Number(summary.total || 0),
      },
      nextAppointment: appointments.find((item) => new Date(String(item.data_hora).replace(' ', 'T')) > new Date()) || null,
      todayAppointments,
      upcomingAppointments: appointments,
      occupancy: {
        bookedMinutes,
        availableMinutes,
        percentage: availableMinutes > 0 ? Math.min(100, Math.round((bookedMinutes / availableMinutes) * 100)) : 0,
      },
    });
  } catch (err) {
    console.error('ERRO dashboard agenda:', err.message);
    return res.status(500).json({ code: 'AGENDA_LOAD_ERROR', erro: 'Nao foi possivel carregar a agenda.' });
  }
}

// ==========================================
// RF05: Buscar horários disponíveis
// Suporta duração total (múltiplos serviços)
// ==========================================
async function horariosdisponiveis(req, res) {
  const { colaborador_id } = req.params;
  const { data, servico_id, duracao_total } = req.query;

  if (!data) {
    return res.status(400).json({ erro: 'Data é obrigatória.' });
  }

  try {
    let duracao = parseInt(duracao_total) || 0;

    // Se não veio duração total, busca pelo serviço
    if (!duracao && servico_id) {
      const [servico] = await pool.query(
        'SELECT duracao_min FROM servicos WHERE id = ? AND ativo = 1',
        [servico_id]
      );
      if (servico.length === 0) return res.status(404).json({ erro: 'Serviço não encontrado.' });
      duracao = servico[0].duracao_min;
    }

    if (!duracao) return res.status(400).json({ erro: 'Informe servico_id ou duracao_total.' });

    const slots = await require('../services/appointment-availability.service').availableSlots(pool, colaborador_id, data, Number(duracao));

    return res.json({ disponiveis: slots });
  } catch (err) {
    console.error('ERRO horarios disponíveis:', err.message);
    return res.status(500).json({ erro: 'Erro interno ao buscar horários disponíveis.' });
  }
}

// ==========================================
// RF10: Histórico de atendimentos do cliente
// ==========================================
async function historico(req, res) {
  const { cliente_id } = req.params;

  if (Number.parseInt(cliente_id, 10) !== req.usuario.id) {
    return res.status(403).json({ code: 'HISTORY_FORBIDDEN', erro: 'Sem permissão para acessar este histórico.' });
  }

  try {
    const [rows] = await pool.query(
      `SELECT a.id, a.data_hora, a.status, a.valor_cobrado,
              s.nome AS servico, u.nome AS barbeiro
       FROM agendamentos a
       JOIN servicos s      ON s.id = a.servico_id
       JOIN colaboradores c ON c.id = a.colaborador_id
       JOIN usuarios u      ON u.id = c.usuario_id
       WHERE a.cliente_id = ? AND a.status = 'concluido'
       ORDER BY a.data_hora DESC`,
      [cliente_id]
    );
    return res.json({ historico: rows });
  } catch (err) {
    return res.status(500).json({ erro: 'Erro interno ao buscar histórico.' });
  }
}

module.exports = { horariosdisponiveis, historico, dashboard };
