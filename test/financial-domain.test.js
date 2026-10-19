const test = require('node:test');
const assert = require('node:assert/strict');
const { cents, decimal } = require('../src/services/financial.service');
const { CAPABILITIES } = require('../src/middlewares/capabilities.middleware');

test('converte valores monetarios sem ponto flutuante', () => {
  assert.equal(cents('0,01'), 1n);
  assert.equal(cents('10,00'), 1000n);
  assert.equal(cents('10.10'), 1010n);
  assert.equal(cents('999999,99'), 99999999n);
  assert.equal(decimal(99999999n), '999999.99');
});

test('rejeita valores monetarios ambiguos ou fora da escala', () => {
  assert.equal(cents('-1.00'), null);
  assert.equal(cents('1.001'), null);
  assert.equal(cents('abc'), null);
});

test('capabilities administrativas nao liberam financeiro ao profissional', () => {
  assert.equal(CAPABILITIES.owner.includes('financial.read.all'), true);
  assert.equal(CAPABILITIES.manager.includes('financial.create.expense'), true);
  assert.equal(CAPABILITIES.professional.includes('financial.read.all'), false);
  assert.deepEqual(CAPABILITIES.professional, ['appointments.read.own', 'commission.own.view', 'commission.own.history']);
});
