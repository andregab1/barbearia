// ==========================================
// ROTAS: Notificações
// RF08 - Notificações Automáticas
// ==========================================
const router = require('express').Router();
const { autenticar, autorizar } = require('../middlewares/auth.middleware');
const { listar, dispararPendentes } = require('../controllers/notificacoes.controller');

// * CONSULTAR: lista notificacoes do usuario autenticado.
router.get('/',           autenticar, listar);
// * ADICIONAR/EDITAR ESTADO: dispara pendencias sem apagar notificacoes
// * anteriores; a regra de duplicidade fica no controller/service.
router.post('/disparar',  autenticar, autorizar('admin'), dispararPendentes);

module.exports = router;
