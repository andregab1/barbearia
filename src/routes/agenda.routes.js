// ==========================================
// ROTAS: Agenda e Histórico
// RF05 - Visualização | RF10 - Histórico
// ==========================================
const router = require('express').Router();
const { autenticar } = require('../middlewares/auth.middleware');
const { horariosdisponiveis, historico } = require('../controllers/agenda.controller');

// Sem acento para evitar problemas de encoding na URL
router.get('/disponiveis/:colaborador_id', autenticar, horariosdisponiveis);
router.get('/historico/:cliente_id',       autenticar, historico);

module.exports = router;