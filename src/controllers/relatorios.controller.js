// ==========================================
// CONTROLLER: Relatórios
// RF13 - Faturamento diário, mensal e por período
// ==========================================
const { pool } = require('../config/database');

// ==========================================
// RF13: Relatório diário
// ==========================================
async function faturamentoDiario(req, res) {
  const { barbearia_id } = req.params;
  const { data }         = req.query;
  const dataConsulta     = data || new Date().toISOString().slice(0, 10);

  try {
    const [concluidos] = await pool.query(
      `SELECT a.id, a.data_hora, a.valor_cobrado,
              s.nome AS servico, u.nome AS barbeiro, uc.nome AS cliente
       FROM agendamentos a
       JOIN servicos s      ON s.id = a.servico_id
       JOIN colaboradores c ON c.id = a.colaborador_id
       JOIN usuarios u      ON u.id = c.usuario_id
       JOIN usuarios uc     ON uc.id = a.cliente_id
       WHERE c.barbearia_id = ? AND DATE(a.data_hora) = ? AND a.status = 'concluido'
       ORDER BY a.data_hora ASC`,
      [barbearia_id, dataConsulta]
    );

    const [confirmados] = await pool.query(
      `SELECT COUNT(*) as total, COALESCE(SUM(a.valor_cobrado), 0) as total_previsto
       FROM agendamentos a
       JOIN colaboradores c ON c.id = a.colaborador_id
       WHERE c.barbearia_id = ? AND DATE(a.data_hora) = ? AND a.status = 'confirmado'`,
      [barbearia_id, dataConsulta]
    );

    const totalFaturado = concluidos.reduce((acc, r) => acc + parseFloat(r.valor_cobrado), 0);
    return res.json({
      data:                  dataConsulta,
      total_atendimentos:    concluidos.length,
      total_faturado:        totalFaturado.toFixed(2),
      total_previsto:        parseFloat(confirmados[0].total_previsto || 0).toFixed(2),
      confirmados_pendentes: confirmados[0].total,
      atendimentos:          concluidos,
    });
  } catch (err) {
    return res.status(500).json({ erro: 'Erro interno ao gerar relatório diário.' });
  }
}

// ==========================================
// RF13: Relatório mensal (mês atual)
// ==========================================
async function faturamentoMensal(req, res) {
  const { barbearia_id } = req.params;
  const { ano, mes }     = req.query;

  const hoje    = new Date();
  const anoRef  = parseInt(ano)  || hoje.getFullYear();
  const mesRef  = parseInt(mes)  || (hoje.getMonth() + 1);
  const dataIni = `${anoRef}-${String(mesRef).padStart(2,'0')}-01`;
  // Calcula o último dia correto do mês (ex: junho = 30, julho = 31)
  const ultimoDia = new Date(anoRef, mesRef, 0).getDate();
  const dataFim   = `${anoRef}-${String(mesRef).padStart(2,'0')}-${String(ultimoDia).padStart(2,'0')}`;

  try {
    const [rows] = await pool.query(
      `SELECT
         COUNT(*) as total_atendimentos,
         COALESCE(SUM(a.valor_cobrado), 0) as total_faturado,
         DATE(a.data_hora) as dia
       FROM agendamentos a
       JOIN colaboradores c ON c.id = a.colaborador_id
       WHERE c.barbearia_id = ?
         AND DATE(a.data_hora) BETWEEN ? AND ?
         AND a.status = 'concluido'
       GROUP BY DATE(a.data_hora)
       ORDER BY dia ASC`,
      [barbearia_id, dataIni, dataFim]
    );

    const totalFaturado = rows.reduce((acc, r) => acc + parseFloat(r.total_faturado), 0);
    const totalAtend    = rows.reduce((acc, r) => acc + parseInt(r.total_atendimentos), 0);

    const [confirmadosMes] = await pool.query(
      `SELECT COALESCE(SUM(a.valor_cobrado), 0) as previsto
       FROM agendamentos a
       JOIN colaboradores c ON c.id = a.colaborador_id
       WHERE c.barbearia_id = ?
         AND DATE(a.data_hora) BETWEEN ? AND ?
         AND a.status = 'confirmado'`,
      [barbearia_id, dataIni, dataFim]
    );

    return res.json({
      ano:                anoRef,
      mes:                mesRef,
      total_faturado:     totalFaturado.toFixed(2),
      total_atendimentos: totalAtend,
      total_previsto:     parseFloat(confirmadosMes[0].previsto || 0).toFixed(2),
      por_dia:            rows,
    });
  } catch (err) {
    return res.status(500).json({ erro: 'Erro interno ao gerar relatório mensal.' });
  }
}

// ==========================================
// RF13: Relatório por período personalizado
// ==========================================
async function faturamentoPeriodo(req, res) {
  const { barbearia_id }       = req.params;
  const { data_ini, data_fim } = req.query;

  if (!data_ini || !data_fim) {
    return res.status(400).json({ erro: 'data_ini e data_fim são obrigatórias.' });
  }

  try {
    const [rows] = await pool.query(
      `SELECT DATE(a.data_hora) AS data,
              COUNT(*) AS total_atendimentos,
              SUM(a.valor_cobrado) AS total_faturado
       FROM agendamentos a
       JOIN colaboradores c ON c.id = a.colaborador_id
       WHERE c.barbearia_id = ?
         AND DATE(a.data_hora) BETWEEN ? AND ?
         AND a.status = 'concluido'
       GROUP BY DATE(a.data_hora)
       ORDER BY data ASC`,
      [barbearia_id, data_ini, data_fim]
    );

    const totalGeral = rows.reduce((acc, r) => acc + parseFloat(r.total_faturado || 0), 0);
    return res.json({
      periodo:     { de: data_ini, ate: data_fim },
      total_geral: totalGeral.toFixed(2),
      por_dia:     rows,
    });
  } catch (err) {
    return res.status(500).json({ erro: 'Erro interno ao gerar relatório por período.' });
  }
}

module.exports = { faturamentoDiario, faturamentoMensal, faturamentoPeriodo };