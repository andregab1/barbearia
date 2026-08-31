// ==========================================
// ROTAS: Agendamentos
// RF06 - Agendar | RF07 - Cancelar | RF11 - Bloquear
// ==========================================
const router = require('express').Router();
const { autenticar, autorizar } = require('../middlewares/auth.middleware');
const {
  criar, listarCliente, listarBarbeiro,
  cancelar, concluir, bloquearHorario, preverBloqueio, bloquearRecorrente, removerBloqueio, listarBloqueios, clientesAtivos, listarClientesProfissional
} = require('../controllers/agendamentos.controller');

router.post('/',                          autenticar, autorizar('cliente'), criar);
router.get('/meus',                       autenticar, autorizar('cliente'), listarCliente);
router.get('/barbeiro/:colaborador_id',   autenticar, autorizar('admin', 'barbeiro'), listarBarbeiro);
router.get('/clientes-ativos',            autenticar, autorizar('admin', 'barbeiro'), clientesAtivos);
router.get('/clientes',                   autenticar, autorizar('admin', 'barbeiro'), listarClientesProfissional);
router.patch('/:id/cancelar',             autenticar, cancelar);
router.patch('/:id/concluir',             autenticar, autorizar('admin', 'barbeiro'), concluir);
router.get('/bloqueios/:colaborador_id',  autenticar, autorizar('admin', 'barbeiro'), listarBloqueios);
router.post('/bloquear',                  autenticar, autorizar('admin', 'barbeiro'), bloquearHorario);
router.post('/bloquear/preview',          autenticar, autorizar('admin', 'barbeiro'), preverBloqueio);
router.post('/bloquear/recorrente',       autenticar, autorizar('admin', 'barbeiro'), bloquearRecorrente);
router.delete('/bloquear/:id',            autenticar, autorizar('admin', 'barbeiro'), removerBloqueio);

module.exports = router;
