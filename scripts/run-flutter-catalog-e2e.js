#!/usr/bin/env node
'use strict';

require('dotenv').config();
const fs = require('fs/promises');
const path = require('path');
const { spawn } = require('child_process');
const mysql = require('mysql2/promise');
const bcrypt = require('bcryptjs');

const ROOT = path.resolve(__dirname, '..');
const APP_DIR = path.join(ROOT, 'app');
const TEST_DATABASE = 'barbearia_flutter_e2e_test';
const evidenceLabelArgument = process.argv.find(item => item.startsWith('--evidence-label='));
const evidenceLabel = evidenceLabelArgument
  ? `_${evidenceLabelArgument.split('=')[1].replace(/[^a-z0-9_-]/gi, '_')}`
  : '';
const APPOINTMENT_EVIDENCE = path.join(ROOT, 'docs', 'evidence', `APPOINTMENT_FLUTTER_E2E_2026-08-19${evidenceLabel}.json`);
const APPOINTMENT_LOG = path.join(ROOT, 'docs', 'evidence', `APPOINTMENT_FLUTTER_E2E_2026-08-19${evidenceLabel}.log`);
const databaseHost = process.env.DB_HOST || '127.0.0.1';
if (!['127.0.0.1', 'localhost', '::1'].includes(databaseHost.toLowerCase())) {
  throw new Error(`Safety stop: Flutter E2E requires local MySQL; received host ${databaseHost}.`);
}
const baseConfig = {
  host: databaseHost,
  port: Number(process.env.DB_PORT) || 3306,
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
};

async function migrate(connection) {
  const directory = path.join(ROOT, 'migrations');
  const files = (await fs.readdir(directory)).filter(file => file.endsWith('.sql')).sort();
  for (const file of files) {
    const sql = await fs.readFile(path.join(directory, file), 'utf8');
    for (const statement of sql.split(';').map(item => item.trim()).filter(Boolean)) await connection.query(statement);
  }
}

async function seed(pool) {
  const hash = await bcrypt.hash('QaSenha123!', 10);
  const [users] = await pool.query(
    `INSERT INTO usuarios (nome,email,telefone,senha_hash,role,ativo) VALUES
      ('QA Admin A','qa-admin-a@getcutt.test','41981000001',?,'admin',1),
      ('QA Barbeiro A','qa-barber-a@getcutt.test','41981000002',?,'barbeiro',1),
      ('QA Cliente A','qa-client-a@getcutt.test','41981000003',?,'cliente',1),
      ('QA Admin B','qa-admin-b@getcutt.test','41982000001',?,'admin',1),
      ('QA Barbeiro B','qa-barber-b@getcutt.test','41982000002',?,'barbeiro',1),
      ('QA Cliente B','qa-client-b@getcutt.test','41982000003',?,'cliente',1)`,
    [hash, hash, hash, hash, hash, hash],
  );
  const [shops] = await pool.query(
    `INSERT INTO barbearias (admin_id,nome,slug,telefone,email,onboarding_concluido,ativa) VALUES
      (?, 'QA Barbearia A','qa-barbearia-a','41981000100','qa-shop-a@getcutt.test',1,1),
      (?, 'QA Barbearia B','qa-barbearia-b','41982000100','qa-shop-b@getcutt.test',1,1)`,
    [users.insertId, users.insertId + 3],
  );
  const userA = users.insertId;
  const userB = users.insertId + 3;
  const shopA = shops.insertId;
  const shopB = shops.insertId + 1;
  await pool.query(
    `INSERT INTO memberships (barbearia_id,usuario_id,papel,ativo) VALUES
      (?,?,'owner',1),(?,?,'professional',1),(?,?,'owner',1),(?,?,'professional',1)`,
    [shopA, userA, shopA, userA + 1, shopB, userB, shopB, userB + 1],
  );
  const [staffA] = await pool.query('INSERT INTO colaboradores (barbearia_id,usuario_id,ativo) VALUES (?,?,1)', [shopA, userA + 1]);
  const [staffB] = await pool.query('INSERT INTO colaboradores (barbearia_id,usuario_id,ativo) VALUES (?,?,1)', [shopB, userB + 1]);
  const [services] = await pool.query(
    `INSERT INTO servicos (barbearia_id,nome,descricao,preco,duracao_min,ativo) VALUES
      (?, 'QA Corte A','Serviço isolado A',40,45,1),
      (?, 'QA Barba A','Serviço isolado A',25,20,1),
      (?, 'QA Corte B','Serviço isolado B',45,30,1)`,
    [shopA, shopA, shopB],
  );
  for (const collaboratorId of [staffA.insertId, staffB.insertId]) {
    for (let day = 0; day <= 6; day += 1) {
      await pool.query('INSERT INTO horarios_funcionamento (colaborador_id,dia_semana,hora_inicio,hora_fim,ativo) VALUES (?,?,?,?,1)', [collaboratorId, day, '08:00', '20:00']);
    }
  }
  return {
    shopA,
    shopB,
    userA,
    userB,
    clientA: userA + 2,
    barberA: userA + 1,
    collaboratorA: staffA.insertId,
    serviceA1: services.insertId,
  };
}

