const router = require('express').Router();
const { autenticar } = require('../middlewares/auth.middleware');
const { tenantContext, requireCapability, requireAdmin } = require('../middlewares/capabilities.middleware');
const controller = require('../controllers/accounting.controller');

router.use(autenticar, tenantContext, requireAdmin, requireCapability('accounting.read'));
// * CONSULTAR: contas, partidas, resultado e tributos do tenant.
router.get('/accounts', controller.accounts);
router.get('/entries', controller.entries);
router.get('/result', controller.result);
router.get('/taxes', controller.taxes);
// * ADICIONAR/EXCLUIR: tributo e um registro contabil; a exclusao valida o
// * tenant e remove somente o item permitido pelo controller.
router.post('/taxes', controller.createTax);
router.delete('/taxes/:id', controller.deleteTax);

module.exports = router;
