const crypto = require('crypto');
const { pool } = require('../config/database');
const { obterBarbeariaAdministrada } = require('../utils/access');
const { normalizeEmail } = require('../utils/validation');
const { errorBody } = require('../middlewares/request.middleware');
const { mercadoPagoRequest } = require('../services/mercado-pago.service');

async function createSubscription(req, res) {
  const shop = await obterBarbeariaAdministrada(req.usuario.id, req.params.barbearia_id);
  if (!shop) return res.status(403).json(errorBody(req, 'FORBIDDEN', 'Acesso não permitido.'));
  const planCode = String(req.body.plan_code || 'professional');
  const payerEmail = normalizeEmail(req.body.payer_email);
  if (!payerEmail) return res.status(422).json(errorBody(req, 'VALIDATION_ERROR', 'Informe o e-mail do pagador.'));
  const [plans] = await pool.query('SELECT id, nome, preco_mensal FROM plans WHERE codigo = ? AND ativo = 1 LIMIT 1', [planCode]);
  if (plans.length === 0) return res.status(404).json(errorBody(req, 'PLAN_NOT_FOUND', 'Plano não encontrado.'));
  const plan = plans[0];
  const idempotencyKey = String(req.headers['x-idempotency-key'] || crypto.randomUUID());
  try {
    const provider = await mercadoPagoRequest('/preapproval', {
      method: 'POST',
      headers: { 'X-Idempotency-Key': idempotencyKey },
      body: JSON.stringify({
        reason: `GetCutt - ${plan.nome}`,
        external_reference: `barbershop:${shop.id}:plan:${plan.id}`,
        payer_email: payerEmail,
        auto_recurring: { frequency: 1, frequency_type: 'months', transaction_amount: Number(plan.preco_mensal), currency_id: 'BRL' },
        back_url: `${process.env.APP_PUBLIC_URL || 'http://localhost:8080'}/billing/return`,
        status: 'pending',
      }),
    });
    await pool.query(
      `UPDATE subscriptions SET plan_id = ?, provedor_assinatura_id = ?, status = 'trial'
       WHERE barbearia_id = ? AND status IN ('trial','past_due','paused') ORDER BY id DESC LIMIT 1`,
      [plan.id, provider.id, shop.id],
    );
    return res.status(201).json({ data: { subscription_id: provider.id, checkout_url: provider.init_point, status: provider.status }, requestId: req.requestId });
  } catch (error) {
    console.error(JSON.stringify({ level: 'error', event: 'subscription_create_failed', requestId: req.requestId, providerCode: error.providerCode, error: error.message }));
    return res.status(error.status === 400 ? 422 : 502).json(errorBody(req, 'PAYMENT_PROVIDER_ERROR', 'Não foi possível iniciar a assinatura.'));
  }
}

module.exports = { createSubscription };
