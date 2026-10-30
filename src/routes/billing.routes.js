const router = require('express').Router();
const { autenticar, autorizar } = require('../middlewares/auth.middleware');
const { createSubscription } = require('../controllers/billing.controller');

// * ADICIONAR/EDITAR: cria ou atualiza a assinatura da barbearia conforme o
// * fluxo de billing; o controller valida o administrador e o tenant informado.
router.post('/:barbearia_id/subscriptions', autenticar, autorizar('admin'), createSubscription);

module.exports = router;
