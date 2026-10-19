function parseCents(value, field = 'amount') {
  const text = String(value ?? '').trim();
  if (!/^\d+(?:\.\d{1,2})?$/.test(text)) throw new Error('invalid_amount');
  const [whole, fraction = ''] = text.split('.');
  return BigInt(whole) * 100n + BigInt((fraction + '00').slice(0, 2));
}

function roundRatio(numerator, denominator) {
  if (numerator < 0n || denominator <= 0n) throw new Error('invalid_ratio');
  return (2n * numerator + denominator) / (2n * denominator);
}

function totalPercentage(baseCents, rateBps) {
  if (baseCents < 0n || rateBps < 0n || rateBps > 10000n) throw new Error('invalid_commission');
  return roundRatio(baseCents * rateBps, 10000n);
}

function targetReleased(completed, totalCommission, originalNet, netReceived) {
  if (!completed || originalNet === 0n) return 0n;
  if (originalNet < 0n || totalCommission < 0n || netReceived < 0n) throw new Error('inconsistent_amounts');
  const received = netReceived > originalNet ? originalNet : netReceived;
  return received === originalNet ? totalCommission : roundRatio(totalCommission * received, originalNet);
}

function resolveCommissionRule(rules, { professionalId, serviceId, effectiveAt }) {
  const at = new Date(effectiveAt).getTime();
  if (!Number.isFinite(at)) throw new Error('invalid_effective_date');
  const applicable = rules.filter((rule) => {
    if (!rule.active) return false;
    const from = rule.validFrom ? new Date(rule.validFrom).getTime() : -Infinity;
    const until = rule.validUntil ? new Date(rule.validUntil).getTime() : Infinity;
    return at >= from && at < until;
  });
  const candidates = [
    applicable.filter((r) => String(r.professionalId) === String(professionalId) && String(r.serviceId) === String(serviceId)),
    applicable.filter((r) => String(r.professionalId) === String(professionalId) && r.serviceId == null),
    applicable.filter((r) => r.professionalId == null && String(r.serviceId) === String(serviceId)),
    applicable.filter((r) => r.professionalId == null && r.serviceId == null),
  ];
  return candidates.find((group) => group.length > 0)?.sort((a, b) => Number(b.version || 0) - Number(a.version || 0))[0] || null;
}

function calculateItem({ grossCents, discountCents, quantity = 1n, rule }) {
  if (grossCents < 0n || discountCents < 0n || quantity <= 0n) throw new Error('invalid_item_amount');
  const gross = grossCents * quantity;
  const discount = discountCents;
  const originalNet = gross - discount;
  if (originalNet < 0n) throw new Error('discount_exceeds_item');
  const base = rule.type === 'fixed' ? 0n : rule.base === 'gross' ? gross : originalNet;
  const totalCommission = rule.type === 'fixed'
    ? parseCents(rule.value, 'fixed_value') * quantity
    : totalPercentage(base, BigInt(rule.valueBps));
  return { gross, discount, originalNet, base, totalCommission };
}

module.exports = { parseCents, roundRatio, totalPercentage, targetReleased, resolveCommissionRule, calculateItem };
