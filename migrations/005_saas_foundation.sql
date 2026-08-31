ALTER TABLE barbearias
  ADD COLUMN slug VARCHAR(80) NULL AFTER nome,
  ADD COLUMN email VARCHAR(150) NULL AFTER telefone,
  ADD COLUMN timezone VARCHAR(64) NOT NULL DEFAULT 'America/Sao_Paulo' AFTER endereco,
  ADD COLUMN onboarding_concluido TINYINT(1) NOT NULL DEFAULT 0 AFTER ativa;

CREATE UNIQUE INDEX uq_barbearias_slug ON barbearias (slug);

CREATE TABLE IF NOT EXISTS memberships (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  barbearia_id INT UNSIGNED NOT NULL,
  usuario_id INT UNSIGNED NOT NULL,
  papel ENUM('owner','manager','receptionist','professional') NOT NULL,
  ativo TINYINT(1) NOT NULL DEFAULT 1,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  atualizado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_membership_tenant_user (barbearia_id, usuario_id),
  KEY idx_membership_user (usuario_id, ativo),
  CONSTRAINT fk_membership_barbearia FOREIGN KEY (barbearia_id) REFERENCES barbearias (id) ON DELETE CASCADE,
  CONSTRAINT fk_membership_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS invitations (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  barbearia_id INT UNSIGNED NOT NULL,
  email VARCHAR(150) NULL,
  telefone VARCHAR(20) NULL,
  papel ENUM('manager','receptionist','professional') NOT NULL,
  token_hash CHAR(64) NOT NULL,
  expira_em DATETIME NOT NULL,
  aceito_em DATETIME NULL,
  convidado_por INT UNSIGNED NOT NULL,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_invitation_token (token_hash),
  KEY idx_invitation_tenant_status (barbearia_id, aceito_em, expira_em),
  CONSTRAINT fk_invitation_barbearia FOREIGN KEY (barbearia_id) REFERENCES barbearias (id) ON DELETE CASCADE,
  CONSTRAINT fk_invitation_inviter FOREIGN KEY (convidado_por) REFERENCES usuarios (id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS plans (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  codigo VARCHAR(40) NOT NULL,
  nome VARCHAR(80) NOT NULL,
  preco_mensal DECIMAL(10,2) NOT NULL,
  limite_profissionais SMALLINT UNSIGNED NULL,
  recursos JSON NULL,
  ativo TINYINT(1) NOT NULL DEFAULT 1,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_plan_codigo (codigo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO plans (codigo, nome, preco_mensal, limite_profissionais, recursos) VALUES
  ('trial', 'Período de teste', 0.00, 3, JSON_OBJECT('dias', 14)),
  ('professional', 'Profissional', 99.90, 10, JSON_OBJECT('financeiro', true, 'notificacoes', true));

CREATE TABLE IF NOT EXISTS subscriptions (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  barbearia_id INT UNSIGNED NOT NULL,
  plan_id INT UNSIGNED NOT NULL,
  provedor VARCHAR(30) NOT NULL DEFAULT 'mercado_pago',
  provedor_assinatura_id VARCHAR(120) NULL,
  status ENUM('trial','active','past_due','paused','canceled') NOT NULL DEFAULT 'trial',
  periodo_inicio DATETIME NOT NULL,
  periodo_fim DATETIME NOT NULL,
  cancelar_ao_final TINYINT(1) NOT NULL DEFAULT 0,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  atualizado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_subscription_tenant_status (barbearia_id, status),
  UNIQUE KEY uq_subscription_provider (provedor, provedor_assinatura_id),
  CONSTRAINT fk_subscription_barbearia FOREIGN KEY (barbearia_id) REFERENCES barbearias (id) ON DELETE CASCADE,
  CONSTRAINT fk_subscription_plan FOREIGN KEY (plan_id) REFERENCES plans (id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS payment_accounts (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  barbearia_id INT UNSIGNED NOT NULL,
  provedor VARCHAR(30) NOT NULL DEFAULT 'mercado_pago',
  conta_externa_id VARCHAR(120) NULL,
  status ENUM('pending','active','restricted','disabled') NOT NULL DEFAULT 'pending',
  credencial_criptografada TEXT NULL,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  atualizado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_payment_account_tenant_provider (barbearia_id, provedor),
  CONSTRAINT fk_payment_account_barbearia FOREIGN KEY (barbearia_id) REFERENCES barbearias (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS payments (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  barbearia_id INT UNSIGNED NOT NULL,
  agendamento_id INT UNSIGNED NULL,
  usuario_id INT UNSIGNED NULL,
  provedor VARCHAR(30) NOT NULL DEFAULT 'mercado_pago',
  provedor_pagamento_id VARCHAR(120) NULL,
  idempotency_key VARCHAR(100) NOT NULL,
  tipo ENUM('subscription','deposit','service') NOT NULL,
  metodo ENUM('pix','credit_card','debit_card','cash','other') NOT NULL,
  status ENUM('pending','authorized','paid','failed','canceled','refunded','partially_refunded') NOT NULL DEFAULT 'pending',
  valor DECIMAL(10,2) NOT NULL,
  moeda CHAR(3) NOT NULL DEFAULT 'BRL',
  pago_em DATETIME NULL,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  atualizado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_payment_idempotency (idempotency_key),
  UNIQUE KEY uq_payment_provider_id (provedor, provedor_pagamento_id),
  KEY idx_payment_tenant_status_date (barbearia_id, status, criado_em),
  CONSTRAINT fk_payment_barbearia FOREIGN KEY (barbearia_id) REFERENCES barbearias (id) ON DELETE RESTRICT,
  CONSTRAINT fk_payment_agendamento FOREIGN KEY (agendamento_id) REFERENCES agendamentos (id) ON DELETE SET NULL,
  CONSTRAINT fk_payment_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS webhook_events (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  provedor VARCHAR(30) NOT NULL,
  evento_externo_id VARCHAR(160) NOT NULL,
  tipo VARCHAR(80) NOT NULL,
  payload JSON NOT NULL,
  processado_em DATETIME NULL,
  erro VARCHAR(500) NULL,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_webhook_provider_event (provedor, evento_externo_id),
  KEY idx_webhook_pending (processado_em, criado_em)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS cash_entries (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  barbearia_id INT UNSIGNED NOT NULL,
  payment_id BIGINT UNSIGNED NULL,
  criado_por INT UNSIGNED NULL,
  tipo ENUM('income','expense','refund','commission') NOT NULL,
  categoria VARCHAR(60) NOT NULL,
  descricao VARCHAR(240) NULL,
  valor DECIMAL(10,2) NOT NULL,
  ocorrido_em DATETIME NOT NULL,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_cash_tenant_date (barbearia_id, ocorrido_em),
  CONSTRAINT fk_cash_barbearia FOREIGN KEY (barbearia_id) REFERENCES barbearias (id) ON DELETE RESTRICT,
  CONSTRAINT fk_cash_payment FOREIGN KEY (payment_id) REFERENCES payments (id) ON DELETE SET NULL,
  CONSTRAINT fk_cash_creator FOREIGN KEY (criado_por) REFERENCES usuarios (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS audit_logs (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  barbearia_id INT UNSIGNED NULL,
  usuario_id INT UNSIGNED NULL,
  acao VARCHAR(80) NOT NULL,
  recurso VARCHAR(80) NOT NULL,
  recurso_id VARCHAR(80) NULL,
  request_id CHAR(36) NULL,
  detalhes JSON NULL,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_audit_tenant_date (barbearia_id, criado_em),
  KEY idx_audit_user_date (usuario_id, criado_em),
  CONSTRAINT fk_audit_barbearia FOREIGN KEY (barbearia_id) REFERENCES barbearias (id) ON DELETE SET NULL,
  CONSTRAINT fk_audit_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
