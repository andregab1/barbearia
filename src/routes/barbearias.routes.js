// ==========================================
// ROTAS: Barbearias
// RF03 - Cadastro | RF04 - Personalização
// ==========================================
const router     = require('express').Router();
const multer     = require('multer');
const path       = require('path');
const { autenticar, autorizar } = require('../middlewares/auth.middleware');
const { cadastrar, buscar, personalizar, atualizar } = require('../controllers/barbearias.controller');

// RF04: Configuração do multer para upload do logo PNG (background mobile)
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, path.join(__dirname, '..', 'uploads')),
  filename:    (req, file, cb) => cb(null, `logo_${Date.now()}${path.extname(file.originalname)}`),
});

const upload = multer({
  storage,
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const permitidos = /png|jpg|jpeg/;
    const valido = permitidos.test(path.extname(file.originalname).toLowerCase());
    valido ? cb(null, true) : cb(new Error('Apenas imagens PNG, JPG ou JPEG são permitidas.'));
  },
});

router.post('/',                    autenticar, autorizar('admin'), cadastrar);
router.get('/:id',                  buscar);
router.put('/:id',                  autenticar, autorizar('admin'), atualizar);
router.patch('/:id/personalizar',   autenticar, autorizar('admin'), upload.single('logo'), personalizar);

module.exports = router;
