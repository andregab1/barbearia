// ==========================================
// MIDDLEWARE: Autenticação JWT e Autorização
// ==========================================
const jwt = require('jsonwebtoken');

function autenticar(req, res, next) {
  const header = req.headers['authorization'];
  
  if (!header) {
    return res.status(401).json({ erro: 'Token não fornecido.' });
  }

  const token = header.split(' ')[1];
  if (!token) {
    return res.status(401).json({ erro: 'Formato inválido. Use: Bearer <token>' });
  }

  try {
    // Verifica o token usando a chave secreta do seu .env
    req.usuario = jwt.verify(token, process.env.JWT_SECRET);
    next();
  } catch (err) {
    return res.status(401).json({ erro: 'Token inválido ou expirado.' });
  }
}

function autorizar(...roles) {
  return (req, res, next) => {
    // Verifica se o usuário logado possui a role necessária para a rota
    if (!req.usuario || !roles.includes(req.usuario.role)) {
      return res.status(403).json({ erro: 'Acesso não permitido para este perfil.' });
    }
    next();
  };
}

module.exports = { autenticar, autorizar };