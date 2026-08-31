// ==========================================
// APP: Configuração do Express e rotas
// ==========================================
const express    = require('express');
const cors       = require('cors');
const path       = require('path');
const { securityHeaders, rateLimit } = require('./src/middlewares/security.middleware');
const { requestContext } = require('./src/middlewares/request.middleware');

const authRoutes          = require('./src/routes/auth.routes');
const usuariosRoutes      = require('./src/routes/usuarios.routes');
const barbeariasRoutes    = require('./src/routes/barbearias.routes');
const servicosRoutes      = require('./src/routes/servicos.routes');
const agendamentosRoutes  = require('./src/routes/agendamentos.routes');
const colaboradoresRoutes = require('./src/routes/colaboradores.routes');
const agendaRoutes        = require('./src/routes/agenda.routes');
const notificacoesRoutes  = require('./src/routes/notificacoes.routes');
const relatoriosRoutes    = require('./src/routes/relatorios.routes');
const horariosRoutes      = require('./src/routes/horarios.routes');
const webhooksRoutes      = require('./src/routes/webhooks.routes');
const invitationsRoutes   = require('./src/routes/invitations.routes');
const financeRoutes       = require('./src/routes/finance.routes');
const billingRoutes       = require('./src/routes/billing.routes');

const app = express();

const allowedOrigins = (process.env.CORS_ORIGINS || 'http://localhost:3000,http://localhost:8080')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);
app.disable('x-powered-by');
app.use(requestContext);
if (process.env.TRUST_PROXY === '1') app.set('trust proxy', 1);
app.use(securityHeaders);
app.use(cors({
  origin(origin, callback) {
    const origemLocal = process.env.NODE_ENV !== 'production' &&
      /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin || '');
    if (!origin || origemLocal || allowedOrigins.includes(origin)) return callback(null, true);
    return callback(new Error('Origem não permitida pelo CORS.'));
  },
}));
app.use(express.json({ limit: '3mb' }));
app.use(express.urlencoded({ extended: true, limit: '3mb' }));
app.use('/uploads', express.static(path.join(__dirname, 'src/uploads')));

// ==========================================
// ROTAS: Autenticação gerenciada por rota
// ==========================================
app.use('/api/auth',          rateLimit({ windowMs: 15 * 60 * 1000, max: 30 }), authRoutes);
app.use('/api/usuarios',      usuariosRoutes);
app.use('/api/barbearias',    barbeariasRoutes);
app.use('/api/servicos',      servicosRoutes);
app.use('/api/colaboradores', colaboradoresRoutes);
app.use('/api/agendamentos',  agendamentosRoutes);
app.use('/api/agenda',        agendaRoutes);
app.use('/api/notificacoes',  notificacoesRoutes);
app.use('/api/relatorios',    relatoriosRoutes);
app.use('/api/horarios',      horariosRoutes);
app.use('/api/webhooks',      rateLimit({ windowMs: 60 * 1000, max: 180 }), webhooksRoutes);
app.use('/api/invitations',   rateLimit({ windowMs: 15 * 60 * 1000, max: 60 }), invitationsRoutes);
app.use('/api/finance',       financeRoutes);
app.use('/api/billing',       rateLimit({ windowMs: 60 * 1000, max: 30 }), billingRoutes);

app.get('/', (req, res) => res.json({ status: 'API Barbearia rodando!' }));
app.get('/health', (req, res) => res.json({ status: 'ok' }));

app.use((req, res) => res.status(404).json({ code: 'NOT_FOUND', erro: 'Rota não encontrada.' }));
app.use((err, req, res, next) => {
  if (res.headersSent) return next(err);
  const status = err.message?.includes('CORS') ? 403 : 500;
  if (status === 500) console.error('ERRO não tratado:', err.message);
  return res.status(status).json({ code: status === 403 ? 'CORS_FORBIDDEN' : 'INTERNAL_ERROR', erro: status === 403 ? err.message : 'Erro interno do servidor.' });
});

module.exports = app;
