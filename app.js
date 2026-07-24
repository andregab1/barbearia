// ==========================================
// APP: Configuração do Express e rotas
// ==========================================
const express    = require('express');
const cors       = require('cors');
const path       = require('path');

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

const app = express();

app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
app.use('/uploads', express.static(path.join(__dirname, 'src/uploads')));

// ==========================================
// ROTAS: Autenticação gerenciada por rota
// ==========================================
app.use('/api/auth',          authRoutes);
app.use('/api/usuarios',      usuariosRoutes);
app.use('/api/barbearias',    barbeariasRoutes);
app.use('/api/servicos',      servicosRoutes);
app.use('/api/colaboradores', colaboradoresRoutes);
app.use('/api/agendamentos',  agendamentosRoutes);
app.use('/api/agenda',        agendaRoutes);
app.use('/api/notificacoes',  notificacoesRoutes);
app.use('/api/relatorios',    relatoriosRoutes);
app.use('/api/horarios',      horariosRoutes);

app.get('/', (req, res) => res.json({ status: 'API Barbearia rodando!' }));

module.exports = app;