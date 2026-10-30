const router = require('express').Router();
const { mercadoPago } = require('../controllers/webhooks.controller');

// * ADICIONAR/EDITAR: webhook confirma eventos externos de pagamento; o
// * controller deve validar assinatura e idempotencia antes de persistir.
router.post('/mercado-pago', mercadoPago);

module.exports = router;
