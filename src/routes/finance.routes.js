const router = require('express').Router();
const { autenticar, autorizar } = require('../middlewares/auth.middleware');
const { summary, entries, createExpense } = require('../controllers/finance.controller');

router.use(autenticar, autorizar('admin'));
router.get('/:barbearia_id/summary', summary);
router.get('/:barbearia_id/entries', entries);
router.post('/:barbearia_id/expenses', createExpense);

module.exports = router;
