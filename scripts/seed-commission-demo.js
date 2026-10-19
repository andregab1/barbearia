#!/usr/bin/env node
'use strict';

const dotenv = require('dotenv');

dotenv.config();

const configuredHost = (process.env.DB_HOST || 'localhost').toLowerCase();
if (process.env.DATABASE_URL || !['localhost', '127.0.0.1', '::1'].includes(configuredHost)) {
  throw new Error('Safety stop: commission demo seed requires a local MySQL connection.');
}

const { pool } = require('../src/config/database');
const commissionService = require('../src/services/commission.service');
const financialService = require('../src/services/financial.service');

const DEMO_KEY = 'commission-demo-2026';
const PASSWORD_HASH = '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi';
const DEMO_PROFESSIONALS = [
  { name: 'Ana Demo', email: 'ana.demo@local.test', phone: '41990000101' },
  { name: 'Bruno Demo', email: 'bruno.demo@local.test', phone: '41990000102' },
  { name: 'Carla Demo', email: 'carla.demo@local.test', phone: '41990000103' },
];

function dateTimeDaysAgo(daysAgo) {
  const value = new Date();
  value.setUTCDate(value.getUTCDate() - daysAgo);
  value.setUTCHours(12, 0, 0, 0);
  return value.toISOString().slice(0, 19).replace('T', ' ');
}

async function findOrCreateUser(connection, professional) {
  await connection.query(
    `INSERT INTO usuarios (nome, email, telefone, senha_hash, role, ativo)
     VALUES (?, ?, ?, ?, 'barbeiro', 1)
     ON DUPLICATE KEY UPDATE
       id = LAST_INSERT_ID(id), nome = VALUES(nome), senha_hash = VALUES(senha_hash),
       role = 'barbeiro', ativo = 1`,
    [professional.name, professional.email, professional.phone, PASSWORD_HASH],
  );
  const [[user]] = await connection.query(
    'SELECT id, nome FROM usuarios WHERE email = ?',
    [professional.email],
  );
  return user;
}

async function ensureProfessional(connection, tenantId, professional) {
  const user = await findOrCreateUser(connection, professional);
  await connection.query(
    `INSERT INTO colaboradores (barbearia_id, usuario_id, ativo)
     VALUES (?, ?, 1)
     ON DUPLICATE KEY UPDATE id = LAST_INSERT_ID(id), ativo = 1`,
    [tenantId, user.id],
  );
  const [[collaborator]] = await connection.query(
    `SELECT c.id, c.usuario_id, u.nome
       FROM colaboradores c
       JOIN usuarios u ON u.id = c.usuario_id
      WHERE c.barbearia_id = ? AND c.usuario_id = ?`,
    [tenantId, user.id],
  );
  await connection.query(
    `INSERT INTO memberships (barbearia_id, usuario_id, papel, ativo)
     VALUES (?, ?, 'professional', 1)
     ON DUPLICATE KEY UPDATE papel = 'professional', ativo = 1`,
    [tenantId, user.id],
  );
  return collaborator;
}

function hasDemoRule(rows) {
  return rows.some((row) => {
    try {
      const config = typeof row.config_json === 'string'
        ? JSON.parse(row.config_json)
        : row.config_json;
      return config && config.demoKey === DEMO_KEY;
    } catch (_) {
      return false;
    }
  });
}

async function ensureRule(tenantId, actorId, professional) {
  const [existing] = await pool.query(
    `SELECT id, config_json
       FROM commission_rules
      WHERE barbearia_id = ? AND profissional_id = ? AND servico_id IS NULL
        AND ativo = 1`,
    [tenantId, professional.id],
  );
  if (hasDemoRule(existing)) return { created: false, id: existing[0].id };
  if (existing.length > 0) return { created: false, id: existing[0].id, reusedExisting: true };

  const result = await commissionService.createRule({
    tenantId,
    actorId,
    data: {
      name: `Demo 40% — ${professional.nome}`,
      professionalId: professional.id,
      serviceId: null,
      type: 'percentage',
      value: '40',
      base: 'net_after_discount',
      validFrom: '2026-09-01T00:00:00-03:00',
      config: {
        demoKey: DEMO_KEY,
        source: 'development-seed',
        description: 'Regra demonstrativa de desenvolvimento: 40% após descontos.',
      },
    },
  });
  if (result.status >= 400) {
    throw new Error(`Falha ao criar regra para ${professional.nome}: ${result.code}`);
  }
  return { created: true, id: result.id };
}

