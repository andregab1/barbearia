const router = require('express').Router();
const { autenticar, autorizar } = require('../middlewares/auth.middleware');
const { list, create, accept } = require('../controllers/invitations.controller');

router.post('/accept', accept);
router.get('/:barbearia_id', autenticar, autorizar('admin'), list);
router.post('/:barbearia_id', autenticar, autorizar('admin'), create);

module.exports = router;
