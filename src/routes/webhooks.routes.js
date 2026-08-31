const router = require('express').Router();
const { mercadoPago } = require('../controllers/webhooks.controller');

router.post('/mercado-pago', mercadoPago);

module.exports = router;
