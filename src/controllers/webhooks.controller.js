const { pool } = require('../config/database');
const { validateWebhookSignature } = require('../services/mercado-pago.service');
const { errorBody } = require('../middlewares/request.middleware');

async function mercadoPago(req, res) {
  const dataId = req.query['data.id'] || req.query.data_id || req.body?.data?.id;
  const providerRequestId = req.headers['x-request-id'];
  const valid = validateWebhookSignature({
    xSignature: req.headers['x-signature'],
    xRequestId: providerRequestId,
    dataId,
    secret: process.env.MERCADO_PAGO_WEBHOOK_SECRET,
  });
  if (!valid) return res.status(401).json(errorBody(req, 'INVALID_WEBHOOK_SIGNATURE', 'Assinatura inválida.'));

  const externalEventId = String(req.body?.id || `${req.body?.type || 'event'}:${dataId}:${providerRequestId}`);
  try {
    await pool.query(
      `INSERT IGNORE INTO webhook_events (provedor, evento_externo_id, tipo, payload)
       VALUES ('mercado_pago', ?, ?, ?)`,
      [externalEventId, String(req.body?.action || req.body?.type || 'unknown'), JSON.stringify(req.body || {})],
    );
    return res.status(202).json({ received: true, requestId: req.requestId });
  } catch (error) {
    console.error(JSON.stringify({ level: 'error', event: 'webhook_store_failed', requestId: req.requestId, error: error.message }));
    return res.status(500).json(errorBody(req, 'WEBHOOK_STORE_FAILED', 'Não foi possível registrar o evento.'));
  }
}

module.exports = { mercadoPago };
