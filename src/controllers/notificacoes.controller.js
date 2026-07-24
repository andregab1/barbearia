// ==========================================
// CONTROLLER: Notificações
// RF08 - Notificações Automáticas
// ==========================================
const { pool } = require('../config/database');

// ==========================================
// RF08: Listar notificações do usuário
// ==========================================
async function listar(req, res) {
  const usuario_id = req.usuario.id;

  try {
    const [rows] = await pool.query(
      `SELECT id, tipo, titulo, mensagem, enviada, criado_em
       FROM notificacoes
       WHERE usuario_id = ?
       ORDER BY criado_em DESC
       LIMIT 50`,
      [usuario_id]
    );
    return res.json(rows);
  } catch (err) {
    return res.status(500).json({ erro: 'Erro interno ao listar notificações.' });
  }
}

// ==========================================
// RF08: Disparar notificações pendentes (chamado pelo cron job)
// ==========================================
async function dispararPendentes(req, res) {
  try {
    const [pendentes] = await pool.query(
      `SELECT n.id, n.usuario_id, n.titulo, n.mensagem, u.telefone
       FROM notificacoes n
       JOIN usuarios u ON u.id = n.usuario_id
       WHERE n.enviada = 0 AND n.agendada_para <= NOW()
       LIMIT 100`
    );

    if (pendentes.length === 0) {
      return res.json({ mensagem: 'Nenhuma notificação pendente.' });
    }

    const ids = pendentes.map(n => n.id);

    // RF08: Marca como enviadas (integração push notification feita no Flutter)
    await pool.query(
      `UPDATE notificacoes SET enviada = 1, enviada_em = NOW() WHERE id IN (?)`,
      [ids]
    );

    return res.json({ disparadas: pendentes.length, notificacoes: pendentes });
  } catch (err) {
    return res.status(500).json({ erro: 'Erro interno ao disparar notificações.' });
  }
}

module.exports = { listar, dispararPendentes };