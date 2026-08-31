// ==========================================
// CONTROLLER: Horários de Funcionamento
// RF03 - Configuração de horários do barbeiro
// ==========================================
const { pool } = require('../config/database');
const { obterColaboradorAcessivel } = require('../utils/access');

const DIAS = ['Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado'];

// ==========================================
// RF03: Buscar horários do colaborador
// ==========================================
async function buscar(req, res) {
  const { colaborador_id } = req.params;

  try {
    const colaborador = await obterColaboradorAcessivel(req.usuario, colaborador_id);
    if (!colaborador) return res.status(403).json({ code: 'SCHEDULE_FORBIDDEN', erro: 'Sem permissão para acessar estes horários.' });
    const [rows] = await pool.query(
      `SELECT dia_semana, hora_inicio, hora_fim, ativo
       FROM horarios_funcionamento
       WHERE colaborador_id = ?
       ORDER BY dia_semana ASC`,
      [colaborador_id]
    );

    // Monta objeto com todos os dias
    const horarios = {};
    for (let i = 0; i <= 6; i++) {
      const encontrado = rows.find(r => r.dia_semana === i);
      horarios[i] = {
        dia:         DIAS[i],
        ativo:       encontrado ? encontrado.ativo === 1 : false,
        hora_inicio: encontrado ? encontrado.hora_inicio.substring(0, 5) : '09:00',
        hora_fim:    encontrado ? encontrado.hora_fim.substring(0, 5)    : '18:00',
      };
    }

    return res.json(horarios);
  } catch (err) {
    return res.status(500).json({ erro: 'Erro interno ao buscar horários.' });
  }
}

// ==========================================
// RF03: Salvar horários do colaborador
// ==========================================
async function salvar(req, res) {
  const { colaborador_id } = req.params;
  const { horarios }       = req.body;

  if (!horarios || typeof horarios !== 'object' || Array.isArray(horarios)) {
    return res.status(400).json({ erro: 'Horários são obrigatórios.' });
  }

  try {
    const colaborador = await obterColaboradorAcessivel(req.usuario, colaborador_id);
    if (!colaborador) return res.status(403).json({ code: 'SCHEDULE_FORBIDDEN', erro: 'Sem permissão para alterar estes horários.' });
    const valores = [];
    for (const [dia, config] of Object.entries(horarios)) {
      const diaNumero = Number.parseInt(dia, 10);
      if (!Number.isInteger(diaNumero) || diaNumero < 0 || diaNumero > 6 || typeof config !== 'object') {
        return res.status(400).json({ code: 'INVALID_SCHEDULE', erro: 'Configuração de horário inválida.' });
      }
      if (config.ativo) {
        const inicio = String(config.hora_inicio || '');
        const fim = String(config.hora_fim || '');
        if (!/^([01]\d|2[0-3]):[0-5]\d$/.test(inicio) || !/^([01]\d|2[0-3]):[0-5]\d$/.test(fim) || inicio >= fim) {
          return res.status(400).json({ code: 'INVALID_SCHEDULE_RANGE', erro: 'O horário final deve ser posterior ao inicial.' });
        }
        valores.push([colaborador_id, diaNumero, inicio, fim, 1]);
      }
    }
    const connection = await pool.getConnection();
    try {
      await connection.beginTransaction();
      await connection.query('DELETE FROM horarios_funcionamento WHERE colaborador_id = ?', [colaborador_id]);
      if (valores.length > 0) {
        await connection.query(
          `INSERT INTO horarios_funcionamento (colaborador_id, dia_semana, hora_inicio, hora_fim, ativo) VALUES ?`,
          [valores],
        );
      }
      await connection.commit();
    } catch (error) {
      await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }

    return res.json({ mensagem: 'Horários salvos com sucesso!' });
  } catch (err) {
    console.error('ERRO ao salvar horários:', err.message);
    return res.status(500).json({ erro: 'Erro interno ao salvar horários.' });
  }
}

module.exports = { buscar, salvar };