async function ensureDemoAppointment({ tenantId, actorId, clientId, professional, service, daysAgo }) {
  const marker = `${DEMO_KEY}:${professional.id}:${service.id}`;
  const [existingRows] = await pool.query(
    `SELECT id, status, valor_cobrado
       FROM agendamentos
      WHERE colaborador_id = ? AND servico_id = ? AND observacao = ?
      ORDER BY id DESC LIMIT 1`,
    [professional.id, service.id, marker],
  );

  let appointment = existingRows[0];
  if (!appointment) {
    const [inserted] = await pool.query(
      `INSERT INTO agendamentos
         (cliente_id, colaborador_id, servico_id, data_hora, duracao_min, status, valor_cobrado, observacao)
       VALUES (?, ?, ?, ?, ?, 'confirmado', ?, ?)`,
      [
        clientId,
        professional.id,
        service.id,
        dateTimeDaysAgo(daysAgo),
        service.duracao_min,
        service.preco,
        marker,
      ],
    );
    appointment = {
      id: inserted.insertId,
      status: 'confirmado',
      valor_cobrado: service.preco,
    };
  }

  if (appointment.status !== 'concluido') {
    const completed = await financialService.completeAppointment({
      appointmentId: appointment.id,
      actorId,
      tenantId,
    });
    if (completed.status >= 400 && completed.code !== 'APPOINTMENT_ALREADY_COMPLETED') {
      throw new Error(`Falha ao concluir atendimento #${appointment.id}: ${completed.code}`);
    }
  }

  const paymentKey = `${DEMO_KEY}-payment-${appointment.id}`;
  const [[payment]] = await pool.query(
    'SELECT id FROM payments WHERE idempotency_key = ?',
    [paymentKey],
  );
  if (!payment) {
    const registered = await financialService.registerPayment({
      tenantId,
      actorId,
      appointmentId: appointment.id,
      method: 'pix',
      amount: String(appointment.valor_cobrado),
      idempotencyKey: paymentKey,
    });
    if (registered.status >= 400 && registered.code !== 'PAYMENT_ALREADY_REGISTERED') {
      throw new Error(`Falha ao receber atendimento #${appointment.id}: ${registered.code}`);
    }
  }

  return { appointmentId: appointment.id, paymentCreated: !payment };
}

async function main() {
  const connection = await pool.getConnection();
  try {
    const [[tenant]] = await connection.query(
      `SELECT id, admin_id
         FROM barbearias
        WHERE slug = 'barbearia-local' AND ativa = 1
        LIMIT 1`,
    );
    if (!tenant) throw new Error('Tenant local barbearia-local não encontrado. Rode database/seeds/development.sql primeiro.');

    const [[client]] = await connection.query(
      `SELECT id FROM usuarios WHERE email = 'cliente@local.test' AND ativo = 1 LIMIT 1`,
    );
    if (!client) throw new Error('Cliente local não encontrado. Rode database/seeds/development.sql primeiro.');

    const demoProfessionals = [];
    for (const professional of DEMO_PROFESSIONALS) {
      demoProfessionals.push(await ensureProfessional(connection, tenant.id, professional));
    }

    const [allProfessionals] = await connection.query(
      `SELECT c.id, c.usuario_id, u.nome
         FROM colaboradores c
         JOIN usuarios u ON u.id = c.usuario_id
        WHERE c.barbearia_id = ? AND c.ativo = 1
        ORDER BY c.id`,
      [tenant.id],
    );
    const [services] = await connection.query(
      `SELECT id, nome, preco, duracao_min
         FROM servicos
        WHERE barbearia_id = ? AND ativo = 1
        ORDER BY id`,
      [tenant.id],
    );
    if (services.length === 0) throw new Error('Nenhum serviço local ativo encontrado.');

    const rules = [];
    for (const professional of allProfessionals) {
      rules.push({ professional: professional.nome, ...(await ensureRule(tenant.id, tenant.admin_id, professional)) });
    }

    const appointments = [];
    for (let index = 0; index < allProfessionals.length; index += 1) {
      const professional = allProfessionals[index];
      const service = services[index % services.length];
      appointments.push({
        professional: professional.nome,
        service: service.nome,
        ...(await ensureDemoAppointment({
          tenantId: tenant.id,
          actorId: tenant.admin_id,
          clientId: client.id,
          professional,
          service,
          daysAgo: index + 1,
        })),
      });
    }

    console.log(JSON.stringify({
      demoKey: DEMO_KEY,
      tenantId: tenant.id,
      professionals: allProfessionals.map((item) => ({ id: item.id, name: item.nome })),
      rules,
      appointments,
    }, null, 2));
  } finally {
    connection.release();
    await pool.end();
  }
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
