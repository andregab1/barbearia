const fs = require('node:fs');
const path = require('node:path');
const mysql = require('mysql2/promise');

require('dotenv').config();

const outputDirectory = path.join(__dirname, '..', 'docs');
const diagramPath = path.join(outputDirectory, 'database-der.mmd');
const reportPath = path.join(outputDirectory, 'database-der.md');
const snapshotPath = path.join(outputDirectory, 'database-schema-snapshot.json');

function mermaidIdentifier(value) {
  return String(value).replace(/[^A-Za-z0-9_]/g, '_');
}

function mermaidType(column) {
  return mermaidIdentifier(column.DATA_TYPE || 'unknown');
}

function quote(value) {
  return String(value ?? '').replace(/"/g, "'");
}

async function main() {
  const database = process.env.DB_NAME;
  if (!database) throw new Error('DB_NAME não está definido no .env');

  const connection = await mysql.createConnection({
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT) || 3306,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database,
  });

  try {
    const [tables] = await connection.query(
      `SELECT TABLE_NAME, TABLE_TYPE, ENGINE, TABLE_ROWS, TABLE_COMMENT
         FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = ?
        ORDER BY TABLE_NAME`,
      [database],
    );
    const [columns] = await connection.query(
      `SELECT TABLE_NAME, ORDINAL_POSITION, COLUMN_NAME, DATA_TYPE, COLUMN_TYPE,
              IS_NULLABLE, COLUMN_KEY, EXTRA, COLUMN_DEFAULT, COLUMN_COMMENT
         FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = ?
        ORDER BY TABLE_NAME, ORDINAL_POSITION`,
      [database],
    );
    const [foreignKeys] = await connection.query(
      `SELECT k.CONSTRAINT_NAME, k.TABLE_NAME, k.COLUMN_NAME,
              k.REFERENCED_TABLE_NAME, k.REFERENCED_COLUMN_NAME,
              r.UPDATE_RULE, r.DELETE_RULE
         FROM information_schema.KEY_COLUMN_USAGE k
         JOIN information_schema.REFERENTIAL_CONSTRAINTS r
           ON r.CONSTRAINT_SCHEMA = k.CONSTRAINT_SCHEMA
          AND r.CONSTRAINT_NAME = k.CONSTRAINT_NAME
          AND r.TABLE_NAME = k.TABLE_NAME
        WHERE k.TABLE_SCHEMA = ?
          AND k.REFERENCED_TABLE_NAME IS NOT NULL
        ORDER BY k.TABLE_NAME, k.CONSTRAINT_NAME, k.ORDINAL_POSITION`,
      [database],
    );
    const [indexes] = await connection.query(
      `SELECT TABLE_NAME, INDEX_NAME, NON_UNIQUE, SEQ_IN_INDEX, COLUMN_NAME
         FROM information_schema.STATISTICS
        WHERE TABLE_SCHEMA = ?
        ORDER BY TABLE_NAME, INDEX_NAME, SEQ_IN_INDEX`,
      [database],
    );

    const columnsByTable = new Map(tables.map((table) => [table.TABLE_NAME, []]));
    for (const column of columns) columnsByTable.get(column.TABLE_NAME)?.push(column);

    const foreignKeyColumns = new Set(
      foreignKeys.map((key) => `${key.TABLE_NAME}.${key.COLUMN_NAME}`),
    );
    const uniqueColumns = new Set(
      indexes
        .filter((index) => index.NON_UNIQUE === 0 && index.INDEX_NAME !== 'PRIMARY')
        .map((index) => `${index.TABLE_NAME}.${index.COLUMN_NAME}`),
    );

    const diagram = ['erDiagram'];
    for (const table of tables) {
      diagram.push(`  ${mermaidIdentifier(table.TABLE_NAME)} {`);
      for (const column of columnsByTable.get(table.TABLE_NAME) || []) {
        const markers = [];
        if (column.COLUMN_KEY === 'PRI') markers.push('PK');
        if (foreignKeyColumns.has(`${table.TABLE_NAME}.${column.COLUMN_NAME}`)) markers.push('FK');
        if (uniqueColumns.has(`${table.TABLE_NAME}.${column.COLUMN_NAME}`)) markers.push('UK');
        const details = [
          column.COLUMN_TYPE,
          column.IS_NULLABLE === 'YES' ? 'NULL' : 'NOT NULL',
          column.EXTRA,
          column.COLUMN_COMMENT,
        ].filter(Boolean).join('; ');
        diagram.push(
          `    ${mermaidType(column)} ${mermaidIdentifier(column.COLUMN_NAME)}` +
          `${markers.length ? ` ${markers.join(',')}` : ''} "${quote(details)}"`,
        );
      }
      diagram.push('  }');
    }

    const columnLookup = new Map(
      columns.map((column) => [`${column.TABLE_NAME}.${column.COLUMN_NAME}`, column]),
    );
    for (const key of foreignKeys) {
      const childColumn = columnLookup.get(`${key.TABLE_NAME}.${key.COLUMN_NAME}`);
      const parentCardinality = childColumn?.IS_NULLABLE === 'YES' ? 'o|' : '||';
      diagram.push(
        `  ${mermaidIdentifier(key.REFERENCED_TABLE_NAME)} ${parentCardinality}--o{ ` +
        `${mermaidIdentifier(key.TABLE_NAME)} : "${quote(key.CONSTRAINT_NAME)}: ` +
        `${quote(key.COLUMN_NAME)} -> ${quote(key.REFERENCED_COLUMN_NAME)}"`,
      );
    }

    const snapshot = {
      generatedAt: new Date().toISOString(),
      database,
      totals: {
        tables: tables.length,
        columns: columns.length,
        foreignKeys: foreignKeys.length,
        indexes: indexes.length,
      },
      tables,
      columns,
      foreignKeys,
      indexes,
    };

    const report = [
      '# DER do banco de dados MySQL',
      '',
      `Schema analisado: \`${database}\``,
      '',
      `Inventário real: **${tables.length} tabelas**, **${columns.length} colunas**, ` +
        `**${foreignKeys.length} chaves estrangeiras** e **${indexes.length} entradas de índice**.`,
      '',
      '> Gerado diretamente de `information_schema`; nenhuma tabela foi inferida a partir das migrations.',
      '',
      '```mermaid',
      ...diagram,
      '```',
      '',
      '## Regras de relacionamento',
      '',
      '| Restrição | Tabela/coluna filha | Tabela/coluna pai | ON UPDATE | ON DELETE |',
      '|---|---|---|---|---|',
      ...foreignKeys.map((key) =>
        `| ${key.CONSTRAINT_NAME} | ${key.TABLE_NAME}.${key.COLUMN_NAME} | ` +
        `${key.REFERENCED_TABLE_NAME}.${key.REFERENCED_COLUMN_NAME} | ` +
        `${key.UPDATE_RULE} | ${key.DELETE_RULE} |`,
      ),
      '',
      'O snapshot técnico completo está em `docs/database-schema-snapshot.json`.',
      '',
    ].join('\n');

    fs.mkdirSync(outputDirectory, { recursive: true });
    fs.writeFileSync(diagramPath, `${diagram.join('\n')}\n`, 'utf8');
    fs.writeFileSync(reportPath, report, 'utf8');
    fs.writeFileSync(snapshotPath, `${JSON.stringify(snapshot, null, 2)}\n`, 'utf8');

    console.log(JSON.stringify(snapshot.totals));
    console.log(reportPath);
  } finally {
    await connection.end();
  }
}

main().catch((error) => {
  console.error(`Falha ao gerar DER: ${error.code || error.message}`);
  process.exitCode = 1;
});
