// ==========================================
// SERVIDOR: Entrada principal da aplicação
// ==========================================
require('dotenv').config();
const app = require('./app');
const { testDB } = require('./src/config/database');

const PORT = process.env.PORT || 3000;

async function start() {
  await testDB();
  app.listen(PORT, () => {
    console.log(`Servidor rodando na porta ${PORT}`);
  });
}

start();
