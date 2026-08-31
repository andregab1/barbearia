const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('crypto');
const { validateWebhookSignature } = require('../src/services/mercado-pago.service');

test('valida assinatura oficial de webhook do Mercado Pago', () => {
  const secret = 'segredo-de-teste';
  const dataId = 'PAYMENT-123';
  const requestId = 'provider-request-123';
  const ts = '1704908010';
  const manifest = `id:${dataId.toLowerCase()};request-id:${requestId};ts:${ts};`;
  const signature = crypto.createHmac('sha256', secret).update(manifest).digest('hex');
  assert.equal(validateWebhookSignature({
    xSignature: `ts=${ts},v1=${signature}`,
    xRequestId: requestId,
    dataId,
    secret,
  }), true);
});

test('rejeita webhook alterado ou incompleto', () => {
  assert.equal(validateWebhookSignature({
    xSignature: 'ts=1,v1=deadbeef',
    xRequestId: 'request-123',
    dataId: '999',
    secret: 'secret',
  }), false);
  assert.equal(validateWebhookSignature({}), false);
});
