// ==========================================
// ROTAS: Horários de Funcionamento
// RF03 - Configuração de horários do barbeiro
// ==========================================
const router = require('express').Router();
const { autenticar, autorizar } = require('../middlewares/auth.middleware');
const { buscar, salvar } = require('../controllers/horarios.controller');

router.get('/:colaborador_id',  autenticar, autorizar('admin', 'barbeiro'), buscar);
router.post('/:colaborador_id', autenticar, autorizar('admin', 'barbeiro'), salvar);

module.exports = router;
