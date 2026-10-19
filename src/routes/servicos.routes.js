// ==========================================
// ROTAS: Serviços e Preços
// RF12 - Gestão de Serviços e Preços
// ==========================================
const router = require('express').Router();
const { autenticar, autorizar } = require('../middlewares/auth.middleware');
const { listar, listarCategorias, criarCategoria, criar, atualizar, desativar } = require('../controllers/servicos.controller');

router.get('/categorias/:barbearia_id', autenticar, autorizar('admin'), listarCategorias);
router.post('/categorias/:barbearia_id', autenticar, autorizar('admin'), criarCategoria);

// Público — clientes podem ver os serviços sem login
router.get('/:barbearia_id', listar);

// Protegido — apenas admin e barbeiro podem gerenciar
router.post('/:barbearia_id', autenticar, autorizar('admin'), criar);
router.put('/:id',            autenticar, autorizar('admin'), atualizar);
router.delete('/:id',         autenticar, autorizar('admin'), desativar);

module.exports = router;
