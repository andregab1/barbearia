const { pool } = require('../config/database');
const commissionService = require('./commission.service');

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

async function reconcilePendingCommissions() {
  const [rows] = await pool.query(
    `SELECT DISTINCT barbearia_id tenant_id, agendamento_id appointment_id
       FROM commission_entitlements
      WHERE status = 'pending_rule'`,
  );
  for (const row of rows) {
    const connection = await pool.getConnection();
    try {
      await connection.beginTransaction();
      await commissionService.reconcileAppointment(connection, {
        tenantId: row.tenant_id,
        appointmentId: row.appointment_id,
        actorId: null,
      });
      await connection.commit();
    } catch (error) {
      await connection.rollback().catch(() => {});
      throw error;
    } finally {
      connection.release();
    }
  }
  return rows.length;
}

function startAppointmentAutomation({ intervalMs = 5 * 60 * 1000 } = {}) {
  const run = () => Promise.all([
    confirmPastPendingAppointments(),
    reconcilePendingCommissions(),
  ]).catch((error) => console.error('Falha na automacao de agendamentos/comissoes:', error.message));
  run();
  const timer = setInterval(run, intervalMs);
  timer.unref();
  return timer;
}

module.exports = { confirmPastPendingAppointments, reconcilePendingCommissions, startAppointmentAutomation };
