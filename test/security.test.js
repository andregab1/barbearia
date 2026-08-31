const test = require('node:test');
const assert = require('node:assert/strict');
const { securityHeaders, rateLimit } = require('../src/middlewares/security.middleware');

function resposta() {
  return {
    headers: {}, statusCode: 200,
    setHeader(nome, valor) { this.headers[nome] = valor; },
    status(codigo) { this.statusCode = codigo; return this; },
    json(body) { this.body = body; return this; },
  };
}

test('securityHeaders aplica cabeçalhos essenciais', () => {
  const res = resposta();
  let nextCalled = false;
  securityHeaders({}, res, () => { nextCalled = true; });
  assert.equal(res.headers['X-Content-Type-Options'], 'nosniff');
  assert.equal(res.headers['X-Frame-Options'], 'DENY');
  assert.equal(nextCalled, true);
});

test('rateLimit bloqueia chamadas acima do limite', () => {
  const middleware = rateLimit({ windowMs: 60000, max: 1 });
  const req = { ip: '127.0.0.99', baseUrl: '/api/auth', path: '/login' };
  let chamadas = 0;
  middleware(req, resposta(), () => { chamadas += 1; });
  const bloqueada = resposta();
  middleware(req, bloqueada, () => { chamadas += 1; });
  assert.equal(chamadas, 1);
  assert.equal(bloqueada.statusCode, 429);
  assert.equal(bloqueada.body.code, 'RATE_LIMITED');
});