function runChild(command, args, options) {
  return new Promise((resolve, reject) => {
    const { timeout, captureOutput, ...spawnOptions } = options;
    const child = spawn(command, args, spawnOptions);
    const chunks = [];
    if (captureOutput) {
      child.stdout.on('data', chunk => {
        process.stdout.write(chunk);
        chunks.push(chunk.toString());
      });
      child.stderr.on('data', chunk => {
        process.stderr.write(chunk);
        chunks.push(chunk.toString());
      });
    }
    const timer = setTimeout(() => {
      child.kill();
      reject(new Error(`Command timed out after ${timeout}ms: ${command}`));
    }, timeout);
    child.once('error', error => {
      clearTimeout(timer);
      reject(error);
    });
    child.once('exit', (code, signal) => {
      clearTimeout(timer);
      resolve({ status: code, signal, output: chunks.join('') });
    });
  });
}

async function apiCall(apiUrl, method, route, token, body) {
  const response = await fetch(`${apiUrl}${route}`, {
    method,
    headers: {
      ...(token ? { authorization: `Bearer ${token}` } : {}),
      ...(body === undefined ? {} : { 'content-type': 'application/json' }),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await response.text();
  let data;
  try { data = text ? JSON.parse(text) : null; } catch { data = text; }
  return { status: response.status, body: data };
}

async function appointmentEvidence(pool, apiUrl, seedData) {
  const [appointments] = await pool.query(
    `SELECT id, cliente_id, colaborador_id, servico_id, data_hora, duracao_min,
            valor_cobrado, status
       FROM agendamentos WHERE cliente_id = ? ORDER BY id`,
    [seedData.clientA],
  );
  const appointmentId = appointments[0]?.id || 0;
  const [serviceSnapshots] = await pool.query(
    `SELECT servico_id, preco_cobrado, duracao_min
       FROM agendamento_servicos WHERE agendamento_id = ? ORDER BY servico_id`,
    [appointmentId],
  );
  const [notifications] = await pool.query(
    `SELECT tipo, COUNT(*) AS total FROM notificacoes
      WHERE agendamento_id = ? GROUP BY tipo ORDER BY tipo`,
    [appointmentId],
  );
  const [[finance]] = await pool.query(
    'SELECT COUNT(*) AS total FROM cash_entries WHERE appointment_id = ?',
    [appointmentId],
  );
  const login = await apiCall(apiUrl, 'POST', '/auth/login', null, {
    login: 'qa-client-a@getcutt.test', senha: 'QaSenha123!',
  });
  const clientAgenda = await apiCall(apiUrl, 'GET', '/agendamentos/meus?tipo=agenda', login.body?.access_token);
  const clientHistory = await apiCall(apiUrl, 'GET', '/agendamentos/meus?tipo=historico', login.body?.access_token);
  const appointmentDate = String(appointments[0]?.data_hora || '').substring(0, 10);
  const appointmentTime = String(appointments[0]?.data_hora || '').substring(11, 16);
  const availability = appointmentDate
    ? await apiCall(
      apiUrl,
      'GET',
      `/agenda/disponiveis/${seedData.collaboratorA}?data=${appointmentDate}&duracao_total=65`,
      login.body?.access_token,
    )
    : { status: 0, body: null };
  const cancellationNotifications = notifications.find(item => item.tipo === 'cancelamento');
  const confirmationNotifications = notifications.find(item => item.tipo === 'confirmacao');
  const errors = [];
  if (appointments.length !== 1) errors.push(`expected one appointment, found ${appointments.length}`);
  if (appointments[0]?.status !== 'cancelado') errors.push(`expected canceled status, found ${appointments[0]?.status}`);
  if (Number(appointments[0]?.duracao_min) !== 65) errors.push(`expected duration 65, found ${appointments[0]?.duracao_min}`);
  if (Number(appointments[0]?.valor_cobrado) !== 65) errors.push(`expected amount 65.00, found ${appointments[0]?.valor_cobrado}`);
  if (serviceSnapshots.length !== 2) errors.push(`expected two service snapshots, found ${serviceSnapshots.length}`);
  if (Number(cancellationNotifications?.total) !== 1) errors.push(`expected one cancellation notification, found ${cancellationNotifications?.total || 0}`);
  if (Number(confirmationNotifications?.total) !== 1) errors.push(`expected one confirmation notification, found ${confirmationNotifications?.total || 0}`);
  if (Number(finance.total) !== 0) errors.push(`expected no financial entry, found ${finance.total}`);
  if (clientAgenda.status !== 200 || !Array.isArray(clientAgenda.body) || clientAgenda.body.length !== 0) {
    errors.push('active client agenda is not empty after cancellation');
  }
  if (clientHistory.status !== 200 || !Array.isArray(clientHistory.body) ||
      !clientHistory.body.some(item => item.id === appointmentId && item.status === 'cancelado')) {
    errors.push('canceled appointment is missing from client history');
  }
  if (availability.status !== 200 || !availability.body?.disponiveis?.includes(appointmentTime)) {
    errors.push('canceled slot was not released in availability API');
  }
  return {
    status: errors.length === 0 ? 'passed' : 'failed',
    errors,
    database: { appointments, serviceSnapshots, notifications, financeEntries: Number(finance.total) },
    api: {
      loginStatus: login.status,
      clientAgenda: { status: clientAgenda.status, count: Array.isArray(clientAgenda.body) ? clientAgenda.body.length : null },
      clientHistory: { status: clientHistory.status, containsCanceledAppointment: Array.isArray(clientHistory.body) && clientHistory.body.some(item => item.id === appointmentId && item.status === 'cancelado') },
      availability: { status: availability.status, releasedSlot: appointmentTime, available: availability.body?.disponiveis?.includes(appointmentTime) === true },
    },
  };
}

async function main() {
  process.env.DB_NAME = TEST_DATABASE;
  process.env.JWT_SECRET = 'flutter-e2e-access-secret-32-characters-minimum';
  process.env.JWT_REFRESH_SECRET = 'flutter-e2e-refresh-secret-32-characters-minimum';
  process.env.NODE_ENV = 'test';
  delete process.env.DATABASE_URL;

  const appointmentMode = process.argv.includes('--appointment-flow');
  let admin;
  let pool;
  let server;
  let chromeDriver;
  let flutterResult;
  let seedData;
  let infrastructureError;
  const cleanup = { chromeDriverStopped: false, serverClosed: false, poolClosed: false, databaseDropped: false };
  try {
    admin = await mysql.createConnection(baseConfig);
    await admin.query(`DROP DATABASE IF EXISTS \`${TEST_DATABASE}\``);
    await admin.query(`CREATE DATABASE \`${TEST_DATABASE}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`);
    const migrationConnection = await mysql.createConnection({ ...baseConfig, database: TEST_DATABASE });
    try {
      await migrate(migrationConnection);
    } finally {
      await migrationConnection.end();
    }
    const database = require('../src/config/database');
    pool = database.pool;
    seedData = await seed(pool);
    const app = require('../app');
    server = await new Promise(resolve => {
      const instance = app.listen(0, '127.0.0.1', () => resolve(instance));
    });
    if (process.env.CHROMEDRIVER_PATH) {
      chromeDriver = spawn(process.env.CHROMEDRIVER_PATH, ['--port=4444'], {
        stdio: 'ignore', windowsHide: true,
      });
      await new Promise((resolve, reject) => {
        const timer = setTimeout(resolve, 1500);
        chromeDriver.once('error', error => { clearTimeout(timer); reject(error); });
        chromeDriver.once('exit', code => {
          if (code !== null && code !== 0) { clearTimeout(timer); reject(new Error(`ChromeDriver exited early with ${code}`)); }
        });
      });
    }
    const apiUrl = `http://127.0.0.1:${server.address().port}/api`;
    const flutterArgs = [
      'drive', '--driver=test_driver/integration_test.dart',
      '--target=integration_test/catalog_e2e_test.dart', '-d', 'chrome',
      `--dart-define=API_BASE_URL=${apiUrl}`,
    ];
    if (process.argv.includes('--login-only')) {
      flutterArgs.push('--dart-define=E2E_ONLY_LOGIN=true');
    }
    if (process.argv.includes('--button-audit')) {
      flutterArgs.push('--dart-define=E2E_BUTTON_AUDIT=true');
    }
    if (appointmentMode) {
      flutterArgs.push('--dart-define=E2E_APPOINTMENT_FLOW=true');
    }
    const command = process.platform === 'win32' ? process.env.ComSpec || 'cmd.exe' : 'flutter';
    const args = process.platform === 'win32' ? ['/d', '/s', '/c', 'flutter', ...flutterArgs] : flutterArgs;
    flutterResult = await runChild(command, args, {
      cwd: APP_DIR,
      stdio: ['ignore', 'pipe', 'pipe'],
      captureOutput: true,
      timeout: 600000,
      windowsHide: true,
    });
    if (appointmentMode) {
      const apiDatabaseEvidence = await appointmentEvidence(pool, apiUrl, seedData);
      if (apiDatabaseEvidence.status !== 'passed') process.exitCode = 1;
      flutterResult.apiDatabaseEvidence = apiDatabaseEvidence;
    }
    if (flutterResult.status !== 0) process.exitCode = flutterResult.status ?? 1;
  } catch (error) {
    infrastructureError = { name: error.name, message: error.message };
    console.error(error.stack || error.message);
    process.exitCode = 1;
  } finally {
    if (chromeDriver && !chromeDriver.killed) {
      chromeDriver.kill();
      cleanup.chromeDriverStopped = true;
    }
    if (server) {
      await new Promise(resolve => server.close(resolve));
      cleanup.serverClosed = true;
    }
    if (pool) {
      await pool.end();
      cleanup.poolClosed = true;
    }
    if (admin) {
      try {
        await admin.query(`DROP DATABASE IF EXISTS \`${TEST_DATABASE}\``);
        cleanup.databaseDropped = true;
      } finally {
        await admin.end();
      }
    }
    if (appointmentMode) {
      await fs.mkdir(path.dirname(APPOINTMENT_EVIDENCE), { recursive: true });
      const log = flutterResult?.output || (infrastructureError ? infrastructureError.message : 'No Flutter output captured.');
      await fs.writeFile(APPOINTMENT_LOG, log);
      const apiDatabaseEvidence = flutterResult?.apiDatabaseEvidence || null;
      const passed = flutterResult?.status === 0 && apiDatabaseEvidence?.status === 'passed' && !infrastructureError;
      const evidence = {
        schemaVersion: 1,
        generatedAt: new Date().toISOString(),
        catalogIds: ['QA-E2E-002', 'QA-E2E-003', 'QA-E2E-018', 'QA-E2E-021', 'QA-E2E-030', 'QA-E2E-031'],
        environment: { database: TEST_DATABASE, databaseHost, production: false, browser: 'Chrome via flutter drive', api: '127.0.0.1 ephemeral port' },
        command: 'node scripts/run-flutter-catalog-e2e.js --appointment-flow',
        preconditions: 'Synthetic client/barber/admin users, two isolated tenants, active services and daily 08:00-20:00 schedule.',
        testData: 'QA Barbearia A; QA Corte A (BRL 40/45 min); QA Barba A (BRL 25/20 min); future 10:00 slot.',
        expectedResult: 'UI completes booking once, persists through app restart and relogin, appears for client/barber, cancels into history and releases the slot; API/DB agree.',
        status: passed ? 'passed' : 'failed',
        flutter: { exitCode: flutterResult?.status ?? null, signal: flutterResult?.signal ?? null, lateExceptionPolicy: 'nonzero flutter drive exit is failed', log: APPOINTMENT_LOG },
        apiDatabaseEvidence,
        infrastructureError,
        cleanup,
      };
      await fs.writeFile(APPOINTMENT_EVIDENCE, JSON.stringify(evidence, null, 2));
      console.log(JSON.stringify({ evidence: APPOINTMENT_EVIDENCE, status: evidence.status, cleanup }, null, 2));
    }
  }
}

main();
