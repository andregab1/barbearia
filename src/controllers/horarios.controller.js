// ==========================================
// CONTROLLER: Horários de Funcionamento
// RF03 - Configuração de horários do barbeiro
// ==========================================
const { pool } = require('../config/database');

const DIAS = ['Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado'];

// ==========================================
// RF03: Buscar horários do colaborador
// ==========================================
async function buscar(req, res) {
  const { colaborador_id } = req.params;

  try {
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

  if (!horarios) return res.status(400).json({ erro: 'Horários são obrigatórios.' });

  try {
    // Remove horários antigos e insere os novos
    await pool.query(
      'DELETE FROM horarios_funcionamento WHERE colaborador_id = ?',
      [colaborador_id]
    );

    const valores = [];
    for (const [dia, config] of Object.entries(horarios)) {
      if (config.ativo) {
        valores.push([colaborador_id, parseInt(dia), config.hora_inicio, config.hora_fim, 1]);
      }
    }

    if (valores.length > 0) {
      await pool.query(
        `INSERT INTO horarios_funcionamento (colaborador_id, dia_semana, hora_inicio, hora_fim, ativo)
         VALUES ?`,
        [valores]
      );
    }

    return res.json({ mensagem: 'Horários salvos com sucesso!' });
} catch (err) {
  console.error('ERRO ao salvar horários:', err.message);
  return res.status(500).json({ erro: 'Erro interno ao salvar horários.' });
}
}

module.exports = { buscar, salvar };