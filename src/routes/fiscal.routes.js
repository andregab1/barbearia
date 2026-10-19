const router = require('express').Router();
const { autenticar } = require('../middlewares/auth.middleware');
const { tenantContext, requireCapability } = require('../middlewares/capabilities.middleware');
const controller = require('../controllers/fiscal.controller');

router.use(autenticar, tenantContext);
router.get('/settings', requireCapability('fiscal.read'), controller.getSettings);
router.put('/settings', requireCapability('fiscal.issue'), controller.updateSettings);
router.get('/documents', requireCapability('fiscal.read'), controller.documents);
router.post('/documents', requireCapability('fiscal.issue'), controller.issue);

module.exports = router;
