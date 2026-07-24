// ==========================================
// CONFIG: Banco de Dados MySQL
// Suporta DATABASE_URL (Railway) ou variáveis separadas
// ==========================================
const mysql = require('mysql2/promise');

let poolConfig;

if (process.env.DATABASE_URL) {
  // Railway: usa URL de conexão direta
  // mysql://user:password@host:port/database
  const url = new URL(process.env.DATABASE_URL);
  poolConfig = {
    host:     url.hostname,
    port:     parseInt(url.port) || 3306,
    user:     url.username,
    password: url.password,
    database: url.pathname.replace('/', ''),
  };
  console.log('🔌 Conectando via DATABASE_URL');
  console.log('   host:', url.hostname);
  console.log('   database:', url.pathname.replace('/', ''));
} else {
  // Local: usa variáveis separadas do .env
  require('dotenv').config();
  poolConfig = {
    host:     process.env.DB_HOST     || 'localhost',
    port:     parseInt(process.env.DB_PORT) || 3306,
    user:     process.env.DB_USER     || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME     || 'barbearia_db',
  };
  console.log('🔌 Conectando via variáveis locais');
  console.log('   host:', poolConfig.host);
  console.log('   database:', poolConfig.database);
}

const pool = mysql.createPool({
  ...poolConfig,
  waitForConnections: true,
  connectionLimit:    10,
  dateStrings:        true,
  timezone:           '+00:00',
});

module.exports = { pool };