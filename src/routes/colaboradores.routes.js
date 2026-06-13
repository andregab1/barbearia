// ==========================================
// ROTAS: Colaboradores
// RF14 - Gestão Multiusuário
// ==========================================
const router = require('express').Router();
const { autenticar, autorizar } = require('../middlewares/auth.middleware');
const { listar, cadastrar, alterarStatus, remover, buscarPorUsuario } = require('../controllers/colaboradores.controller');

// Rota específica ANTES da rota com parâmetro genérico
router.get('/usuario/:usuario_id',    autenticar, buscarPorUsuario);

// Público — clientes podem ver os profissionais
router.get('/:barbearia_id',          listar);

router.post('/:barbearia_id',         autenticar, autorizar('admin'), cadastrar);
router.patch('/:id/status',           autenticar, autorizar('admin'), alterarStatus);
router.delete('/:id',                 autenticar, autorizar('admin'), remover);

module.exports = router;