const test = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
function fixture({ changed = false, conflict = false, existing = false } = {}) {
  const writes = [];
  let committed = false, rolledBack = false;
  const connection = {
    beginTransaction: async () => {}, commit: async () => { committed = true; }, rollback: async () => { rolledBack = true; }, release() {},
    query: async (sql, params) => {
      if (sql.includes('GET_LOCK')) return [[{ acquired: 1 }], []];
      if (sql.includes('SELECT agendamento_id')) return [existing ? [{ agendamento_id: 99 }] : [], []];
      if (sql.includes('SELECT s.id')) return [[{ id: 2, nome: 'Corte', preco: changed ? 70 : 50, duracao_min: 30, barbearia_id: 1 }], []];
      if (sql.includes('SELECT id FROM horarios_funcionamento')) return [[{ id: 1 }], []];
      if (sql.includes('SELECT id FROM agendamentos')) return [conflict ? [{ id: 7 }] : [], []];
      if (sql.includes('SELECT id FROM horarios_bloqueados')) return [[], []];
      if (sql.includes('INSERT')) writes.push({ sql, params });
      return [{ insertId: 99 }, []];
    },
  };
  const sandbox = { module: { exports: {} }, console, require: name => name.includes('config/database') ? { pool: { getConnection: async () => connection } } : name.includes('utils/access') ? {} : name.includes('financial.service') ? { createForecast: async () => {} } : require('../src/services/appointment-availability.service') };
  vm.runInNewContext(fs.readFileSync(require.resolve('../src/controllers/agendamentos.controller'), 'utf8'), sandbox);
  return { handler: sandbox.module.exports.criar, writes, state: () => ({ committed, rolledBack }) };
}
async function run(options) {
  const f = fixture(options);
  const req = { usuario: { id: 10 }, body: { colaborador_id: 3, servico_id: 2, servicos_ids: [2], data_hora: '2099-01-02 15:00:00' }, assistantProposal: { jti: 'test-proposal', shopId: 1, expected: [{ id: 2, price: 50, duration: 30 }] } };
  const res = { code: 200, status(code) { this.code = code; return this; }, json(body) { this.body = body; return this; } };
  await f.handler(req, res); return { ...f, res };
}
test('confirmation writes appointment and unique receipt in same transaction', async () => {
  const f = await run(); assert.equal(f.res.code, 201); assert.equal(f.state().committed, true);
  assert.equal(f.writes.filter(w => w.sql.includes('INSERT INTO agendamentos')).length, 1);
  assert.equal(f.writes.filter(w => w.sql.includes('INSERT INTO assistant_confirmations')).length, 1);
});
test('price changes and concurrent occupation roll back without inserting reservation', async () => {
  for (const options of [{ changed: true }, { conflict: true }]) {
    const f = await run(options); assert.equal(f.res.code, 409); assert.equal(f.state().rolledBack, true); assert.equal(f.writes.length, 0);
  }
});
test('repeated confirmation returns original appointment without writing', async () => {
  const f = await run({ existing: true }); assert.equal(f.res.body.id, 99); assert.equal(f.res.body.idempotent, true); assert.equal(f.writes.length, 0);
});
