require('dotenv').config();

const fs = require('fs/promises');
const path = require('path');
const mysql = require('mysql2/promise');

const VALIDATION_DATABASE = 'barbearia_schema_validation';
const MIGRATION_DATABASE = 'barbearia_migration_validation';

const expectedTables = [
  'agendamento_servicos',
  'agendamentos',
  'audit_logs',
  'barbearias',
  'cash_entries',
  'colaboradores',
  'commissions',
  'device_tokens',
  'horarios_bloqueados',
  'horarios_funcionamento',
  'invitations',
  'memberships',
  'notification_deliveries',
  'notification_preferences',
  'notificacoes',
  'otp_challenges',
  'payment_accounts',
  'payments',
  'plans',
  'refresh_tokens',
  'refunds',
  'schema_migrations',
  'servicos',
  'subscriptions',
  'usuarios',
  'webhook_events',
].sort();

function connectionConfig() {
  return {
    host: process.env.DB_HOST || '127.0.0.1',
    port: Number(process.env.DB_PORT || 3306),
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    multipleStatements: true,
  };
}

function targetValidationDatabase(sql) {
  return sql.replaceAll('barbearia_db', VALIDATION_DATABASE);
}

async function schemaSignature(connection, database) {
  const [columns] = await connection.query(
    `SELECT table_name, column_name, ordinal_position, column_type,
            is_nullable, column_default, extra
       FROM information_schema.columns
      WHERE table_schema = ?
      ORDER BY table_name, ordinal_position`,
    [database],
  );
  const [indexes] = await connection.query(
    `SELECT table_name, index_name, non_unique, seq_in_index, column_name, sub_part
       FROM information_schema.statistics
      WHERE table_schema = ?
      ORDER BY table_name, index_name, seq_in_index`,
    [database],
  );
  const [foreignKeys] = await connection.query(
    `SELECT k.table_name, k.constraint_name, k.column_name,
            k.referenced_table_name, k.referenced_column_name,
            r.update_rule, r.delete_rule
       FROM information_schema.key_column_usage k
       JOIN information_schema.referential_constraints r
         ON r.constraint_schema = k.constraint_schema
        AND r.constraint_name = k.constraint_name
        AND r.table_name = k.table_name
      WHERE k.constraint_schema = ?
        AND k.referenced_table_name IS NOT NULL
      ORDER BY k.table_name, k.constraint_name, k.ordinal_position`,
    [database],
  );

  return JSON.stringify({ columns, indexes, foreignKeys });
}

async function buildFromMigrations(connection) {
  await connection.query('CREATE DATABASE ?? CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci', [MIGRATION_DATABASE]);
  await connection.query('USE ??', [MIGRATION_DATABASE]);
  await connection.query(`
    CREATE TABLE schema_migrations (
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
    const sql = await fs.readFile(path.join(directory, file), 'utf8');
    const statements = sql.split(';').map((item) => item.trim()).filter(Boolean);
    for (const statement of statements) await connection.query(statement);
    await connection.query('INSERT INTO schema_migrations (name) VALUES (?)', [file]);
  }
}

async function validate() {
  if (VALIDATION_DATABASE !== 'barbearia_schema_validation' ||
      MIGRATION_DATABASE !== 'barbearia_migration_validation') {
    throw new Error('Nome inseguro para o banco temporario.');
  }

  const connection = await mysql.createConnection(connectionConfig());
  try {
    await connection.query('DROP DATABASE IF EXISTS ??', [VALIDATION_DATABASE]);
    await connection.query('DROP DATABASE IF EXISTS ??', [MIGRATION_DATABASE]);

    const schema = await fs.readFile(
      path.join(__dirname, '..', 'database', 'schema.sql'),
      'utf8',
    );
    await connection.query(targetValidationDatabase(schema));

    const [tableRows] = await connection.query(
      `SELECT table_name
         FROM information_schema.tables
        WHERE table_schema = ?
        ORDER BY table_name`,
      [VALIDATION_DATABASE],
    );
    const actualTables = tableRows.map((row) => row.TABLE_NAME || row.table_name).sort();

    if (JSON.stringify(actualTables) !== JSON.stringify(expectedTables)) {
      throw new Error(
        `Tabelas divergentes. Esperado: ${expectedTables.join(', ')}. ` +
        `Encontrado: ${actualTables.join(', ')}.`,
      );
    }

    const seed = await fs.readFile(
      path.join(__dirname, '..', 'database', 'seeds', 'development.sql'),
      'utf8',
    );
    const targetedSeed = targetValidationDatabase(seed);
    await connection.query(targetedSeed);
    await connection.query(targetedSeed);

    const [counts] = await connection.query(
      `SELECT
         (SELECT COUNT(*) FROM usuarios WHERE email LIKE '%@local.test') AS usuarios,
         (SELECT COUNT(*) FROM barbearias WHERE slug = 'barbearia-local') AS barbearias,
         (SELECT COUNT(*) FROM servicos WHERE barbearia_id =
           (SELECT id FROM barbearias WHERE slug = 'barbearia-local')) AS servicos,
         (SELECT COUNT(*) FROM horarios_funcionamento WHERE colaborador_id =
           (SELECT c.id FROM colaboradores c
            JOIN usuarios u ON u.id = c.usuario_id
            WHERE u.email = 'barbeiro@local.test')) AS horarios`,
    );

    const result = counts[0];
    if (result.usuarios !== 3 || result.barbearias !== 1 ||
        result.servicos !== 3 || result.horarios !== 5) {
      throw new Error(`Seed nao e idempotente: ${JSON.stringify(result)}`);
    }

    await buildFromMigrations(connection);
    const snapshotSignature = await schemaSignature(connection, VALIDATION_DATABASE);
    const migrationSignature = await schemaSignature(connection, MIGRATION_DATABASE);
    if (snapshotSignature !== migrationSignature) {
      throw new Error('O snapshot diverge da estrutura produzida pelas migracoes.');
    }

    console.log(
      `Schema validado: ${actualTables.length} tabelas identicas as migracoes; ` +
      'seed idempotente (3 usuarios, 1 barbearia, 3 servicos, 5 horarios).',
    );
  } finally {
    await connection.query('DROP DATABASE IF EXISTS ??', [VALIDATION_DATABASE]);
    await connection.query('DROP DATABASE IF EXISTS ??', [MIGRATION_DATABASE]);
    await connection.end();
  }
}

validate().catch((error) => {
  console.error('Falha na validacao do schema:', error.message);
  process.exitCode = 1;
});
