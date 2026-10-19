const test = require('node:test');
const assert = require('node:assert/strict');
const {
  calculateItem,
  resolveCommissionRule,
  targetReleased,
  totalPercentage,
} = require('../src/services/commission-calculator');

test('calcula percentual sobre base líquida e libera pagamentos parciais', () => {
  const item = calculateItem({
    grossCents: 10000n,
    discountCents: 0n,
    rule: { type: 'percentage', base: 'net_after_discount', valueBps: 4000 },
  });
  assert.equal(item.totalCommission, 4000n);
  assert.equal(targetReleased(true, item.totalCommission, item.originalNet, 5000n), 2000n);
  assert.equal(targetReleased(true, item.totalCommission, item.originalNet, 10000n), 4000n);
});

test('calcula comissão fixa por unidade e rateia sem duplicar na quitação', () => {
  const item = calculateItem({
    grossCents: 10000n,
    discountCents: 0n,
    quantity: 1n,
    rule: { type: 'fixed', value: '15.00' },
  });
  assert.equal(item.totalCommission, 1500n);
  assert.equal(targetReleased(true, item.totalCommission, item.originalNet, 5000n), 750n);
  assert.equal(targetReleased(true, item.totalCommission, item.originalNet, 10000n), 1500n);
});

test('respeita base bruta versus líquida após desconto', () => {
  const net = calculateItem({ grossCents: 10000n, discountCents: 2000n, rule: { type: 'percentage', base: 'net_after_discount', valueBps: 4000 } });
  const gross = calculateItem({ grossCents: 10000n, discountCents: 2000n, rule: { type: 'percentage', base: 'gross', valueBps: 4000 } });
  assert.equal(net.totalCommission, 3200n);
  assert.equal(gross.totalCommission, 4000n);
});

test('resolve regra por especificidade e aceita percentual explícito zero', () => {
  const rules = [
    { id: 1, professionalId: null, serviceId: null, type: 'percentage', active: true, valueBps: 4000, validFrom: '2026-01-01', version: 1 },
    { id: 2, professionalId: 10, serviceId: null, type: 'percentage', active: true, valueBps: 0, validFrom: '2026-01-01', version: 1 },
    { id: 3, professionalId: 10, serviceId: 20, type: 'percentage', active: true, valueBps: 5000, validFrom: '2026-01-01', version: 1 },
  ];
  assert.equal(resolveCommissionRule(rules, { professionalId: 10, serviceId: 20, effectiveAt: '2026-09-24T10:00:00Z' }).id, 3);
  assert.equal(resolveCommissionRule(rules, { professionalId: 10, serviceId: 21, effectiveAt: '2026-09-24T10:00:00Z' }).id, 2);
  assert.equal(resolveCommissionRule(rules, { professionalId: 11, serviceId: 21, effectiveAt: '2026-09-24T10:00:00Z' }).id, 1);
});

test('arredondamento half-up trabalha em centavos sem float', () => {
  assert.equal(totalPercentage(3333n, 4000n), 1333n);
  assert.equal(totalPercentage(3334n, 4000n), 1334n);
});
