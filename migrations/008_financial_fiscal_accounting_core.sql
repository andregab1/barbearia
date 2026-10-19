ALTER TABLE agendamentos
  ADD COLUMN concluido_em DATETIME NULL AFTER status;

CREATE TABLE IF NOT EXISTS financial_accounts (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  barbearia_id INT UNSIGNED NOT NULL,
  nome VARCHAR(80) NOT NULL,
  tipo ENUM('cash','bank','pix','card','other') NOT NULL,
  ativo TINYINT(1) NOT NULL DEFAULT 1,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  atualizado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_financial_account_tenant_name (barbearia_id, nome),
  KEY idx_financial_account_tenant_active (barbearia_id, ativo),
  CONSTRAINT fk_financial_account_barbearia FOREIGN KEY (barbearia_id) REFERENCES barbearias (id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS financial_categories (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  barbearia_id INT UNSIGNED NOT NULL,
  nome VARCHAR(80) NOT NULL,
  tipo ENUM('income','expense') NOT NULL,
  ativo TINYINT(1) NOT NULL DEFAULT 1,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  atualizado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_financial_category_tenant_name_type (barbearia_id, nome, tipo),
  KEY idx_financial_category_tenant_active (barbearia_id, tipo, ativo),
  CONSTRAINT fk_financial_category_barbearia FOREIGN KEY (barbearia_id) REFERENCES barbearias (id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS financial_transactions (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  barbearia_id INT UNSIGNED NOT NULL,
  tipo ENUM('forecast','income','expense','refund','reversal') NOT NULL,
  status ENUM('pending','posted','partially_paid','paid','cancelled','reversed') NOT NULL DEFAULT 'pending',
  category_id INT UNSIGNED NULL,
  account_id INT UNSIGNED NULL,
  agendamento_id INT UNSIGNED NULL,
  colaborador_id INT UNSIGNED NULL,
  cliente_id INT UNSIGNED NULL,
  transacao_origem_id BIGINT UNSIGNED NULL,
  source_type VARCHAR(40) NOT NULL,
  source_id VARCHAR(100) NOT NULL,
  descricao VARCHAR(240) NOT NULL,
  valor_bruto DECIMAL(12,2) NOT NULL,
  valor_desconto DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  valor_taxa DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  valor_liquido DECIMAL(12,2) NOT NULL,
  data_competencia DATE NOT NULL,
  data_vencimento DATE NULL,
  pago_em DATETIME NULL,
  criado_por INT UNSIGNED NULL,
  cancelado_por INT UNSIGNED NULL,
  motivo_cancelamento VARCHAR(240) NULL,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  atualizado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_financial_source_event (barbearia_id, source_type, source_id, tipo),
  KEY idx_financial_tenant_competence (barbearia_id, data_competencia, status),
  KEY idx_financial_tenant_professional (barbearia_id, colaborador_id, data_competencia),
  KEY idx_financial_appointment (agendamento_id),
  CONSTRAINT fk_financial_transaction_barbearia FOREIGN KEY (barbearia_id) REFERENCES barbearias (id) ON DELETE RESTRICT,
  CONSTRAINT fk_financial_transaction_category FOREIGN KEY (category_id) REFERENCES financial_categories (id) ON DELETE RESTRICT,
  CONSTRAINT fk_financial_transaction_account FOREIGN KEY (account_id) REFERENCES financial_accounts (id) ON DELETE RESTRICT,
  CONSTRAINT fk_financial_transaction_appointment FOREIGN KEY (agendamento_id) REFERENCES agendamentos (id) ON DELETE RESTRICT,
  CONSTRAINT fk_financial_transaction_professional FOREIGN KEY (colaborador_id) REFERENCES colaboradores (id) ON DELETE RESTRICT,
  CONSTRAINT fk_financial_transaction_client FOREIGN KEY (cliente_id) REFERENCES usuarios (id) ON DELETE RESTRICT,
  CONSTRAINT fk_financial_transaction_origin FOREIGN KEY (transacao_origem_id) REFERENCES financial_transactions (id) ON DELETE RESTRICT,
  CONSTRAINT fk_financial_transaction_creator FOREIGN KEY (criado_por) REFERENCES usuarios (id) ON DELETE SET NULL,
  CONSTRAINT fk_financial_transaction_canceller FOREIGN KEY (cancelado_por) REFERENCES usuarios (id) ON DELETE SET NULL,
  CONSTRAINT chk_financial_amounts CHECK (valor_bruto >= 0 AND valor_desconto >= 0 AND valor_taxa >= 0 AND valor_liquido >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS payment_allocations (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  barbearia_id INT UNSIGNED NOT NULL,
  payment_id BIGINT UNSIGNED NOT NULL,
  financial_transaction_id BIGINT UNSIGNED NOT NULL,
  valor DECIMAL(12,2) NOT NULL,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_payment_allocation (payment_id, financial_transaction_id),
  KEY idx_allocation_transaction (financial_transaction_id),
  CONSTRAINT fk_allocation_barbearia FOREIGN KEY (barbearia_id) REFERENCES barbearias (id) ON DELETE RESTRICT,
  CONSTRAINT fk_allocation_payment FOREIGN KEY (payment_id) REFERENCES payments (id) ON DELETE RESTRICT,
  CONSTRAINT fk_allocation_transaction FOREIGN KEY (financial_transaction_id) REFERENCES financial_transactions (id) ON DELETE RESTRICT,
  CONSTRAINT chk_allocation_positive CHECK (valor > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS outbox_events (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  barbearia_id INT UNSIGNED NOT NULL,
  tipo VARCHAR(80) NOT NULL,
  aggregate_type VARCHAR(60) NOT NULL,
  aggregate_id VARCHAR(100) NOT NULL,
  payload JSON NOT NULL,
  status ENUM('pending','processing','processed','failed') NOT NULL DEFAULT 'pending',
  tentativas TINYINT UNSIGNED NOT NULL DEFAULT 0,
  processar_apos DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  processado_em DATETIME NULL,
  ultimo_erro VARCHAR(500) NULL,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_outbox_event (barbearia_id, tipo, aggregate_type, aggregate_id),
  KEY idx_outbox_pending (status, processar_apos),
  CONSTRAINT fk_outbox_barbearia FOREIGN KEY (barbearia_id) REFERENCES barbearias (id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS fiscal_settings (
  barbearia_id INT UNSIGNED NOT NULL,
  razao_social VARCHAR(180) NULL,
  nome_fantasia VARCHAR(180) NULL,
  cnpj CHAR(14) NULL,
  inscricao_municipal VARCHAR(40) NULL,
  municipio VARCHAR(100) NULL,
  uf CHAR(2) NULL,
  regime_tributario VARCHAR(60) NULL,
  codigo_servico VARCHAR(40) NULL,
  aliquota DECIMAL(7,4) NULL,
  ambiente ENUM('sandbox','production') NOT NULL DEFAULT 'sandbox',
  provedor VARCHAR(60) NULL,
  emissao_automatica TINYINT(1) NOT NULL DEFAULT 0,
  ativo TINYINT(1) NOT NULL DEFAULT 0,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  atualizado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (barbearia_id),
  CONSTRAINT fk_fiscal_settings_barbearia FOREIGN KEY (barbearia_id) REFERENCES barbearias (id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS fiscal_documents (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  barbearia_id INT UNSIGNED NOT NULL,
  agendamento_id INT UNSIGNED NOT NULL,
  cliente_id INT UNSIGNED NOT NULL,
  financial_transaction_id BIGINT UNSIGNED NOT NULL,
  payment_id BIGINT UNSIGNED NULL,
  document_type ENUM('nfse','other') NOT NULL DEFAULT 'nfse',
  provider VARCHAR(60) NOT NULL,
  provider_document_id VARCHAR(160) NULL,
  idempotency_key VARCHAR(100) NOT NULL,
  status ENUM('pending','processing','authorized','rejected','cancelled','error') NOT NULL DEFAULT 'pending',
  total_amount DECIMAL(12,2) NOT NULL,
  service_amount DECIMAL(12,2) NOT NULL,
  tax_amount DECIMAL(12,2) NULL,
  snapshot JSON NOT NULL,
  pdf_url VARCHAR(500) NULL,
  xml_url VARCHAR(500) NULL,
  issued_at DATETIME NULL,
  cancelled_at DATETIME NULL,
  error_message VARCHAR(500) NULL,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  atualizado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_fiscal_idempotency (idempotency_key),
  UNIQUE KEY uq_fiscal_appointment_type (barbearia_id, agendamento_id, document_type),
  UNIQUE KEY uq_fiscal_provider_document (provider, provider_document_id),
  KEY idx_fiscal_tenant_status (barbearia_id, status, criado_em),
  CONSTRAINT fk_fiscal_document_barbearia FOREIGN KEY (barbearia_id) REFERENCES barbearias (id) ON DELETE RESTRICT,
  CONSTRAINT fk_fiscal_document_appointment FOREIGN KEY (agendamento_id) REFERENCES agendamentos (id) ON DELETE RESTRICT,
  CONSTRAINT fk_fiscal_document_client FOREIGN KEY (cliente_id) REFERENCES usuarios (id) ON DELETE RESTRICT,
  CONSTRAINT fk_fiscal_document_transaction FOREIGN KEY (financial_transaction_id) REFERENCES financial_transactions (id) ON DELETE RESTRICT,
  CONSTRAINT fk_fiscal_document_payment FOREIGN KEY (payment_id) REFERENCES payments (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS accounting_accounts (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  barbearia_id INT UNSIGNED NOT NULL,
  parent_id INT UNSIGNED NULL,
  codigo VARCHAR(30) NOT NULL,
  nome VARCHAR(120) NOT NULL,
  natureza ENUM('asset','liability','equity','revenue','expense') NOT NULL,
  ativo TINYINT(1) NOT NULL DEFAULT 1,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  atualizado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_accounting_account_code (barbearia_id, codigo),
  CONSTRAINT fk_accounting_account_barbearia FOREIGN KEY (barbearia_id) REFERENCES barbearias (id) ON DELETE RESTRICT,
  CONSTRAINT fk_accounting_account_parent FOREIGN KEY (parent_id) REFERENCES accounting_accounts (id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS accounting_entries (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  barbearia_id INT UNSIGNED NOT NULL,
  financial_transaction_id BIGINT UNSIGNED NULL,
  source_type VARCHAR(40) NOT NULL,
  source_id VARCHAR(100) NOT NULL,
  descricao VARCHAR(240) NOT NULL,
  data_competencia DATE NOT NULL,
  status ENUM('draft','posted','reversed') NOT NULL DEFAULT 'posted',
  criado_por INT UNSIGNED NULL,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_accounting_source (barbearia_id, source_type, source_id),
  KEY idx_accounting_tenant_competence (barbearia_id, data_competencia, status),
  CONSTRAINT fk_accounting_entry_barbearia FOREIGN KEY (barbearia_id) REFERENCES barbearias (id) ON DELETE RESTRICT,
  CONSTRAINT fk_accounting_entry_transaction FOREIGN KEY (financial_transaction_id) REFERENCES financial_transactions (id) ON DELETE RESTRICT,
  CONSTRAINT fk_accounting_entry_creator FOREIGN KEY (criado_por) REFERENCES usuarios (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS accounting_entry_lines (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  entry_id BIGINT UNSIGNED NOT NULL,
  account_id INT UNSIGNED NOT NULL,
  tipo ENUM('debit','credit') NOT NULL,
  valor DECIMAL(12,2) NOT NULL,
  descricao VARCHAR(240) NULL,
  PRIMARY KEY (id),
  KEY idx_accounting_line_entry (entry_id),
  CONSTRAINT fk_accounting_line_entry FOREIGN KEY (entry_id) REFERENCES accounting_entries (id) ON DELETE RESTRICT,
  CONSTRAINT fk_accounting_line_account FOREIGN KEY (account_id) REFERENCES accounting_accounts (id) ON DELETE RESTRICT,
  CONSTRAINT chk_accounting_line_positive CHECK (valor > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO financial_accounts (barbearia_id, nome, tipo)
SELECT id, 'Caixa', 'cash' FROM barbearias;

INSERT IGNORE INTO financial_categories (barbearia_id, nome, tipo)
SELECT id, 'Servicos', 'income' FROM barbearias;

INSERT IGNORE INTO financial_categories (barbearia_id, nome, tipo)
SELECT id, 'Outras despesas', 'expense' FROM barbearias;

INSERT IGNORE INTO financial_transactions
  (barbearia_id, tipo, status, category_id, agendamento_id, colaborador_id, cliente_id,
   source_type, source_id, descricao, valor_bruto, valor_liquido, data_competencia,
   data_vencimento, criado_em)
SELECT c.barbearia_id, 'forecast', 'posted', fc.id, a.id, a.colaborador_id, a.cliente_id,
       'appointment', CAST(a.id AS CHAR), CONCAT('Previsao: ', s.nome), a.valor_cobrado,
       a.valor_cobrado, DATE(a.data_hora), DATE(a.data_hora), a.criado_em
  FROM agendamentos a
  JOIN colaboradores c ON c.id = a.colaborador_id
  JOIN servicos s ON s.id = a.servico_id
  JOIN financial_categories fc ON fc.barbearia_id = c.barbearia_id
   AND fc.nome = 'Servicos' AND fc.tipo = 'income'
 WHERE a.status IN ('pendente','confirmado');

INSERT IGNORE INTO financial_transactions
  (barbearia_id, tipo, status, category_id, agendamento_id, colaborador_id, cliente_id,
   source_type, source_id, descricao, valor_bruto, valor_liquido, data_competencia,
   data_vencimento, criado_em)
SELECT c.barbearia_id, 'income', 'pending', fc.id, a.id, a.colaborador_id, a.cliente_id,
       'appointment', CAST(a.id AS CHAR), s.nome, a.valor_cobrado, a.valor_cobrado,
       DATE(a.data_hora), DATE(a.data_hora), a.criado_em
  FROM agendamentos a
  JOIN colaboradores c ON c.id = a.colaborador_id
  JOIN servicos s ON s.id = a.servico_id
  JOIN financial_categories fc ON fc.barbearia_id = c.barbearia_id
   AND fc.nome = 'Servicos' AND fc.tipo = 'income'
 WHERE a.status = 'concluido';
