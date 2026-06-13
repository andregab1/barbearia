// ==========================================
// SERVIDOR: Barbearia API
// ==========================================
require('dotenv').config();
const app  = require('./app');
const PORT = process.env.PORT || 3000;

const { pool } = require('./src/config/database');

async function iniciar() {
  try {
    const [rows] = await pool.query('SELECT 1');
    console.log('✅ Banco de dados conectado com sucesso!');
    app.listen(PORT, '0.0.0.0', () => {
      console.log(`🚀 Servidor rodando na porta ${PORT}`);
    });
  } catch (err) {
    console.error('❌ Erro ao conectar no banco:', err.message);
    console.error('   DB_HOST:', process.env.DB_HOST);
    console.error('   DB_USER:', process.env.DB_USER);
    console.error('   DB_NAME:', process.env.DB_NAME);
    console.error('   DB_PORT:', process.env.DB_PORT);
    process.exit(1);
  }
}

iniciar();