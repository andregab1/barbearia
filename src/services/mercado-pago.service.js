const crypto = require('crypto');

function parseSignature(header) {
  return String(header || '')
    .split(',')
    .map((item) => item.trim().split('='))
    .reduce((result, [key, value]) => ({ ...result, [key]: value }), {});
}

function validateWebhookSignature({ xSignature, xRequestId, dataId, secret }) {
  if (!xSignature || !xRequestId || !dataId || !secret) return false;
  const { ts, v1 } = parseSignature(xSignature);
  if (!ts || !v1) return false;
  const manifest = `id:${String(dataId).toLowerCase()};request-id:${xRequestId};ts:${ts};`;
  const expected = crypto.createHmac('sha256', secret).update(manifest).digest('hex');
  const received = Buffer.from(v1, 'hex');
  const calculated = Buffer.from(expected, 'hex');
  return received.length === calculated.length && crypto.timingSafeEqual(received, calculated);
}

async function mercadoPagoRequest(path, options = {}) {
  const accessToken = process.env.MERCADO_PAGO_ACCESS_TOKEN;
  if (!accessToken) throw new Error('MERCADO_PAGO_ACCESS_TOKEN não configurado.');
  const response = await fetch(`https://api.mercadopago.com${path}`, {
    ...options,
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
      ...options.headers,
    },
    signal: AbortSignal.timeout(10000),
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    const error = new Error('Falha na comunicação com o Mercado Pago.');
    error.status = response.status;
    error.providerCode = body.code || body.error;
    throw error;
  }
  return body;
}

module.exports = { parseSignature, validateWebhookSignature, mercadoPagoRequest };
