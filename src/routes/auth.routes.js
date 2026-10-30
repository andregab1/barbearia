// ==========================================
// ROTAS: Autenticação
// ==========================================
const router = require('express').Router();
const { cadastrar, login, refresh, logout } = require('../controllers/auth.controller');
const { registerOwner } = require('../controllers/onboarding.controller');

// * ADICIONAR: cadastro publico de usuario e registro inicial do proprietario.
router.post('/cadastrar', cadastrar);
router.post('/register-owner', registerOwner);
// * CONSULTAR/EDITAR SESSAO: login, refresh e logout controlam os tokens.
router.post('/login',     login);
router.post('/refresh',   refresh);
router.post('/logout',    logout);

module.exports = router;
