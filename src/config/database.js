// ==========================================
// CONFIG: Conexão com MySQL
// ==========================================
const mysql = require('mysql2/promise');

const pool = mysql.createPool({
  host:               process.env.DB_HOST     || 'localhost',
  user:               process.env.DB_USER     || 'root',
  password:           process.env.DB_PASSWORD || '',
  database:           process.env.DB_NAME     || 'barbearia_db',
  waitForConnections: true,
  connectionLimit:    10,
  queueLimit:         0,
  dateStrings:        true,
  timezone:           '+00:00',
});

const testDB = async () => {
  try {
    const conn = await pool.getConnection();
    console.log('Banco de dados conectado com sucesso!');
    conn.release();
  } catch (err) {
    console.error('Erro ao conectar no banco:', err.message);
    process.exit(1);
  }
};

module.exports = { pool, testDB };