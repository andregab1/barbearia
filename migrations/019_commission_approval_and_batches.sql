CREATE TABLE IF NOT EXISTS commission_settings (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  barbearia_id INT UNSIGNED NOT NULL,
  approval_mode ENUM('manual','automatic') NOT NULL DEFAULT 'manual',
  version INT UNSIGNED NOT NULL DEFAULT 1,
  updated_by INT UNSIGNED NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_commission_settings_business (barbearia_id),
  CONSTRAINT fk_commission_settings_business FOREIGN KEY (barbearia_id) REFERENCES barbearias (id) ON DELETE RESTRICT,
  CONSTRAINT fk_commission_settings_updater FOREIGN KEY (updated_by) REFERENCES usuarios (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO commission_settings (barbearia_id, approval_mode, version)
SELECT id, 'automatic', 1 FROM barbearias WHERE ativa = 1;

ALTER TABLE commission_entitlements
  ADD COLUMN approval_mode_snapshot ENUM('manual','automatic') NOT NULL DEFAULT 'automatic' AFTER status,
  ADD COLUMN approval_status ENUM('pending','approved') NOT NULL DEFAULT 'approved' AFTER approval_mode_snapshot,
  ADD COLUMN approved_at DATETIME NULL AFTER approval_status,
  ADD COLUMN approved_by INT UNSIGNED NULL AFTER approved_at,
  ADD COLUMN approval_source ENUM('manual','automatic') NULL AFTER approved_by,
  ADD KEY idx_commission_entitlement_approval (barbearia_id, profissional_id, approval_status, completed_at),
  ADD CONSTRAINT fk_commission_entitlement_approver FOREIGN KEY (approved_by) REFERENCES usuarios (id) ON DELETE SET NULL;

CREATE TABLE IF NOT EXISTS commission_approval_requests (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  barbearia_id INT UNSIGNED NOT NULL,
  idempotency_key VARCHAR(120) NOT NULL,
  payload_hash CHAR(64) NOT NULL,
  response_json JSON NOT NULL,
  created_by INT UNSIGNED NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_commission_approval_request (barbearia_id, idempotency_key),
  CONSTRAINT fk_commission_approval_request_business FOREIGN KEY (barbearia_id) REFERENCES barbearias (id) ON DELETE RESTRICT,
  CONSTRAINT fk_commission_approval_request_creator FOREIGN KEY (created_by) REFERENCES usuarios (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS commission_payment_previews (
  id CHAR(36) NOT NULL,
  barbearia_id INT UNSIGNED NOT NULL,
  payload_hash CHAR(64) NOT NULL,
  payload_json JSON NOT NULL,
  result_json JSON NOT NULL,
  expires_at DATETIME NOT NULL,
  created_by INT UNSIGNED NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_commission_payment_preview_expiry (barbearia_id, expires_at),
  CONSTRAINT fk_commission_payment_preview_business FOREIGN KEY (barbearia_id) REFERENCES barbearias (id) ON DELETE RESTRICT,
  CONSTRAINT fk_commission_payment_preview_creator FOREIGN KEY (created_by) REFERENCES usuarios (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS commission_payment_batches (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  barbearia_id INT UNSIGNED NOT NULL,
  idempotency_key VARCHAR(120) NOT NULL,
  payload_hash CHAR(64) NOT NULL,
  response_json JSON NOT NULL,
  created_by INT UNSIGNED NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_commission_payment_batch_key (barbearia_id, idempotency_key),
  CONSTRAINT fk_commission_payment_batch_business FOREIGN KEY (barbearia_id) REFERENCES barbearias (id) ON DELETE RESTRICT,
  CONSTRAINT fk_commission_payment_batch_creator FOREIGN KEY (created_by) REFERENCES usuarios (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
