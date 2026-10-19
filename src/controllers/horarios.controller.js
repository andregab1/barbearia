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
      `SELECT id, dia_semana, hora_inicio, hora_fim, ativo
       FROM horarios_funcionamento
       WHERE colaborador_id = ?
       ORDER BY dia_semana ASC, hora_inicio ASC`,
      [colaborador_id]
    );

    // Monta objeto com todos os dias
    const horarios = {};
    for (let i = 0; i <= 6; i++) {
      const faixas = rows
        .filter((row) => Number(row.dia_semana) === i && row.ativo === 1)
        .map((row) => ({
          id: String(row.id),
          start: String(row.hora_inicio).substring(0, 5),
          end: String(row.hora_fim).substring(0, 5),
        }));
      const primeiraFaixa = faixas[0];
      const ultimaFaixa = faixas[faixas.length - 1];
      horarios[i] = {
        dia:         DIAS[i],
        ativo:       faixas.length > 0,
        faixas,
        // Mantém os campos antigos para consumidores legados.
        hora_inicio: primeiraFaixa ? primeiraFaixa.start : '09:00',
        hora_fim:    ultimaFaixa ? ultimaFaixa.end : '18:00',
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
      if (!config.ativo) continue;

      const faixas = Array.isArray(config.faixas)
        ? config.faixas
        : [{ hora_inicio: config.hora_inicio, hora_fim: config.hora_fim }];
      if (faixas.length > 8) {
        return res.status(400).json({ code: 'INVALID_SCHEDULE_RANGE', erro: 'Cada dia pode ter no máximo 8 períodos.' });
      }

      const intervalos = [];
      for (const faixa of faixas) {
        if (!faixa || typeof faixa !== 'object') {
          return res.status(400).json({ code: 'INVALID_SCHEDULE_RANGE', erro: 'Configuração de horário inválida.' });
        }
        const inicio = String(faixa.start || faixa.hora_inicio || '');
        const fim = String(faixa.end || faixa.hora_fim || '');
        if (!/^([01]\d|2[0-3]):[0-5]\d$/.test(inicio) || !/^([01]\d|2[0-3]):[0-5]\d$/.test(fim) || inicio >= fim) {
          return res.status(400).json({ code: 'INVALID_SCHEDULE_RANGE', erro: 'O horário final deve ser posterior ao inicial.' });
        }
        intervalos.push({ inicio, fim });
      }

      intervalos.sort((primeiro, segundo) => primeiro.inicio.localeCompare(segundo.inicio));
      for (let indice = 1; indice < intervalos.length; indice += 1) {
        if (intervalos[indice - 1].fim > intervalos[indice].inicio) {
          return res.status(400).json({ code: 'INVALID_SCHEDULE_OVERLAP', erro: 'Existem períodos de atendimento sobrepostos.' });
        }
      }
      for (const intervalo of intervalos) {
        valores.push([colaborador_id, diaNumero, intervalo.inicio, intervalo.fim, 1]);
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
