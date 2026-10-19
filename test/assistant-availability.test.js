const test = require('node:test');
const assert = require('node:assert/strict');
const { availableSlots, parseLocal, formatLocal } = require('../src/services/appointment-availability.service');
const fs = require('node:fs');
const vm = require('node:vm');
const jwt = require('jsonwebtoken');
const now = new Date('2030-01-01T00:00:00Z');
function database(shifts, appointments = [], blocks = []) {
  return { query: async sql => [sql.includes('horarios_funcionamento') ? shifts : sql.includes('horarios_bloqueados') ? blocks : appointments, []] };
}
test('available shift is read from mysql rows and returns real slots', async () => {
  const slots = await availableSlots(database([{ hora_inicio: '09:00:00', hora_fim: '10:00:00' }]), 1, '2030-01-02', 30, now);
  assert.deepEqual(slots, ['09:00', '09:30']);
});
test('multiple shifts, combined duration, overlap and cross-day block', async () => {
  const db = database([{ hora_inicio: '09:00:00', hora_fim: '12:00:00' }, { hora_inicio: '14:00:00', hora_fim: '16:00:00' }], [{ data_hora: '2030-01-02 14:30:00', duracao_min: 30 }], [{ data_hora_ini: '2030-01-01 23:00:00', data_hora_fim: '2030-01-02 10:00:00' }]);
  assert.deepEqual(await availableSlots(db, 1, '2030-01-02', 60, now), ['10:00', '10:30', '11:00', '15:00']);
});
test('reject impossible dates and past slots, independent of server timezone', async () => {
  assert.ok(Number.isNaN(+parseLocal('2030-02-30 15:00:00')));
  assert.equal(parseLocal('2030-01-02 15:00:00').toISOString(), '2030-01-02T18:00:00.000Z');
  assert.equal(formatLocal(new Date('2030-01-02T18:00:00Z')), '2030-01-02 15:00:00');
  assert.deepEqual(await availableSlots(database([{ hora_inicio: '09:00:00', hora_fim: '10:00:00' }]), 1, '2030-01-02', 30, new Date('2030-01-02T12:10:00Z')), ['09:30']);
});
function controller({ missing = false, answer, status = 'completed', fail = false } = {}) {
  const pool = { query: async sql => {
    if (sql.includes('FROM barbearias')) return [missing ? [] : [{ id: 1, nome: 'Barbearia' }], []];
    if (sql.includes('FROM servicos')) return [[{ id: 2, nome: 'Corte', preco: 50, duracao_min: 30 }], []];
    if (sql.includes('FROM colaboradores')) return [[{ id: 3, nome: 'André' }], []];
    return database([{ hora_inicio: '09:00:00', hora_fim: '18:00:00' }]).query(sql);
  } };
  class FakeGemini { constructor() { this.models = { generateContent: async () => { if (fail) throw new Error('timeout'); return { text: status === 'completed' ? JSON.stringify(answer) : '' }; } }; } }
  const sandbox = { module: { exports: {} }, process: { env: { GEMINI_API_KEY: 'test', JWT_SECRET: 'test-secret' } }, console: { error() {} }, require: name => name === '@google/genai' ? { GoogleGenAI: FakeGemini } : name.includes('config/database') ? { pool } : name === './agendamentos.controller' ? { criar: async (_, res) => res.json({ id: 99 }) } : name.includes('appointment-availability') ? require('../src/services/appointment-availability.service') : require(name) };
  vm.runInNewContext(fs.readFileSync(require.resolve('../src/controllers/assistente.controller'), 'utf8'), sandbox);
  return sandbox.module.exports;
}
async function invoke(handler, body) {
  const res = { statusCode: 200, status(n) { this.statusCode = n; return this; }, json(data) { this.body = data; return this; } };
  await handler({ body, usuario: { id: 10 } }, res); return res;
}
const complete = { message: 'Confira', service_ids: [2], professional_id: 3, date: '2099-01-02', time: '15:00' };
test('complete request produces signed proposal with authoritative price and duration', async () => {
  const res = await invoke(controller({ answer: complete }).conversar, { message: 'corte', barbearia_id: 1 });
  assert.equal(res.body.status, 'proposal'); assert.equal(res.body.proposal.total, 50);
  const signed = jwt.verify(res.body.proposal_token, 'test-secret');
  assert.equal(signed.expected[0].duration, 30); assert.ok(signed.jti);
});
test('missing shop, missing time, unavailable time and incomplete model response', async () => {
  assert.equal((await invoke(controller({ missing: true }).conversar, { message: 'corte', barbearia_id: 1 })).statusCode, 404);
  for (const time of [null, '20:00']) {
    const res = await invoke(controller({ answer: { ...complete, time } }).conversar, { message: 'corte', barbearia_id: 1 });
    assert.equal(res.body.status, 'alternatives'); assert.equal(res.body.alternatives.length, 5);
  }
  const dates = await invoke(controller({ answer: { ...complete, date: null, time: null } }).conversar, { message: 'quais dias', barbearia_id: 1 });
  assert.equal(dates.body.status, 'alternatives'); assert.equal(dates.body.alternatives.length, 10);
  assert.equal((await invoke(controller({ answer: complete, status: 'incomplete' }).conversar, { message: 'corte', barbearia_id: 1 })).statusCode, 502);
  assert.equal((await invoke(controller({ fail: true }).conversar, { message: 'corte', barbearia_id: 1 })).statusCode, 504);
});
test('reject tampered, expired and other-user proposals', async () => {
  for (const token of ['invalid', jwt.sign({ type: 'assistant_appointment', userId: 11 }, 'test-secret'), jwt.sign({ type: 'assistant_appointment', userId: 10 }, 'test-secret', { expiresIn: -1 })]) {
    assert.equal((await invoke(controller().confirmarProposta, { proposal_token: token })).statusCode, 400);
  }
});
