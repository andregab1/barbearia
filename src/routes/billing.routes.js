const router = require('express').Router();
const { autenticar, autorizar } = require('../middlewares/auth.middleware');
const { createSubscription } = require('../controllers/billing.controller');

router.post('/:barbearia_id/subscriptions', autenticar, autorizar('admin'), createSubscription);

module.exports = router;
