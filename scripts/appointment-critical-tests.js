#!/usr/bin/env node
'use strict';

const assert = require('node:assert/strict');
const bcrypt = require('bcryptjs');
const dotenv = require('dotenv');
const fs = require('fs/promises');
const mysql = require('mysql2/promise');
const path = require('path');

dotenv.config();

const ROOT = path.resolve(__dirname, '..');
const TEST_DATABASE = 'barbearia_appointment_critical_test';
const labelArgument = process.argv.find((item) => item.startsWith('--label='));
const RUN_LABEL = (labelArgument?.split('=')[1] || 'run').replace(/[^a-z0-9_-]/gi, '_');
const EVIDENCE_PATH = path.join(
  ROOT,
  'docs',
  'evidence',
  `APPOINTMENT_CRITICAL_API_DB_2026-08-19_${RUN_LABEL}.json`,
);

const host = process.env.DB_HOST || '127.0.0.1';
if (!['127.0.0.1', 'localhost', '::1'].includes(host.toLowerCase())) {
  throw new Error(`Safety stop: appointment tests require local MySQL; received host ${host}.`);
}

delete process.env.DATABASE_URL;
process.env.DB_HOST = host;
process.env.DB_NAME = TEST_DATABASE;
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'appointment-test-access-secret-32-characters';
process.env.JWT_REFRESH_SECRET = 'appointment-test-refresh-secret-32-characters';
process.env.JWT_EXPIRES_IN = '1h';
process.env.JWT_REFRESH_EXPIRES_IN = '1d';

const baseConfig = {
  host,
  port: Number(process.env.DB_PORT) || 3306,
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
};

const report = {
  schemaVersion: 1,
  runLabel: RUN_LABEL,
  startedAt: new Date().toISOString(),
  finishedAt: null,
  environment: {
    node: process.version,
    database: TEST_DATABASE,
    databaseHost: host,
    production: false,
    api: 'in-process Express server bound to 127.0.0.1 on an ephemeral port',
  },
  scope: 'Critical appointment API, persistence, cancellation and concurrency',
  command: `node scripts/appointment-critical-tests.js --label=${RUN_LABEL}`,
  results: [],
  summary: null,
  cleanup: {
    serverClosed: false,
    poolClosed: false,
    databaseDropped: false,
  },
};

let adminConnection;
let pool;
let server;
let baseUrl;

function formatDate(value) {
  const pad = (number) => String(number).padStart(2, '0');
  return `${value.getFullYear()}-${pad(value.getMonth() + 1)}-${pad(value.getDate())}`;
}

function dateTime(daysAhead, hour, minute = 0) {
  const value = new Date();
  value.setDate(value.getDate() + daysAhead);
  value.setHours(hour, minute, 0, 0);
  return `${formatDate(value)} ${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}:00`;
}

function datePart(value) {
  return value.substring(0, 10);
}

function timePart(value) {
  return value.substring(11, 16);
}

function publicResponse(response) {
  return { status: response.status, body: response.body };
}

function fail(message, actual) {
  const error = new assert.AssertionError({
    message,
    actual,
    expected: message,
    operator: 'critical invariant',
  });
  error.evidence = actual;
  throw error;
}

function expect(condition, message, actual) {
  if (!condition) fail(message, actual);
}

async function migrate(connection) {
  const directory = path.join(ROOT, 'migrations');
  const files = (await fs.readdir(directory)).filter((file) => file.endsWith('.sql')).sort();
  for (const file of files) {
    const sql = await fs.readFile(path.join(directory, file), 'utf8');
    for (const statement of sql.split(';').map((item) => item.trim()).filter(Boolean)) {
      await connection.query(statement);
    }
  }
  return files;
}

