const router = require('express').Router();
const { autenticar, autorizar } = require('../middlewares/auth.middleware');
const { faturamentoDiario, faturamentoMensal, faturamentoPeriodo } = require('../controllers/relatorios.controller');

router.get('/:barbearia_id/diario',  autenticar, autorizar('admin'), faturamentoDiario);
router.get('/:barbearia_id/mensal',  autenticar, autorizar('admin'), faturamentoMensal);
router.get('/:barbearia_id/periodo', autenticar, autorizar('admin'), faturamentoPeriodo);

module.exports = router;