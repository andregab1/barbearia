ALTER TABLE expenses
  ADD COLUMN legacy_cash_entry_id BIGINT UNSIGNED NULL AFTER id,
  ADD UNIQUE KEY uq_expense_legacy_cash_entry (legacy_cash_entry_id),
  ADD CONSTRAINT fk_expense_legacy_cash_entry FOREIGN KEY (legacy_cash_entry_id) REFERENCES cash_entries (id) ON DELETE RESTRICT;

INSERT IGNORE INTO financial_accounts (barbearia_id, nome, tipo)
SELECT id, 'Caixa', 'cash' FROM barbearias;

INSERT IGNORE INTO financial_categories (barbearia_id, nome, tipo)
SELECT DISTINCT ce.barbearia_id, LEFT(ce.categoria, 80), 'expense'
FROM cash_entries ce WHERE ce.tipo = 'expense';

INSERT IGNORE INTO expenses
  (legacy_cash_entry_id, barbearia_id, category_id, financial_account_id,
   responsible_user_id, descricao, valor, data_competencia, data_vencimento,
   pago_em, status, criado_por, criado_em)
SELECT ce.id, ce.barbearia_id, fc.id, fa.id, COALESCE(ce.criado_por, b.admin_id),
       COALESCE(NULLIF(ce.descricao, ''), ce.categoria), ce.valor,
       DATE(ce.ocorrido_em), DATE(ce.ocorrido_em), ce.ocorrido_em, 'paid',
       COALESCE(ce.criado_por, b.admin_id), ce.criado_em
FROM cash_entries ce
JOIN barbearias b ON b.id = ce.barbearia_id
JOIN financial_accounts fa ON fa.barbearia_id = ce.barbearia_id AND fa.nome = 'Caixa'
JOIN financial_categories fc ON fc.barbearia_id = ce.barbearia_id
 AND fc.nome = LEFT(ce.categoria, 80) AND fc.tipo = 'expense'
WHERE ce.tipo = 'expense';

INSERT IGNORE INTO financial_movements
  (barbearia_id, movement_type, operation, origin_type, origin_id,
   financial_account_id, category_id, expense_id, amount, movement_date,
   description, status, created_by, created_at)
SELECT e.barbearia_id, 'expense', 'expense_paid', 'expense', e.id,
       e.financial_account_id, e.category_id, e.id, e.valor, e.pago_em,
       e.descricao, 'confirmed', e.criado_por, e.criado_em
FROM expenses e
WHERE e.legacy_cash_entry_id IS NOT NULL AND e.status = 'paid';
