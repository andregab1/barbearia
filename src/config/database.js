// ==========================================
// CONFIG: Banco de Dados MySQL
// Suporta variáveis Railway (MYSQL*) e locais (DB_*)
// ==========================================
const mysql  = require('mysql2/promise');
require('dotenv').config();

// Railway usa MYSQLHOST, MYSQLUSER etc.
// Localmente usamos DB_HOST, DB_USER etc.
const host     = process.env.DB_HOST     || process.env.MYSQLHOST     || 'localhost';
const user     = process.env.DB_USER     || process.env.MYSQLUSER     || 'root';
const password = process.env.DB_PASSWORD || process.env.MYSQLPASSWORD || '';
const database = process.env.DB_NAME     || process.env.MYSQLDATABASE || 'barbearia_db';
const port     = process.env.DB_PORT     || process.env.MYSQLPORT     || 3306;

console.log('🔌 Conectando ao banco:');
console.log('   host:', host);
console.log('   user:', user);
console.log('   database:', database);
console.log('   port:', port);

const pool = mysql.createPool({
  host,
  user,
  password,
  database,
  port:           parseInt(port),
  waitForConnections: true,
  connectionLimit:    10,
  dateStrings:        true,
  timezone:           '+00:00',
});

module.exports = { pool };