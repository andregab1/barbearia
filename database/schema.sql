-- ============================================================================
-- GetCutt / Barbearia - esquema consolidado
-- MySQL 8+
--
-- Uso: somente para criar um banco vazio ou consultar o modelo completo.
-- Bancos existentes devem evoluir com `npm run migrate`.
-- Este arquivo consolida migrations/000 ate migrations/007 sem remover campos.
-- ============================================================================

CREATE DATABASE IF NOT EXISTS barbearia_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE barbearia_db;

-- ----------------------------------------------------------------------------
-- 1. Identidade e tenants
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS usuarios (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  nome VARCHAR(100) NOT NULL,
  email VARCHAR(150) NULL,
  username VARCHAR(50) NULL,
  telefone VARCHAR(20) NOT NULL,
  data_nascimento DATE NULL,
  foto_url MEDIUMTEXT NULL,
  bio VARCHAR(280) NULL,
  senha_hash VARCHAR(255) NOT NULL,
  role ENUM('cliente','barbeiro','admin') NOT NULL DEFAULT 'cliente',
  ativo TINYINT(1) NOT NULL DEFAULT 1,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  atualizado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_usuarios_email (email),
  UNIQUE KEY uq_usuarios_username (username),
  UNIQUE KEY uq_usuarios_telefone (telefone),
  KEY idx_usuarios_role (role)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS barbearias (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  admin_id INT UNSIGNED NOT NULL,
  nome VARCHAR(150) NOT NULL,
  slug VARCHAR(80) NULL,
  descricao TEXT NULL,
  logo_url VARCHAR(500) NULL,
  cor_primaria VARCHAR(7) DEFAULT '#1A1A1A',
  cor_secundaria VARCHAR(7) DEFAULT '#C9A84C',
  telefone VARCHAR(20) NULL,
  email VARCHAR(150) NULL,
  endereco VARCHAR(300) NULL,
  timezone VARCHAR(64) NOT NULL DEFAULT 'America/Sao_Paulo',
  ativa TINYINT(1) NOT NULL DEFAULT 1,
  onboarding_concluido TINYINT(1) NOT NULL DEFAULT 0,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  atualizado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_barbearias_slug (slug),
  KEY idx_barbearias_admin (admin_id),
  CONSTRAINT fk_barbearia_admin
    FOREIGN KEY (admin_id) REFERENCES usuarios (id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

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
  CONSTRAINT fk_membership_barbearia
    FOREIGN KEY (barbearia_id) REFERENCES barbearias (id) ON DELETE CASCADE,
  CONSTRAINT fk_membership_usuario
    FOREIGN KEY (usuario_id) REFERENCES usuarios (id) ON DELETE CASCADE
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
  CONSTRAINT fk_invitation_barbearia
    FOREIGN KEY (barbearia_id) REFERENCES barbearias (id) ON DELETE CASCADE,
  CONSTRAINT fk_invitation_inviter
    FOREIGN KEY (convidado_por) REFERENCES usuarios (id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS colaboradores (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  barbearia_id INT UNSIGNED NOT NULL,
  usuario_id INT UNSIGNED NOT NULL,
  ativo TINYINT(1) NOT NULL DEFAULT 1,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_barbearia_usuario (barbearia_id, usuario_id),
  KEY idx_colaboradores_usuario (usuario_id),
  CONSTRAINT fk_colab_barbearia
    FOREIGN KEY (barbearia_id) REFERENCES barbearias (id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_colab_usuario
    FOREIGN KEY (usuario_id) REFERENCES usuarios (id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------------------
-- 2. Catalogo, disponibilidade e agenda
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS servicos (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  barbearia_id INT UNSIGNED NOT NULL,
  nome VARCHAR(100) NOT NULL,
  descricao TEXT NULL,
  preco DECIMAL(8,2) NOT NULL,
  duracao_min SMALLINT UNSIGNED NOT NULL,
  ativo TINYINT(1) NOT NULL DEFAULT 1,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  atualizado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_servicos_tenant_ativo (barbearia_id, ativo),
  CONSTRAINT fk_servico_barbearia
    FOREIGN KEY (barbearia_id) REFERENCES barbearias (id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS horarios_funcionamento (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  colaborador_id INT UNSIGNED NOT NULL,
  dia_semana TINYINT NOT NULL COMMENT '0=Dom, 1=Seg, ..., 6=Sab',
  hora_inicio TIME NOT NULL,
  hora_fim TIME NOT NULL,
  ativo TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (id),
  KEY idx_horarios_colaborador_dia (colaborador_id, dia_semana),
  CONSTRAINT fk_horario_colaborador
    FOREIGN KEY (colaborador_id) REFERENCES colaboradores (id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS agendamentos (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  cliente_id INT UNSIGNED NOT NULL,
  colaborador_id INT UNSIGNED NOT NULL,
  servico_id INT UNSIGNED NOT NULL COMMENT 'Servico principal, mantido por compatibilidade',
  data_hora DATETIME NOT NULL,
  duracao_min SMALLINT NOT NULL,
  status ENUM('pendente','confirmado','concluido','cancelado') NOT NULL DEFAULT 'confirmado',
  valor_cobrado DECIMAL(8,2) NOT NULL,
  observacao TEXT NULL,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  atualizado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_agendamentos_colaborador_data (colaborador_id, data_hora),
  KEY idx_agendamentos_cliente_data (cliente_id, data_hora),
  KEY idx_agendamentos_status (status),
  CONSTRAINT fk_agend_cliente
    FOREIGN KEY (cliente_id) REFERENCES usuarios (id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_agend_colaborador
    FOREIGN KEY (colaborador_id) REFERENCES colaboradores (id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_agend_servico
    FOREIGN KEY (servico_id) REFERENCES servicos (id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS agendamento_servicos (
  agendamento_id INT UNSIGNED NOT NULL,
  servico_id INT UNSIGNED NOT NULL,
  preco_cobrado DECIMAL(8,2) NOT NULL,
  duracao_min SMALLINT UNSIGNED NOT NULL,
  PRIMARY KEY (agendamento_id, servico_id),
  CONSTRAINT fk_agendamento_servicos_agendamento
    FOREIGN KEY (agendamento_id) REFERENCES agendamentos (id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_agendamento_servicos_servico
    FOREIGN KEY (servico_id) REFERENCES servicos (id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS horarios_bloqueados (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  colaborador_id INT UNSIGNED NOT NULL,
  data_hora_ini DATETIME NOT NULL,
  data_hora_fim DATETIME NOT NULL,
  motivo VARCHAR(200) NULL,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_bloqueios_colaborador_periodo (colaborador_id, data_hora_ini, data_hora_fim),
  CONSTRAINT fk_bloqueio_colaborador
    FOREIGN KEY (colaborador_id) REFERENCES colaboradores (id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------------------
-- 3. Autenticacao e comunicacao
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS refresh_tokens (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  usuario_id INT UNSIGNED NOT NULL,
  token VARCHAR(500) NOT NULL COMMENT 'Armazena SHA-256 do refresh token',
  expira_em DATETIME NOT NULL,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_refresh_token (token),
  KEY idx_refresh_usuario (usuario_id),
  CONSTRAINT fk_token_usuario
    FOREIGN KEY (usuario_id) REFERENCES usuarios (id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

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

CREATE TABLE IF NOT EXISTS notificacoes (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  usuario_id INT UNSIGNED NOT NULL,
  agendamento_id INT UNSIGNED NULL,
  tipo ENUM('lembrete','cancelamento','confirmacao','bloqueio') NOT NULL,
  titulo VARCHAR(150) NOT NULL,
  mensagem TEXT NOT NULL,
  enviada TINYINT(1) NOT NULL DEFAULT 0,
  enviada_em DATETIME NULL,
  agendada_para DATETIME NOT NULL,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_notificacoes_pendentes (enviada, agendada_para),
  KEY idx_notificacoes_usuario (usuario_id),
  CONSTRAINT fk_notif_usuario
    FOREIGN KEY (usuario_id) REFERENCES usuarios (id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_notif_agendamento
    FOREIGN KEY (agendamento_id) REFERENCES agendamentos (id)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS notification_preferences (
  usuario_id INT UNSIGNED NOT NULL,
  push_ativo TINYINT(1) NOT NULL DEFAULT 1,
  whatsapp_ativo TINYINT(1) NOT NULL DEFAULT 1,
  email_ativo TINYINT(1) NOT NULL DEFAULT 1,
  marketing_ativo TINYINT(1) NOT NULL DEFAULT 0,
  atualizado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (usuario_id),
  CONSTRAINT fk_notification_preference_user
    FOREIGN KEY (usuario_id) REFERENCES usuarios (id) ON DELETE CASCADE
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
  CONSTRAINT fk_notification_delivery_notification
    FOREIGN KEY (notificacao_id) REFERENCES notificacoes (id) ON DELETE CASCADE
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
  CONSTRAINT fk_device_token_user
    FOREIGN KEY (usuario_id) REFERENCES usuarios (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------------------
-- 4. Planos, pagamentos e financeiro
-- ----------------------------------------------------------------------------

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
  UNIQUE KEY uq_subscription_provider (provedor, provedor_assinatura_id),
  KEY idx_subscription_tenant_status (barbearia_id, status),
  CONSTRAINT fk_subscription_barbearia
    FOREIGN KEY (barbearia_id) REFERENCES barbearias (id) ON DELETE CASCADE,
  CONSTRAINT fk_subscription_plan
    FOREIGN KEY (plan_id) REFERENCES plans (id) ON DELETE RESTRICT
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
  CONSTRAINT fk_payment_account_barbearia
    FOREIGN KEY (barbearia_id) REFERENCES barbearias (id) ON DELETE CASCADE
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
  CONSTRAINT fk_payment_barbearia
    FOREIGN KEY (barbearia_id) REFERENCES barbearias (id) ON DELETE RESTRICT,
  CONSTRAINT fk_payment_agendamento
    FOREIGN KEY (agendamento_id) REFERENCES agendamentos (id) ON DELETE SET NULL,
  CONSTRAINT fk_payment_usuario
    FOREIGN KEY (usuario_id) REFERENCES usuarios (id) ON DELETE SET NULL
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
  CONSTRAINT fk_refund_payment
    FOREIGN KEY (payment_id) REFERENCES payments (id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS cash_entries (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  barbearia_id INT UNSIGNED NOT NULL,
  payment_id BIGINT UNSIGNED NULL,
  appointment_id INT UNSIGNED NULL,
  criado_por INT UNSIGNED NULL,
  tipo ENUM('income','expense','refund','commission') NOT NULL,
  categoria VARCHAR(60) NOT NULL,
  descricao VARCHAR(240) NULL,
  valor DECIMAL(10,2) NOT NULL,
  ocorrido_em DATETIME NOT NULL,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_cash_appointment (appointment_id),
  KEY idx_cash_tenant_date (barbearia_id, ocorrido_em),
  CONSTRAINT fk_cash_barbearia
    FOREIGN KEY (barbearia_id) REFERENCES barbearias (id) ON DELETE RESTRICT,
  CONSTRAINT fk_cash_payment
    FOREIGN KEY (payment_id) REFERENCES payments (id) ON DELETE SET NULL,
  CONSTRAINT fk_cash_appointment
    FOREIGN KEY (appointment_id) REFERENCES agendamentos (id) ON DELETE SET NULL,
  CONSTRAINT fk_cash_creator
    FOREIGN KEY (criado_por) REFERENCES usuarios (id) ON DELETE SET NULL
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
  CONSTRAINT fk_commission_barbearia
    FOREIGN KEY (barbearia_id) REFERENCES barbearias (id) ON DELETE RESTRICT,
  CONSTRAINT fk_commission_colaborador
    FOREIGN KEY (colaborador_id) REFERENCES colaboradores (id) ON DELETE RESTRICT,
  CONSTRAINT fk_commission_agendamento
    FOREIGN KEY (agendamento_id) REFERENCES agendamentos (id) ON DELETE RESTRICT,
  CONSTRAINT fk_commission_payment
    FOREIGN KEY (payment_id) REFERENCES payments (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------------------
-- 5. Integracoes, auditoria e controle do schema
-- ----------------------------------------------------------------------------

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
  CONSTRAINT fk_audit_barbearia
    FOREIGN KEY (barbearia_id) REFERENCES barbearias (id) ON DELETE SET NULL,
  CONSTRAINT fk_audit_usuario
    FOREIGN KEY (usuario_id) REFERENCES usuarios (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS schema_migrations (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  name VARCHAR(255) NOT NULL,
  applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_schema_migrations_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- O snapshot ja contem o efeito destas migracoes. Registrar evita reaplica-las.
INSERT IGNORE INTO schema_migrations (name) VALUES
  ('000_initial_schema.sql'),
  ('001_add_profile_photo.sql'),
  ('002_hash_refresh_tokens.sql'),
  ('003_add_appointment_services.sql'),
  ('004_expand_user_profile.sql'),
  ('005_saas_foundation.sql'),
  ('006_identity_finance_communications.sql'),
  ('007_link_cash_entries_to_appointments.sql');

-- Planos de sistema fazem parte do catalogo funcional, nao de dados de teste.
INSERT IGNORE INTO plans
  (codigo, nome, preco_mensal, limite_profissionais, recursos)
VALUES
  ('trial', 'Período de teste', 0.00, 3, JSON_OBJECT('dias', 14)),
  ('professional', 'Profissional', 99.90, 10,
   JSON_OBJECT('financeiro', true, 'notificacoes', true));
