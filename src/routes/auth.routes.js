// ==========================================
// ROTAS: Autenticação
// ==========================================
const router = require('express').Router();
const { cadastrar, login, refreshToken, logout } = require('../controllers/auth.controller');

router.post('/cadastrar', cadastrar);
router.post('/login',     login);
router.post('/refresh',   refreshToken);
router.post('/logout',    logout);

module.exports = router;
