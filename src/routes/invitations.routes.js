const router = require('express').Router();
const { autenticar, autorizar } = require('../middlewares/auth.middleware');
const { list, create, accept } = require('../controllers/invitations.controller');

// * ADICIONAR: aceitar convite cria/ativa o vinculo do usuario ao tenant.
router.post('/accept', accept);
router.get('/:barbearia_id', autenticar, autorizar('admin'), list);
// * ADICIONAR: administrador emite convite para colaborador.
router.post('/:barbearia_id', autenticar, autorizar('admin'), create);

module.exports = router;
