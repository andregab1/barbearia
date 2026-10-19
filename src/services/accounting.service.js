async function ensureAccount(connection, tenantId, code, name, nature) {
  await connection.query(
    `INSERT IGNORE INTO accounting_accounts (barbearia_id, codigo, nome, natureza) VALUES (?, ?, ?, ?)`,
    [tenantId, code, name, nature],
  );
  const [[row]] = await connection.query(
    'SELECT id FROM accounting_accounts WHERE barbearia_id = ? AND codigo = ? LIMIT 1',
    [tenantId, code],
  );
  return row.id;
}

async function postEntry(connection, { tenantId, actorId, financialTransactionId, sourceType, sourceId, description, competenceDate, debit, credit, amount }) {
  const debitId = await ensureAccount(connection, tenantId, debit.code, debit.name, debit.nature);
  const creditId = await ensureAccount(connection, tenantId, credit.code, credit.name, credit.nature);
  const [result] = await connection.query(
    `INSERT INTO accounting_entries
       (barbearia_id, financial_transaction_id, source_type, source_id, descricao, data_competencia, criado_por)
     VALUES (?, ?, ?, ?, ?, DATE(?), ?)
     ON DUPLICATE KEY UPDATE id = LAST_INSERT_ID(id)`,
    [tenantId, financialTransactionId, sourceType, String(sourceId), description, competenceDate, actorId],
  );
  await connection.query(
    `INSERT INTO accounting_entry_lines (entry_id, account_id, tipo, valor, descricao)
     SELECT ?, ?, 'debit', ?, ? WHERE NOT EXISTS (SELECT 1 FROM accounting_entry_lines WHERE entry_id = ?)`,
    [result.insertId, debitId, amount, description, result.insertId],
  );
  await connection.query(
    `INSERT INTO accounting_entry_lines (entry_id, account_id, tipo, valor, descricao)
     SELECT ?, ?, 'credit', ?, ? WHERE (SELECT COUNT(*) FROM accounting_entry_lines WHERE entry_id = ?) = 1`,
    [result.insertId, creditId, amount, description, result.insertId],
  );
  return result.insertId;
}

module.exports = { ensureAccount, postEntry };
