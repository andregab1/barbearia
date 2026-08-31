require('dotenv').config();

const fs = require('fs/promises');
const path = require('path');
const { pool } = require('../src/config/database');

async function migrate() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      id INT UNSIGNED NOT NULL AUTO_INCREMENT,
      name VARCHAR(255) NOT NULL,
      applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      UNIQUE KEY uq_schema_migrations_name (name)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  `);

  const directory = path.join(__dirname, '..', 'migrations');
  const files = (await fs.readdir(directory))
    .filter((file) => file.endsWith('.sql'))
    .sort();

  for (const file of files) {
    const [rows] = await pool.query(
      'SELECT id FROM schema_migrations WHERE name = ? LIMIT 1',
      [file],
    );
    if (rows.length > 0) continue;

    const sql = await fs.readFile(path.join(directory, file), 'utf8');
    const statements = sql
      .split(';')
      .map((statement) => statement.trim())
      .filter(Boolean);
    const connection = await pool.getConnection();
    try {
      await connection.beginTransaction();
      for (const statement of statements) {
        await connection.query(statement);
      }
      await connection.query(
        'INSERT INTO schema_migrations (name) VALUES (?)',
        [file],
      );
      await connection.commit();
      console.log(`Migracao aplicada: ${file}`);
    } catch (error) {
      if (error.code === 'ER_DUP_FIELDNAME') {
        await connection.query(
          'INSERT IGNORE INTO schema_migrations (name) VALUES (?)',
          [file],
        );
        await connection.commit();
        console.log(`Migracao ja refletida no schema: ${file}`);
        continue;
      }
      await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
  }
}

migrate()
  .then(() => pool.end())
  .catch(async (error) => {
    console.error('Falha ao aplicar migracoes:', error.message);
    await pool.end();
    process.exitCode = 1;
  });
