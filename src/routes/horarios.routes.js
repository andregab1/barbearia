// ==========================================
// ROTAS: Horários de Funcionamento
// RF03 - Configuração de horários do barbeiro
// ==========================================
const router = require('express').Router();
const { autenticar, autorizar } = require('../middlewares/auth.middleware');
const { buscar, salvar } = require('../controllers/horarios.controller');

// * CONSULTAR/EDITAR: busca e salva horarios do colaborador autorizado;
// * o controller mantem o relacionamento com a barbearia.
router.get('/:colaborador_id',  autenticar, autorizar('admin', 'barbeiro'), buscar);
router.post('/:colaborador_id', autenticar, autorizar('admin', 'barbeiro'), salvar);

module.exports = router;