async function seed() {
  const passwordHash = await bcrypt.hash('QaAppointment123!', 10);
  const [users] = await pool.query(
    `INSERT INTO usuarios (nome,email,telefone,senha_hash,role,ativo) VALUES
      ('QA Appointment Admin A','qa-appointment-admin-a@getcutt.test','41983000001',?,'admin',1),
      ('QA Appointment Barber A','qa-appointment-barber-a@getcutt.test','41983000002',?,'barbeiro',1),
      ('QA Appointment Client A1','qa-appointment-client-a1@getcutt.test','41983000003',?,'cliente',1),
      ('QA Appointment Client A2','qa-appointment-client-a2@getcutt.test','41983000004',?,'cliente',1),
      ('QA Appointment Admin B','qa-appointment-admin-b@getcutt.test','41984000001',?,'admin',1),
      ('QA Appointment Barber B','qa-appointment-barber-b@getcutt.test','41984000002',?,'barbeiro',1),
      ('QA Appointment Client B','qa-appointment-client-b@getcutt.test','41984000003',?,'cliente',1)`,
    Array(7).fill(passwordHash),
  );
  const ids = {
    adminA: users.insertId,
    barberA: users.insertId + 1,
    clientA1: users.insertId + 2,
    clientA2: users.insertId + 3,
    adminB: users.insertId + 4,
    barberB: users.insertId + 5,
    clientB: users.insertId + 6,
  };
  const [shops] = await pool.query(
    `INSERT INTO barbearias (admin_id,nome,slug,telefone,email,onboarding_concluido,ativa) VALUES
      (?, 'QA Appointment Shop A','qa-appointment-shop-a','41983000100','qa-appointment-shop-a@getcutt.test',1,1),
      (?, 'QA Appointment Shop B','qa-appointment-shop-b','41984000100','qa-appointment-shop-b@getcutt.test',1,1)`,
    [ids.adminA, ids.adminB],
  );
  ids.shopA = shops.insertId;
  ids.shopB = shops.insertId + 1;
  await pool.query(
    `INSERT INTO memberships (barbearia_id,usuario_id,papel,ativo) VALUES
      (?,?,'owner',1),(?,?,'professional',1),(?,?,'owner',1),(?,?,'professional',1)`,
    [ids.shopA, ids.adminA, ids.shopA, ids.barberA, ids.shopB, ids.adminB, ids.shopB, ids.barberB],
  );
  const [barberA] = await pool.query(
    'INSERT INTO colaboradores (barbearia_id,usuario_id,ativo) VALUES (?,?,1)',
    [ids.shopA, ids.barberA],
  );
  const [barberB] = await pool.query(
    'INSERT INTO colaboradores (barbearia_id,usuario_id,ativo) VALUES (?,?,1)',
    [ids.shopB, ids.barberB],
  );
  ids.collaboratorA = barberA.insertId;
  ids.collaboratorB = barberB.insertId;
  const [servicesA] = await pool.query(
    `INSERT INTO servicos (barbearia_id,nome,descricao,preco,duracao_min,ativo) VALUES
      (?, 'QA Corte 45','Synthetic active service',40.00,45,1),
      (?, 'QA Barba 20','Synthetic active service',25.00,20,1),
      (?, 'QA Inativo','Synthetic inactive service',10.00,30,0)`,
    [ids.shopA, ids.shopA, ids.shopA],
  );
  const [serviceB] = await pool.query(
    `INSERT INTO servicos (barbearia_id,nome,descricao,preco,duracao_min,ativo)
     VALUES (?, 'QA Tenant B Service','Synthetic tenant B service',55.00,30,1)`,
    [ids.shopB],
  );
  ids.serviceA1 = servicesA.insertId;
  ids.serviceA2 = servicesA.insertId + 1;
  ids.inactiveServiceA = servicesA.insertId + 2;
  ids.serviceB = serviceB.insertId;
  for (const collaboratorId of [ids.collaboratorA, ids.collaboratorB]) {
    for (let weekday = 0; weekday <= 6; weekday += 1) {
      await pool.query(
        `INSERT INTO horarios_funcionamento
          (colaborador_id,dia_semana,hora_inicio,hora_fim,ativo)
         VALUES (?,?,?,?,1)`,
        [collaboratorId, weekday, '08:00', '20:00'],
      );
    }
  }
  return ids;
}

