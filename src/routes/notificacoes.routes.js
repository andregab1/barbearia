// ==========================================
// ROTAS: Notificações
// RF08 - Notificações Automáticas
// ==========================================
const router = require('express').Router();
const { autenticar, autorizar } = require('../middlewares/auth.middleware');
const { listar, dispararPendentes } = require('../controllers/notificacoes.controller');

router.get('/',           autenticar, listar);
router.post('/disparar',  autenticar, autorizar('admin'), dispararPendentes);

module.exports = router;