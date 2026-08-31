const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const { classify, finalize, redact, summary, validateCatalog } = require('../scripts/ai-test-executor');

const catalog = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'docs', 'AI_TEST_CATALOG.json'), 'utf8'));

test('catálogo possui 630 IDs únicos e campos obrigatórios', () => {
  assert.equal(catalog.cases.length, 630);
  assert.deepEqual(validateCatalog(catalog), []);
  assert.equal(new Set(catalog.cases.map(item => item.id)).size, 630);
});

test('classifica todos os casos em handlers explícitos', () => {
  const bindings = catalog.cases.map(classify);
  assert.equal(bindings.length, 630);
  assert.equal(bindings.every(item => item.handler && item.reason), true);
  assert.equal(bindings.some(item => item.handler === 'flutter_e2e'), true);
  assert.equal(bindings.some(item => item.handler === 'api_database'), true);
});

test('não permite caso aprovado sem evidência e resultado atual', () => {
  assert.throws(() => finalize({ caseId: 'X', evidence: [] }, { status: 'passed', actualResult: '' }), /must have evidence/);
});

test('redige tokens e campos sensíveis de evidência', () => {
  const value = redact({ authorization: 'Bearer abc.def', nested: { password: 'secret' }, log: 'Bearer token-value' });
  assert.equal(value.authorization, '[REDACTED]');
  assert.equal(value.nested.password, '[REDACTED]');
  assert.equal(value.log, 'Bearer [REDACTED]');
});

test('resumo reconcilia todos os status', () => {
  const value = summary([{ status: 'passed' }, { status: 'blocked' }, { status: 'blocked' }]);
  assert.equal(value.total, 3);
  assert.equal(value.passed, 1);
  assert.equal(value.blocked, 2);
  assert.equal([...require('../scripts/ai-test-executor').ALLOWED].reduce((total, status) => total + value[status], 0), value.total);
});

test('overrides de evidência referenciam somente IDs do catálogo e status válidos', () => {
  const overrides = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'docs', 'AI_TEST_RESULT_OVERRIDES.json'), 'utf8'));
  const ids = new Set(catalog.cases.map(item => item.id));
  for (const [id, result] of Object.entries(overrides)) {
    assert.equal(ids.has(id), true, `override desconhecido: ${id}`);
    assert.equal(require('../scripts/ai-test-executor').ALLOWED.has(result.status), true);
    assert.equal(Array.isArray(result.evidence) && result.evidence.length > 0, true);
  }
});
