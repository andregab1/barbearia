const router = require('express').Router();
const { autenticar, autorizar } = require('../middlewares/auth.middleware');
const { faturamentoDiario, faturamentoMensal, faturamentoPeriodo } = require('../controllers/relatorios.controller');

// * CONSULTAR: relatorios sao somente leitura e usam o tenant autorizado;
// * nao alteram os lancamentos que servem de origem.
router.get('/:barbearia_id/diario',  autenticar, autorizar('admin'), faturamentoDiario);
router.get('/:barbearia_id/mensal',  autenticar, autorizar('admin'), faturamentoMensal);
router.get('/:barbearia_id/periodo', autenticar, autorizar('admin'), faturamentoPeriodo);

module.exports = router;
