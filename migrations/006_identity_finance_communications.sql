CREATE TABLE IF NOT EXISTS otp_challenges (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  destino_hash CHAR(64) NOT NULL,
  canal ENUM('email','whatsapp','sms') NOT NULL,
  proposito ENUM('quick_access','verify_contact','password_reset') NOT NULL,
  codigo_hash VARCHAR(255) NOT NULL,
  tentativas TINYINT UNSIGNED NOT NULL DEFAULT 0,
  expira_em DATETIME NOT NULL,
  consumido_em DATETIME NULL,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_otp_lookup (destino_hash, proposito, consumido_em, expira_em)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS notification_preferences (
  usuario_id INT UNSIGNED NOT NULL,
  push_ativo TINYINT(1) NOT NULL DEFAULT 1,
  whatsapp_ativo TINYINT(1) NOT NULL DEFAULT 1,
  email_ativo TINYINT(1) NOT NULL DEFAULT 1,
  marketing_ativo TINYINT(1) NOT NULL DEFAULT 0,
  atualizado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (usuario_id),
  CONSTRAINT fk_notification_preference_user FOREIGN KEY (usuario_id) REFERENCES usuarios (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS notification_deliveries (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  notificacao_id INT UNSIGNED NOT NULL,
  canal ENUM('push','whatsapp','email') NOT NULL,
  provedor VARCHAR(40) NOT NULL,
  idempotency_key VARCHAR(120) NOT NULL,
  status ENUM('queued','sending','delivered','failed','canceled') NOT NULL DEFAULT 'queued',
  tentativas TINYINT UNSIGNED NOT NULL DEFAULT 0,
  proxima_tentativa_em DATETIME NULL,
  provedor_mensagem_id VARCHAR(160) NULL,
  ultimo_erro VARCHAR(500) NULL,
  entregue_em DATETIME NULL,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  atualizado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_notification_delivery_key (idempotency_key),
  KEY idx_notification_delivery_queue (status, proxima_tentativa_em),
  CONSTRAINT fk_notification_delivery_notification FOREIGN KEY (notificacao_id) REFERENCES notificacoes (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS device_tokens (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  usuario_id INT UNSIGNED NOT NULL,
  plataforma ENUM('web','android','ios') NOT NULL,
  token VARCHAR(500) NOT NULL,
  ativo TINYINT(1) NOT NULL DEFAULT 1,
  ultimo_uso_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_device_token (token),
  KEY idx_device_user_active (usuario_id, ativo),
  CONSTRAINT fk_device_token_user FOREIGN KEY (usuario_id) REFERENCES usuarios (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS refunds (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  payment_id BIGINT UNSIGNED NOT NULL,
  provedor_reembolso_id VARCHAR(120) NULL,
  idempotency_key VARCHAR(100) NOT NULL,
  status ENUM('pending','processed','failed') NOT NULL DEFAULT 'pending',
  valor DECIMAL(10,2) NOT NULL,
  motivo VARCHAR(240) NULL,
  processado_em DATETIME NULL,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_refund_idempotency (idempotency_key),
  CONSTRAINT fk_refund_payment FOREIGN KEY (payment_id) REFERENCES payments (id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS commissions (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  barbearia_id INT UNSIGNED NOT NULL,
  colaborador_id INT UNSIGNED NOT NULL,
  agendamento_id INT UNSIGNED NOT NULL,
  payment_id BIGINT UNSIGNED NULL,
  percentual DECIMAL(5,2) NOT NULL,
  base_calculo DECIMAL(10,2) NOT NULL,
  valor DECIMAL(10,2) NOT NULL,
  status ENUM('pending','available','paid','canceled') NOT NULL DEFAULT 'pending',
  disponivel_em DATETIME NULL,
  pago_em DATETIME NULL,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_commission_appointment_professional (agendamento_id, colaborador_id),
  KEY idx_commission_tenant_status (barbearia_id, status, criado_em),
  CONSTRAINT fk_commission_barbearia FOREIGN KEY (barbearia_id) REFERENCES barbearias (id) ON DELETE RESTRICT,
  CONSTRAINT fk_commission_colaborador FOREIGN KEY (colaborador_id) REFERENCES colaboradores (id) ON DELETE RESTRICT,
  CONSTRAINT fk_commission_agendamento FOREIGN KEY (agendamento_id) REFERENCES agendamentos (id) ON DELETE RESTRICT,
  CONSTRAINT fk_commission_payment FOREIGN KEY (payment_id) REFERENCES payments (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
