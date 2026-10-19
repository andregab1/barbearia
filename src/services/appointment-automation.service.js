const { pool } = require('../config/database');

async function confirmPastPendingAppointments() {
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const [appointments] = await connection.query(
      `SELECT a.id, c.barbearia_id FROM agendamentos a
       JOIN colaboradores c ON c.id = a.colaborador_id
       WHERE a.status = 'pendente'
         AND DATE_ADD(a.data_hora, INTERVAL a.duracao_min MINUTE) <= NOW()
       FOR UPDATE`,
    );
    if (appointments.length === 0) { await connection.commit(); return 0; }
    const ids = appointments.map((item) => item.id);
    await connection.query(`UPDATE agendamentos SET status='confirmado' WHERE status='pendente' AND id IN (?)`, [ids]);
    for (const appointment of appointments) {
      await connection.query(
        `INSERT INTO audit_logs (barbearia_id,usuario_id,acao,recurso,recurso_id,detalhes)
         VALUES (?,NULL,'appointment.auto_confirmed','appointment',?,JSON_OBJECT('reason','scheduled_time_elapsed'))`,
        [appointment.barbearia_id, String(appointment.id)],
      );
    }
    await connection.commit();
    return appointments.length;
  } catch (error) {
    await connection.rollback().catch(() => {});
    throw error;
  } finally { connection.release(); }
}

function startAppointmentAutomation({ intervalMs = 5 * 60 * 1000 } = {}) {
  const run = () => confirmPastPendingAppointments().catch((error) => console.error('Falha ao confirmar agendamentos vencidos:', error.message));
  run();
  const timer = setInterval(run, intervalMs);
  timer.unref();
  return timer;
}

module.exports = { confirmPastPendingAppointments, startAppointmentAutomation };