async function request(method, route, token, body) {
  const response = await fetch(`${baseUrl}${route}`, {
    method,
    headers: {
      ...(token ? { authorization: `Bearer ${token}` } : {}),
      ...(body === undefined ? {} : { 'content-type': 'application/json' }),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await response.text();
  let responseBody;
  try {
    responseBody = text ? JSON.parse(text) : null;
  } catch {
    responseBody = text;
  }
  return { status: response.status, body: responseBody };
}

async function login(email) {
  const response = await request('POST', '/api/auth/login', null, {
    login: email,
    senha: 'QaAppointment123!',
  });
  expect(response.status === 200, 'Login sintético deve retornar HTTP 200.', publicResponse(response));
  return response.body;
}

async function appointmentCount(where = '', params = []) {
  const [rows] = await pool.query(`SELECT COUNT(*) AS total FROM agendamentos ${where}`, params);
  return Number(rows[0].total);
}

async function runCase(definition, execute) {
  const startedAt = new Date().toISOString();
  const started = Date.now();
  try {
    const evidence = await execute();
    report.results.push({
      ...definition,
      status: 'passed',
      startedAt,
      durationMs: Date.now() - started,
      actualResult: definition.expectedResult,
      evidence,
      defectId: null,
      cleanup: 'covered by isolated database teardown',
    });
  } catch (error) {
    report.results.push({
      ...definition,
      status: 'failed',
      startedAt,
      durationMs: Date.now() - started,
      actualResult: error.message,
      evidence: error.evidence || { name: error.name, message: error.message },
      defectId: definition.defectId || 'DEF-AGD-TBD',
      cleanup: 'covered by isolated database teardown',
    });
  }
}

async function executeCases(ids) {
  const sessions = {
    adminA: await login('qa-appointment-admin-a@getcutt.test'),
    barberA: await login('qa-appointment-barber-a@getcutt.test'),
    clientA1: await login('qa-appointment-client-a1@getcutt.test'),
    clientA2: await login('qa-appointment-client-a2@getcutt.test'),
    clientB: await login('qa-appointment-client-b@getcutt.test'),
  };

  await runCase({
    id: 'APPT-API-001', catalogIds: ['AI-BOOK-02'], layer: ['api', 'database'],
    preconditions: 'Authenticated client; empty appointment table.',
    testData: 'Missing service, professional, date/time and empty service list.',
    expectedResult: 'Every missing-required-field request returns 400 and writes nothing.',
  }, async () => {
    const before = await appointmentCount();
    const cases = [
      {},
      { servico_id: ids.serviceA1, data_hora: dateTime(4, 10) },
      { colaborador_id: ids.collaboratorA, data_hora: dateTime(4, 10) },
      { colaborador_id: ids.collaboratorA, servico_id: ids.serviceA1 },
      { colaborador_id: ids.collaboratorA, servicos_ids: [], data_hora: dateTime(4, 10) },
    ];
    const responses = await Promise.all(cases.map((body) => request(
      'POST', '/api/agendamentos', sessions.clientA1.access_token, body,
    )));
    const after = await appointmentCount();
    expect(responses.every((item) => item.status === 400) && before === after,
      'Campos obrigatórios ausentes devem retornar 400 sem persistência.',
      { responses: responses.map(publicResponse), database: { before, after } });
    return { responses: responses.map(publicResponse), database: { before, after } };
  });

  await runCase({
    id: 'APPT-API-002', catalogIds: ['AI-BOOK-03', 'QA-E2E-027'], layer: ['api', 'database'],
    preconditions: 'Professional works daily from 08:00 to 20:00.',
    testData: 'Past appointment and appointment beginning before working hours.',
    expectedResult: 'Past/out-of-schedule reservations are rejected and not persisted.',
    defectId: 'DEF-AGD-001',
  }, async () => {
    const past = await request('POST', '/api/agendamentos', sessions.clientA1.access_token, {
      colaborador_id: ids.collaboratorA, servico_id: ids.serviceA1,
      data_hora: '2000-01-01 10:00:00',
    });
    const outsideDate = dateTime(4, 7);
    const outside = await request('POST', '/api/agendamentos', sessions.clientA1.access_token, {
      colaborador_id: ids.collaboratorA, servico_id: ids.serviceA1,
      data_hora: outsideDate,
    });
    const persisted = await appointmentCount('WHERE colaborador_id = ? AND data_hora = ?', [ids.collaboratorA, outsideDate]);
    const evidence = { past: publicResponse(past), outsideSchedule: publicResponse(outside), database: { persisted } };
    expect(past.status === 400 && [400, 409].includes(outside.status) && persisted === 0,
      'Backend deve recusar reserva fora do expediente, além de datas passadas.', evidence);
    return evidence;
  });

  await runCase({
    id: 'APPT-API-003', catalogIds: ['AI-BOOK-05'], layer: ['api', 'database'],
    preconditions: 'Protected appointment route.',
    testData: 'No token and malformed token.',
    expectedResult: 'Both calls return 401 and create no appointment.',
  }, async () => {
    const before = await appointmentCount();
    const body = { colaborador_id: ids.collaboratorA, servico_id: ids.serviceA1, data_hora: dateTime(4, 9) };
    const missing = await request('POST', '/api/agendamentos', null, body);
    const invalid = await request('POST', '/api/agendamentos', 'invalid.jwt.value', body);
    const after = await appointmentCount();
    const evidence = { missing: publicResponse(missing), invalid: publicResponse(invalid), database: { before, after } };
    expect(missing.status === 401 && invalid.status === 401 && before === after,
      'Token ausente/inválido deve ser recusado sem escrita.', evidence);
    return evidence;
  });

  await runCase({
    id: 'APPT-API-004', catalogIds: ['AI-BOOK-06'], layer: ['api', 'database'],
    preconditions: 'Valid admin and barber sessions.',
    testData: 'Admin and barber call client-only POST /agendamentos.',
    expectedResult: 'Both forbidden roles return 403 and create no appointment.',
  }, async () => {
    const before = await appointmentCount();
    const body = { colaborador_id: ids.collaboratorA, servico_id: ids.serviceA1, data_hora: dateTime(4, 9, 30) };
    const responses = await Promise.all([
      request('POST', '/api/agendamentos', sessions.adminA.access_token, body),
      request('POST', '/api/agendamentos', sessions.barberA.access_token, body),
    ]);
    const after = await appointmentCount();
    const evidence = { responses: responses.map(publicResponse), database: { before, after } };
    expect(responses.every((item) => item.status === 403) && before === after,
      'Perfis não clientes devem receber 403 sem escrita.', evidence);
    return evidence;
  });

  await runCase({
    id: 'APPT-API-005', catalogIds: ['AI-BOOK-07'], layer: ['api', 'database', 'tenant_isolation'],
    preconditions: 'Tenants A and B contain distinct professional/service IDs.',
    testData: 'Professional A with service B and professional B with service A.',
    expectedResult: 'Cross-tenant resource combinations are rejected without writes or disclosure.',
  }, async () => {
    const before = await appointmentCount();
    const responses = await Promise.all([
      request('POST', '/api/agendamentos', sessions.clientA1.access_token, {
        colaborador_id: ids.collaboratorA, servico_id: ids.serviceB, data_hora: dateTime(4, 12),
      }),
      request('POST', '/api/agendamentos', sessions.clientA1.access_token, {
        colaborador_id: ids.collaboratorB, servico_id: ids.serviceA1, data_hora: dateTime(4, 12),
      }),
    ]);
    const after = await appointmentCount();
    const evidence = { responses: responses.map(publicResponse), database: { before, after } };
    expect(responses.every((item) => [403, 404].includes(item.status)) && before === after,
      'Combinações entre tenants devem ser recusadas sem escrita.', evidence);
    return evidence;
  });

  await runCase({
    id: 'APPT-API-006', catalogIds: ['QA-E2E-035', 'QA-E2E-042'], layer: ['api', 'database'],
    preconditions: 'Inactive service exists; active professional can be deactivated for an isolated call.',
    testData: 'Inactive service and inactive professional.',
    expectedResult: 'Inactive resources cannot receive new reservations and no appointment is written.',
  }, async () => {
    const before = await appointmentCount();
    const inactiveService = await request('POST', '/api/agendamentos', sessions.clientA1.access_token, {
      colaborador_id: ids.collaboratorA, servico_id: ids.inactiveServiceA, data_hora: dateTime(4, 13),
    });
    await pool.query('UPDATE colaboradores SET ativo = 0 WHERE id = ?', [ids.collaboratorA]);
    const inactiveProfessional = await request('POST', '/api/agendamentos', sessions.clientA1.access_token, {
      colaborador_id: ids.collaboratorA, servico_id: ids.serviceA1, data_hora: dateTime(4, 14),
    });
    await pool.query('UPDATE colaboradores SET ativo = 1 WHERE id = ?', [ids.collaboratorA]);
    const after = await appointmentCount();
    const evidence = {
      inactiveService: publicResponse(inactiveService),
      inactiveProfessional: publicResponse(inactiveProfessional),
      database: { before, after },
    };
    expect([403, 404].includes(inactiveService.status) && [403, 404].includes(inactiveProfessional.status) && before === after,
      'Serviço/profissional inativo deve ser recusado sem escrita.', evidence);
    return evidence;
  });

  let happyAppointmentId;
  const happyDate = dateTime(4, 10);
  await runCase({
    id: 'APPT-API-007', catalogIds: ['AI-BOOK-01', 'QA-E2E-030', 'QA-E2E-031'], layer: ['api', 'database'],
    preconditions: 'Active client, professional, two services and free future slot.',
    testData: 'Two services totaling BRL 65.00 and 65 minutes.',
    expectedResult: 'One confirmed appointment and two snapshot service rows are committed atomically.',
  }, async () => {
    const response = await request('POST', '/api/agendamentos', sessions.clientA1.access_token, {
      colaborador_id: ids.collaboratorA,
      servico_id: ids.serviceA1,
      servicos_ids: [ids.serviceA1, ids.serviceA2],
      data_hora: happyDate,
    });
    happyAppointmentId = response.body?.id;
    const [appointments] = await pool.query(
      `SELECT id, cliente_id, colaborador_id, servico_id, data_hora, duracao_min, valor_cobrado, status
         FROM agendamentos WHERE id = ?`,
      [happyAppointmentId || 0],
    );
    const [services] = await pool.query(
      `SELECT servico_id, preco_cobrado, duracao_min
         FROM agendamento_servicos WHERE agendamento_id = ? ORDER BY servico_id`,
      [happyAppointmentId || 0],
    );
    const [notifications] = await pool.query(
      'SELECT tipo, COUNT(*) AS total FROM notificacoes WHERE agendamento_id = ? GROUP BY tipo ORDER BY tipo',
      [happyAppointmentId || 0],
    );
    const evidence = { response: publicResponse(response), database: { appointments, services, notifications } };
    expect(response.status === 201 && appointments.length === 1 && services.length === 2 &&
      Number(appointments[0].duracao_min) === 65 && Number(appointments[0].valor_cobrado) === 65 &&
      appointments[0].status === 'confirmado',
    'Agendamento multi-serviço deve persistir um registro e snapshots totalizando 65/65.', evidence);
    return evidence;
  });

  await runCase({
    id: 'APPT-API-008', catalogIds: ['AI-BOOK-11', 'QA-E2E-003'], layer: ['api', 'database', 'session'],
    preconditions: 'Multi-service appointment committed by client A1.',
    testData: 'Fresh reads, logout, fresh login and barber agenda read.',
    expectedResult: 'Appointment remains visible to client and barber after logout/login and fresh database query.',
  }, async () => {
    const clientAgenda = await request('GET', '/api/agendamentos/meus?tipo=agenda', sessions.clientA1.access_token);
    const barberAgenda = await request('GET', `/api/agendamentos/barbeiro/${ids.collaboratorA}`, sessions.barberA.access_token);
    const logout = await request('POST', '/api/auth/logout', null, { refresh_token: sessions.clientA1.refresh_token });
    const relogin = await login('qa-appointment-client-a1@getcutt.test');
    const agendaAfterRelogin = await request('GET', '/api/agendamentos/meus?tipo=agenda', relogin.access_token);
    sessions.clientA1 = relogin;
    const [freshRows] = await pool.query('SELECT id, status FROM agendamentos WHERE id = ?', [happyAppointmentId || 0]);
    const hasId = (response) => Array.isArray(response.body) && response.body.some((item) => item.id === happyAppointmentId);
    const evidence = {
      clientAgenda: publicResponse(clientAgenda), barberAgenda: publicResponse(barberAgenda),
      logout: publicResponse(logout), agendaAfterRelogin: publicResponse(agendaAfterRelogin),
      database: freshRows,
    };
    expect([clientAgenda, barberAgenda, agendaAfterRelogin].every((item) => item.status === 200) &&
      hasId(clientAgenda) && hasId(barberAgenda) && hasId(agendaAfterRelogin) && freshRows[0]?.status === 'confirmado',
    'Reserva deve persistir em leituras novas e após logout/login.', evidence);
    return evidence;
  });

  await runCase({
    id: 'APPT-API-009', catalogIds: ['QA-E2E-002', 'QA-E2E-021'], layer: ['api', 'database'],
    preconditions: 'Future confirmed appointment more than one hour away.',
    testData: 'Client cancellation followed by agenda/history/availability reads.',
    expectedResult: 'Status becomes canceled, active agenda loses it, history gains it and slot is released.',
  }, async () => {
    const cancellation = await request('PATCH', `/api/agendamentos/${happyAppointmentId}/cancelar`, sessions.clientA1.access_token, {});
    const active = await request('GET', '/api/agendamentos/meus?tipo=agenda', sessions.clientA1.access_token);
    const history = await request('GET', '/api/agendamentos/meus?tipo=historico', sessions.clientA1.access_token);
    const availability = await request(
      'GET',
      `/api/agenda/disponiveis/${ids.collaboratorA}?data=${datePart(happyDate)}&duracao_total=65`,
      sessions.clientA2.access_token,
    );
    const [database] = await pool.query('SELECT id, status FROM agendamentos WHERE id = ?', [happyAppointmentId || 0]);
    const activeHas = Array.isArray(active.body) && active.body.some((item) => item.id === happyAppointmentId);
    const historyHas = Array.isArray(history.body) && history.body.some((item) => item.id === happyAppointmentId && item.status === 'cancelado');
    const slotFree = Array.isArray(availability.body?.disponiveis) && availability.body.disponiveis.includes(timePart(happyDate));
    const evidence = {
      cancellation: publicResponse(cancellation), activeAgenda: publicResponse(active),
      history: publicResponse(history), availability: publicResponse(availability), database,
    };
    expect(cancellation.status === 200 && database[0]?.status === 'cancelado' && !activeHas && historyHas && slotFree,
      'Cancelamento deve persistir, mover para histórico e liberar o slot.', evidence);
    return evidence;
  });

  await runCase({
    id: 'APPT-API-010', catalogIds: ['QA-E2E-018'], layer: ['api', 'database'],
    preconditions: 'Appointment is already canceled.',
    testData: 'Repeat cancellation through API.',
    expectedResult: 'Repeat is rejected deterministically and creates no additional cancellation notification.',
  }, async () => {
    const [[before]] = await pool.query(
      `SELECT COUNT(*) AS total FROM notificacoes
        WHERE agendamento_id = ? AND tipo = 'cancelamento'`,
      [happyAppointmentId || 0],
    );
    const response = await request('PATCH', `/api/agendamentos/${happyAppointmentId}/cancelar`, sessions.clientA1.access_token, {});
    const [[after]] = await pool.query(
      `SELECT COUNT(*) AS total FROM notificacoes
        WHERE agendamento_id = ? AND tipo = 'cancelamento'`,
      [happyAppointmentId || 0],
    );
    const evidence = { response: publicResponse(response), database: { before: Number(before.total), after: Number(after.total) } };
    expect([400, 409].includes(response.status) && Number(before.total) === Number(after.total),
      'Cancelamento repetido deve ser recusado sem notificação duplicada.', evidence);
    return evidence;
  });

  const concurrentDate = dateTime(5, 11);
  let winningAppointmentId;
  await runCase({
    id: 'APPT-API-011', catalogIds: ['AI-BOOK-08', 'QA-E2E-022'], layer: ['api', 'database', 'concurrency'],
    preconditions: 'Two authenticated clients and one free last slot.',
    testData: 'Synchronized requests for the same professional, date and 45-minute interval.',
    expectedResult: 'Exactly one 201 and one deterministic 409; database has one active reservation and no finance entry.',
  }, async () => {
    const body = { colaborador_id: ids.collaboratorA, servico_id: ids.serviceA1, data_hora: concurrentDate };
    const responses = await Promise.all([
      request('POST', '/api/agendamentos', sessions.clientA1.access_token, body),
      request('POST', '/api/agendamentos', sessions.clientA2.access_token, body),
    ]);
    const winner = responses.find((item) => item.status === 201);
    winningAppointmentId = winner?.body?.id;
    const [database] = await pool.query(
      `SELECT id, cliente_id, status FROM agendamentos
        WHERE colaborador_id = ? AND data_hora = ? AND status IN ('confirmado','pendente')`,
      [ids.collaboratorA, concurrentDate],
    );
    const [[finance]] = await pool.query(
      `SELECT COUNT(*) AS total FROM cash_entries
        WHERE appointment_id IN (SELECT id FROM agendamentos WHERE colaborador_id = ? AND data_hora = ?)`,
      [ids.collaboratorA, concurrentDate],
    );
    const availability = await request(
      'GET',
      `/api/agenda/disponiveis/${ids.collaboratorA}?data=${datePart(concurrentDate)}&duracao_total=45`,
      sessions.clientA1.access_token,
    );
    const statuses = responses.map((item) => item.status).sort((a, b) => a - b);
    const loser = responses.find((item) => item.status === 409);
    const slotUnavailable = Array.isArray(availability.body?.disponiveis) && !availability.body.disponiveis.includes(timePart(concurrentDate));
    const evidence = {
      responses: responses.map(publicResponse), database,
      financeEntries: Number(finance.total), availability: publicResponse(availability),
    };
    expect(statuses[0] === 201 && statuses[1] === 409 && loser?.body?.code === 'APPOINTMENT_CONFLICT' &&
      database.length === 1 && Number(finance.total) === 0 && slotUnavailable,
    'Concorrência deve criar exatamente uma reserva, conflito determinístico e nenhum lançamento financeiro.', evidence);
    return evidence;
  });

  await runCase({
    id: 'APPT-API-012', catalogIds: ['AI-BOOK-09'], layer: ['api', 'database', 'idempotency'],
    preconditions: 'The concurrent slot already contains exactly one active appointment.',
    testData: 'Immediate retry of the same request by the winning client.',
    expectedResult: 'Retry returns deterministic conflict or prior result and does not create another appointment/notification.',
  }, async () => {
    const [winnerRows] = await pool.query('SELECT cliente_id FROM agendamentos WHERE id = ?', [winningAppointmentId || 0]);
    const winnerToken = winnerRows[0]?.cliente_id === ids.clientA1
      ? sessions.clientA1.access_token : sessions.clientA2.access_token;
    const [[notificationsBefore]] = await pool.query(
      `SELECT COUNT(*) AS total FROM notificacoes
        WHERE agendamento_id = ? AND tipo = 'confirmacao'`,
      [winningAppointmentId || 0],
    );
    const retry = await request('POST', '/api/agendamentos', winnerToken, {
      colaborador_id: ids.collaboratorA, servico_id: ids.serviceA1, data_hora: concurrentDate,
    });
    const count = await appointmentCount(
      `WHERE colaborador_id = ? AND data_hora = ? AND status IN ('confirmado','pendente')`,
      [ids.collaboratorA, concurrentDate],
    );
    const [[notificationsAfter]] = await pool.query(
      `SELECT COUNT(*) AS total FROM notificacoes
        WHERE agendamento_id = ? AND tipo = 'confirmacao'`,
      [winningAppointmentId || 0],
    );
    const evidence = {
      retry: publicResponse(retry), database: { activeAppointments: count },
      notifications: { before: Number(notificationsBefore.total), after: Number(notificationsAfter.total) },
    };
    expect([200, 201, 409].includes(retry.status) && count === 1 &&
      Number(notificationsBefore.total) === Number(notificationsAfter.total),
    'Retry não pode duplicar reserva nem efeitos colaterais.', evidence);
    return evidence;
  });

  const cancellationRaceDate = dateTime(6, 13);
  let cancellationRaceId;
  await runCase({
    id: 'APPT-API-013-SETUP', catalogIds: ['AI-BOOK-01'], layer: ['api', 'database'],
    preconditions: 'Free isolated slot for cancellation concurrency setup.',
    testData: 'Single-service appointment.',
    expectedResult: 'Setup appointment is committed once.',
  }, async () => {
    const response = await request('POST', '/api/agendamentos', sessions.clientA1.access_token, {
      colaborador_id: ids.collaboratorA, servico_id: ids.serviceA1, data_hora: cancellationRaceDate,
    });
    cancellationRaceId = response.body?.id;
    const count = await appointmentCount('WHERE id = ?', [cancellationRaceId || 0]);
    const evidence = { response: publicResponse(response), database: { count } };
    expect(response.status === 201 && count === 1, 'Setup para corrida de cancelamento deve criar uma reserva.', evidence);
    return evidence;
  });

  await runCase({
    id: 'APPT-API-013', catalogIds: ['QA-E2E-018'], layer: ['api', 'database', 'concurrency'],
    preconditions: 'One confirmed appointment and no cancellation notification.',
    testData: 'Two simultaneous PATCH cancellation requests from the owning client.',
    expectedResult: 'Exactly one cancellation succeeds; one is rejected; status changes once and only one notification exists.',
    defectId: 'DEF-AGD-002',
  }, async () => {
    const responses = await Promise.all([
      request('PATCH', `/api/agendamentos/${cancellationRaceId}/cancelar`, sessions.clientA1.access_token, {}),
      request('PATCH', `/api/agendamentos/${cancellationRaceId}/cancelar`, sessions.clientA1.access_token, {}),
    ]);
    const [database] = await pool.query('SELECT id, status FROM agendamentos WHERE id = ?', [cancellationRaceId || 0]);
    const [[notifications]] = await pool.query(
      `SELECT COUNT(*) AS total FROM notificacoes
        WHERE agendamento_id = ? AND tipo = 'cancelamento'`,
      [cancellationRaceId || 0],
    );
    const successful = responses.filter((item) => item.status === 200).length;
    const rejected = responses.filter((item) => [400, 409].includes(item.status)).length;
    const evidence = { responses: responses.map(publicResponse), database, cancellationNotifications: Number(notifications.total) };
    expect(successful === 1 && rejected === 1 && database[0]?.status === 'cancelado' && Number(notifications.total) === 1,
      'Cancelamento concorrente deve ter uma única transição e notificação.', evidence);
    return evidence;
  });
}

async function main() {
  let infrastructureError = null;
  try {
    adminConnection = await mysql.createConnection(baseConfig);
    await adminConnection.query(`DROP DATABASE IF EXISTS \`${TEST_DATABASE}\``);
    await adminConnection.query(
      `CREATE DATABASE \`${TEST_DATABASE}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`,
    );
    const migrationConnection = await mysql.createConnection({ ...baseConfig, database: TEST_DATABASE });
    const migrations = await migrate(migrationConnection);
    await migrationConnection.end();
    report.environment.migrations = migrations;

    const database = require('../src/config/database');
    pool = database.pool;
    const ids = await seed();
    const app = require('../app');
    server = await new Promise((resolve) => {
      const instance = app.listen(0, '127.0.0.1', () => resolve(instance));
    });
    baseUrl = `http://127.0.0.1:${server.address().port}`;
    await executeCases(ids);
  } catch (error) {
    infrastructureError = { name: error.name, message: error.message };
    report.infrastructureError = infrastructureError;
    process.exitCode = 1;
  } finally {
    if (server) {
      await new Promise((resolve) => server.close(resolve));
      report.cleanup.serverClosed = true;
    }
    if (pool) {
      await pool.end();
      report.cleanup.poolClosed = true;
    }
    if (adminConnection) {
      try {
        await adminConnection.query(`DROP DATABASE IF EXISTS \`${TEST_DATABASE}\``);
        report.cleanup.databaseDropped = true;
      } finally {
        await adminConnection.end();
      }
    }

    report.finishedAt = new Date().toISOString();
    const statuses = report.results.reduce((counts, item) => {
      counts[item.status] = (counts[item.status] || 0) + 1;
      return counts;
    }, { passed: 0, failed: 0 });
    report.summary = { total: report.results.length, ...statuses };
    await fs.mkdir(path.dirname(EVIDENCE_PATH), { recursive: true });
    await fs.writeFile(EVIDENCE_PATH, JSON.stringify(report, null, 2));
    console.log(JSON.stringify({ evidence: EVIDENCE_PATH, summary: report.summary, cleanup: report.cleanup, infrastructureError }, null, 2));
    if (report.summary.failed > 0) process.exitCode = 1;
  }
}

main();
