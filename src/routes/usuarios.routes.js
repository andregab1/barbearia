// ==========================================
// ROTAS: Usuários
// Perfil e edição de dados
// ==========================================
const router = require('express').Router();
const { autenticar } = require('../middlewares/auth.middleware');
const { buscar, atualizar, alterarSenha } = require('../controllers/usuarios.controller');

// * CONSULTAR/EDITAR: perfil e senha do usuario autenticado, com validacao
// * adicional no controller para impedir alteracao de outro usuario.
router.get('/:id',  autenticar, buscar);
router.put('/:id',  autenticar, atualizar);
router.patch('/me/senha', autenticar, alterarSenha);

module.exports = router;
