const router = require('express').Router();
const { autenticar, autorizar } = require('../middlewares/auth.middleware');
const { conversar, confirmarProposta } = require('../controllers/assistente.controller');
const { rateLimit } = require('../middlewares/security.middleware');
router.use(autenticar, autorizar('cliente'), rateLimit({ windowMs: 60000, max: 20, byUser: true }));

router.post('/conversar', autenticar, autorizar('cliente'), conversar);
router.post('/confirmar', autenticar, autorizar('cliente'), confirmarProposta);

module.exports = router;
