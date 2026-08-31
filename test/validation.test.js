const test = require('node:test');
const assert = require('node:assert/strict');
const { normalizePhone, slugify, validateOwnerRegistration } = require('../src/utils/validation');
const { requestContext, errorBody } = require('../src/middlewares/request.middleware');

test('normaliza telefone e slug para armazenamento consistente', () => {
  assert.equal(normalizePhone('(41) 99876-5432'), '41998765432');
  assert.equal(slugify('Barbearia João & Filhos'), 'barbearia-joao-filhos');
});

test('valida cadastro completo de proprietário', () => {
  const result = validateOwnerRegistration({
    owner_name: 'João Silva',
    shop_name: 'Barbearia Central',
    email: 'JOAO@EXAMPLE.COM',
    phone: '(41) 99876-5432',
    password: 'segura123',
  });
  assert.equal(result.valid, true);
  assert.equal(result.data.email, 'joao@example.com');
  assert.equal(result.data.slug, 'barbearia-central');
});

test('retorna erros por campo em cadastro inválido', () => {
  const result = validateOwnerRegistration({ owner_name: 'A', shop_name: '', email: 'x', phone: '1', password: '123' });
  assert.equal(result.valid, false);
  assert.deepEqual(Object.keys(result.fields).sort(), ['email', 'owner_name', 'password', 'phone', 'shop_name', 'slug']);
});

test('requestContext preserva id válido e padroniza envelope', () => {
  const req = { headers: { 'x-request-id': 'request-1234' } };
  const res = { headers: {}, setHeader(name, value) { this.headers[name] = value; } };
  let called = false;
  requestContext(req, res, () => { called = true; });
  assert.equal(called, true);
  assert.equal(req.requestId, 'request-1234');
  assert.deepEqual(errorBody(req, 'VALIDATION_ERROR', 'Revise.', { email: 'Inválido.' }), {
    code: 'VALIDATION_ERROR', message: 'Revise.', requestId: 'request-1234', fields: { email: 'Inválido.' },
  });
});
