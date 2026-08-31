// ==========================================
// ROTAS: Usuários
// Perfil e edição de dados
// ==========================================
const router = require('express').Router();
const { autenticar } = require('../middlewares/auth.middleware');
const { buscar, atualizar, alterarSenha } = require('../controllers/usuarios.controller');

router.get('/:id',  autenticar, buscar);
router.put('/:id',  autenticar, atualizar);
router.patch('/me/senha', autenticar, alterarSenha);

module.exports = router;
