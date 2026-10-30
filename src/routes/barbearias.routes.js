// ==========================================
// ROTAS: Barbearias
// RF03 - Cadastro | RF04 - Personalização
// Logo salva como base64 no banco (sem filesystem)
// ==========================================
const router = require('express').Router();
const multer = require('multer');
const { autenticar, autorizar } = require('../middlewares/auth.middleware');
const {
  listarPublicas,
  cadastrar,
  buscar,
  buscarPublicaPorSlug,
  personalizar,
  atualizar,
} = require('../controllers/barbearias.controller');

// Usa memoryStorage — imagem fica em buffer, não em disco
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const valido = /png|jpg|jpeg/.test(file.mimetype);
    valido ? cb(null, true) : cb(new Error('Apenas PNG, JPG ou JPEG.'));
  },
});

// * ADICIONAR: cadastra uma barbearia para usuario autorizado.
router.post('/',                  autenticar, autorizar('admin'), cadastrar);
router.get('/',                   listarPublicas);
router.get('/slug/:slug',         buscarPublicaPorSlug);
router.get('/:id',                buscar);
// * EDITAR: atualiza dados e personalizacao; o upload fica em memoria e o
// * controller decide como persistir a imagem sem criar arquivo temporario.
router.put('/:id',                autenticar, autorizar('admin'), atualizar);
router.patch('/:id/personalizar', autenticar, autorizar('admin'), upload.single('logo'), personalizar);

module.exports = router;
