// ==========================================
// ROTAS: Serviços e Preços
// RF12 - Gestão de Serviços e Preços
// ==========================================
const router = require('express').Router();
const { autenticar, autorizar } = require('../middlewares/auth.middleware');
const { listar, criar, atualizar, desativar } = require('../controllers/servicos.controller');

// Público — clientes podem ver os serviços sem login
router.get('/:barbearia_id', listar);

// Protegido — apenas admin e barbeiro podem gerenciar
router.post('/:barbearia_id', autenticar, autorizar('admin', 'barbeiro'), criar);
router.put('/:id',            autenticar, autorizar('admin', 'barbeiro'), atualizar);
router.delete('/:id',         autenticar, autorizar('admin', 'barbeiro'), desativar);

module.exports = router;