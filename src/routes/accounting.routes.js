const router = require('express').Router();
const { autenticar } = require('../middlewares/auth.middleware');
const { tenantContext, requireCapability, requireAdmin } = require('../middlewares/capabilities.middleware');
const controller = require('../controllers/accounting.controller');

router.use(autenticar, tenantContext, requireAdmin, requireCapability('accounting.read'));
router.get('/accounts', controller.accounts);
router.get('/entries', controller.entries);
router.get('/result', controller.result);
router.get('/taxes', controller.taxes);
router.post('/taxes', controller.createTax);
router.delete('/taxes/:id', controller.deleteTax);

module.exports = router;
