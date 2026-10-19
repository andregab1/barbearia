-- ============================================================================
-- GetCutt / Barbearia - esquema consolidado
-- MySQL 8+
--
-- Uso: somente para criar um banco vazio ou consultar o modelo completo.
-- Bancos existentes devem evoluir com `npm run migrate`.
-- Este arquivo consolida migrations/000 ate migrations/010 sem remover campos.
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

CREATE TABLE IF NOT EXISTS categorias_servico (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  barbearia_id INT UNSIGNED NOT NULL,
  nome VARCHAR(80) NOT NULL,
  ativo TINYINT(1) NOT NULL DEFAULT 1,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  atualizado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_categoria_servico_tenant_nome (barbearia_id, nome),
  KEY idx_categoria_servico_tenant_ativo (barbearia_id, ativo),
  CONSTRAINT fk_categoria_servico_barbearia
    FOREIGN KEY (barbearia_id) REFERENCES barbearias (id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS servicos (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  barbearia_id INT UNSIGNED NOT NULL,
  categoria_id INT UNSIGNED NULL,
  nome VARCHAR(100) NOT NULL,
  descricao TEXT NULL,
  preco DECIMAL(8,2) NOT NULL,
  duracao_min SMALLINT UNSIGNED NOT NULL,
  ativo TINYINT(1) NOT NULL DEFAULT 1,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  atualizado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_servicos_tenant_ativo (barbearia_id, ativo),
  KEY idx_servicos_categoria (categoria_id),
  CONSTRAINT fk_servico_barbearia
    FOREIGN KEY (barbearia_id) REFERENCES barbearias (id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_servico_categoria
    FOREIGN KEY (categoria_id) REFERENCES categorias_servico (id)
    ON DELETE SET NULL ON UPDATE CASCADE
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
  status ENUM('pendente','confirmado','cliente_chegou','em_atendimento','concluido','cancelado','nao_compareceu') NOT NULL DEFAULT 'confirmado',
  concluido_em DATETIME NULL,
  cliente_chegou_em DATETIME NULL,
  iniciado_em DATETIME NULL,
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

CREATE TABLE IF NOT EXISTS assistant_confirmations (
  proposal_id VARCHAR(36) NOT NULL PRIMARY KEY,
  cliente_id INT UNSIGNED NOT NULL,
  agendamento_id INT UNSIGNED NOT NULL,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (agendamento_id) REFERENCES agendamentos(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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

CREATE TABLE IF NOT EXISTS financial_accounts (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT, barbearia_id INT UNSIGNED NOT NULL,
  nome VARCHAR(80) NOT NULL, tipo ENUM('cash','bank','pix','card','other') NOT NULL,
  ativo TINYINT(1) NOT NULL DEFAULT 1, criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  atualizado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id), UNIQUE KEY uq_financial_account_tenant_name (barbearia_id, nome),
  KEY idx_financial_account_tenant_active (barbearia_id, ativo),
  CONSTRAINT fk_financial_account_barbearia FOREIGN KEY (barbearia_id) REFERENCES barbearias (id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS financial_categories (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT, barbearia_id INT UNSIGNED NOT NULL,
  nome VARCHAR(80) NOT NULL, tipo ENUM('income','expense') NOT NULL,
  ativo TINYINT(1) NOT NULL DEFAULT 1, criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  atualizado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id), UNIQUE KEY uq_financial_category_tenant_name_type (barbearia_id, nome, tipo),
  KEY idx_financial_category_tenant_active (barbearia_id, tipo, ativo),
  CONSTRAINT fk_financial_category_barbearia FOREIGN KEY (barbearia_id) REFERENCES barbearias (id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS financial_transactions (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, barbearia_id INT UNSIGNED NOT NULL,
  tipo ENUM('forecast','income','expense','refund','reversal') NOT NULL,
  status ENUM('pending','posted','partially_paid','paid','cancelled','reversed') NOT NULL DEFAULT 'pending',
  category_id INT UNSIGNED NULL, account_id INT UNSIGNED NULL, agendamento_id INT UNSIGNED NULL,
  colaborador_id INT UNSIGNED NULL, cliente_id INT UNSIGNED NULL, transacao_origem_id BIGINT UNSIGNED NULL,
  source_type VARCHAR(40) NOT NULL, source_id VARCHAR(100) NOT NULL, descricao VARCHAR(240) NOT NULL,
  valor_bruto DECIMAL(12,2) NOT NULL, valor_desconto DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  valor_taxa DECIMAL(12,2) NOT NULL DEFAULT 0.00, valor_liquido DECIMAL(12,2) NOT NULL,
  data_competencia DATE NOT NULL, data_vencimento DATE NULL, pago_em DATETIME NULL,
  criado_por INT UNSIGNED NULL, cancelado_por INT UNSIGNED NULL, motivo_cancelamento VARCHAR(240) NULL,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  atualizado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id), UNIQUE KEY uq_financial_source_event (barbearia_id, source_type, source_id, tipo),
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
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, barbearia_id INT UNSIGNED NOT NULL,
  payment_id BIGINT UNSIGNED NOT NULL, financial_transaction_id BIGINT UNSIGNED NOT NULL,
  valor DECIMAL(12,2) NOT NULL, criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id), UNIQUE KEY uq_payment_allocation (payment_id, financial_transaction_id),
  KEY idx_allocation_transaction (financial_transaction_id),
  CONSTRAINT fk_allocation_barbearia FOREIGN KEY (barbearia_id) REFERENCES barbearias (id) ON DELETE RESTRICT,
  CONSTRAINT fk_allocation_payment FOREIGN KEY (payment_id) REFERENCES payments (id) ON DELETE RESTRICT,
  CONSTRAINT fk_allocation_transaction FOREIGN KEY (financial_transaction_id) REFERENCES financial_transactions (id) ON DELETE RESTRICT,
  CONSTRAINT chk_allocation_positive CHECK (valor > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS outbox_events (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, barbearia_id INT UNSIGNED NOT NULL,
  tipo VARCHAR(80) NOT NULL, aggregate_type VARCHAR(60) NOT NULL, aggregate_id VARCHAR(100) NOT NULL,
  payload JSON NOT NULL, status ENUM('pending','processing','processed','failed') NOT NULL DEFAULT 'pending',
  tentativas TINYINT UNSIGNED NOT NULL DEFAULT 0, processar_apos DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  processado_em DATETIME NULL, ultimo_erro VARCHAR(500) NULL, criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id), UNIQUE KEY uq_outbox_event (barbearia_id, tipo, aggregate_type, aggregate_id),
  KEY idx_outbox_pending (status, processar_apos),
  CONSTRAINT fk_outbox_barbearia FOREIGN KEY (barbearia_id) REFERENCES barbearias (id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS fiscal_settings (
  barbearia_id INT UNSIGNED NOT NULL, razao_social VARCHAR(180) NULL, nome_fantasia VARCHAR(180) NULL,
  cnpj CHAR(14) NULL, inscricao_municipal VARCHAR(40) NULL, municipio VARCHAR(100) NULL, uf CHAR(2) NULL,
  regime_tributario VARCHAR(60) NULL, codigo_servico VARCHAR(40) NULL, aliquota DECIMAL(7,4) NULL,
  ambiente ENUM('sandbox','production') NOT NULL DEFAULT 'sandbox', provedor VARCHAR(60) NULL,
  emissao_automatica TINYINT(1) NOT NULL DEFAULT 0, ativo TINYINT(1) NOT NULL DEFAULT 0,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  atualizado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (barbearia_id),
  CONSTRAINT fk_fiscal_settings_barbearia FOREIGN KEY (barbearia_id) REFERENCES barbearias (id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS fiscal_documents (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, barbearia_id INT UNSIGNED NOT NULL,
  agendamento_id INT UNSIGNED NOT NULL, cliente_id INT UNSIGNED NOT NULL,
  financial_transaction_id BIGINT UNSIGNED NOT NULL, payment_id BIGINT UNSIGNED NULL,
  document_type ENUM('nfse','other') NOT NULL DEFAULT 'nfse', provider VARCHAR(60) NOT NULL,
  provider_document_id VARCHAR(160) NULL, idempotency_key VARCHAR(100) NOT NULL,
  status ENUM('pending','processing','authorized','rejected','cancelled','error') NOT NULL DEFAULT 'pending',
  total_amount DECIMAL(12,2) NOT NULL, service_amount DECIMAL(12,2) NOT NULL, tax_amount DECIMAL(12,2) NULL,
  snapshot JSON NOT NULL, pdf_url VARCHAR(500) NULL, xml_url VARCHAR(500) NULL,
  issued_at DATETIME NULL, cancelled_at DATETIME NULL, error_message VARCHAR(500) NULL,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  atualizado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id), UNIQUE KEY uq_fiscal_idempotency (idempotency_key),
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
  id INT UNSIGNED NOT NULL AUTO_INCREMENT, barbearia_id INT UNSIGNED NOT NULL, parent_id INT UNSIGNED NULL,
  codigo VARCHAR(30) NOT NULL, nome VARCHAR(120) NOT NULL,
  natureza ENUM('asset','liability','equity','revenue','expense') NOT NULL,
  ativo TINYINT(1) NOT NULL DEFAULT 1, criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  atualizado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id), UNIQUE KEY uq_accounting_account_code (barbearia_id, codigo),
  CONSTRAINT fk_accounting_account_barbearia FOREIGN KEY (barbearia_id) REFERENCES barbearias (id) ON DELETE RESTRICT,
  CONSTRAINT fk_accounting_account_parent FOREIGN KEY (parent_id) REFERENCES accounting_accounts (id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS accounting_entries (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, barbearia_id INT UNSIGNED NOT NULL,
  financial_transaction_id BIGINT UNSIGNED NULL, source_type VARCHAR(40) NOT NULL, source_id VARCHAR(100) NOT NULL,
  descricao VARCHAR(240) NOT NULL, data_competencia DATE NOT NULL,
  status ENUM('draft','posted','reversed') NOT NULL DEFAULT 'posted', criado_por INT UNSIGNED NULL,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id), UNIQUE KEY uq_accounting_source (barbearia_id, source_type, source_id),
  KEY idx_accounting_tenant_competence (barbearia_id, data_competencia, status),
  CONSTRAINT fk_accounting_entry_barbearia FOREIGN KEY (barbearia_id) REFERENCES barbearias (id) ON DELETE RESTRICT,
  CONSTRAINT fk_accounting_entry_transaction FOREIGN KEY (financial_transaction_id) REFERENCES financial_transactions (id) ON DELETE RESTRICT,
  CONSTRAINT fk_accounting_entry_creator FOREIGN KEY (criado_por) REFERENCES usuarios (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS accounting_entry_lines (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, entry_id BIGINT UNSIGNED NOT NULL,
  account_id INT UNSIGNED NOT NULL, tipo ENUM('debit','credit') NOT NULL,
  valor DECIMAL(12,2) NOT NULL, descricao VARCHAR(240) NULL,
  PRIMARY KEY (id), KEY idx_accounting_line_entry (entry_id),
  CONSTRAINT fk_accounting_line_entry FOREIGN KEY (entry_id) REFERENCES accounting_entries (id) ON DELETE RESTRICT,
  CONSTRAINT fk_accounting_line_account FOREIGN KEY (account_id) REFERENCES accounting_accounts (id) ON DELETE RESTRICT,
  CONSTRAINT chk_accounting_line_positive CHECK (valor > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS accounting_tax_entries (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, barbearia_id INT UNSIGNED NOT NULL,
  tipo VARCHAR(40) NOT NULL, regime VARCHAR(30) NOT NULL DEFAULT 'nao_informado',
  modo_calculo ENUM('fixed','percentage') NOT NULL DEFAULT 'fixed',
  valor DECIMAL(12,2) NOT NULL, data_competencia DATE NOT NULL,
  observacao VARCHAR(240) NULL, criado_por INT UNSIGNED NULL,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id), KEY idx_accounting_tax_tenant_competence (barbearia_id, data_competencia),
  CONSTRAINT fk_accounting_tax_barbearia FOREIGN KEY (barbearia_id) REFERENCES barbearias (id) ON DELETE RESTRICT,
  CONSTRAINT fk_accounting_tax_creator FOREIGN KEY (criado_por) REFERENCES usuarios (id) ON DELETE SET NULL,
  CONSTRAINT chk_accounting_tax_amount_positive CHECK (valor > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS accounting_tax_entry_services (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  accounting_tax_entry_id BIGINT UNSIGNED NOT NULL,
  barbearia_id INT UNSIGNED NOT NULL,
  servico_id INT UNSIGNED NOT NULL,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_accounting_tax_entry_service (accounting_tax_entry_id, servico_id),
  KEY idx_accounting_tax_service_tenant (barbearia_id, servico_id),
  CONSTRAINT fk_accounting_tax_service_entry
    FOREIGN KEY (accounting_tax_entry_id) REFERENCES accounting_tax_entries (id) ON DELETE CASCADE,
  CONSTRAINT fk_accounting_tax_service_barbearia
    FOREIGN KEY (barbearia_id) REFERENCES barbearias (id) ON DELETE RESTRICT,
  CONSTRAINT fk_accounting_tax_service_servico
    FOREIGN KEY (servico_id) REFERENCES servicos (id) ON DELETE RESTRICT
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

ALTER TABLE payments
  ADD COLUMN financial_account_id INT UNSIGNED NULL AFTER agendamento_id,
  ADD COLUMN criado_por INT UNSIGNED NULL AFTER usuario_id,
  ADD COLUMN observacao VARCHAR(500) NULL AFTER moeda,
  ADD KEY idx_payment_tenant_appointment_status (barbearia_id, agendamento_id, status),
  ADD CONSTRAINT fk_payment_financial_account FOREIGN KEY (financial_account_id) REFERENCES financial_accounts (id) ON DELETE RESTRICT,
  ADD CONSTRAINT fk_payment_creator FOREIGN KEY (criado_por) REFERENCES usuarios (id) ON DELETE SET NULL;

CREATE TABLE IF NOT EXISTS expenses (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, legacy_cash_entry_id BIGINT UNSIGNED NULL, barbearia_id INT UNSIGNED NOT NULL,
  category_id INT UNSIGNED NOT NULL, financial_account_id INT UNSIGNED NULL,
  responsible_user_id INT UNSIGNED NOT NULL, descricao VARCHAR(240) NOT NULL,
  valor DECIMAL(12,2) NOT NULL, data_competencia DATE NOT NULL, data_vencimento DATE NOT NULL,
  pago_em DATETIME NULL, status ENUM('pending','paid','cancelled') NOT NULL DEFAULT 'pending',
  observacao VARCHAR(500) NULL, criado_por INT UNSIGNED NOT NULL, cancelado_por INT UNSIGNED NULL,
  cancelado_em DATETIME NULL, motivo_cancelamento VARCHAR(240) NULL,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  atualizado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id), UNIQUE KEY uq_expense_legacy_cash_entry (legacy_cash_entry_id), KEY idx_expense_tenant_status_due (barbearia_id,status,data_vencimento),
  KEY idx_expense_tenant_category_competence (barbearia_id,category_id,data_competencia),
  CONSTRAINT fk_expense_barbearia FOREIGN KEY (barbearia_id) REFERENCES barbearias(id) ON DELETE RESTRICT,
  CONSTRAINT fk_expense_category FOREIGN KEY (category_id) REFERENCES financial_categories(id) ON DELETE RESTRICT,
  CONSTRAINT fk_expense_account FOREIGN KEY (financial_account_id) REFERENCES financial_accounts(id) ON DELETE RESTRICT,
  CONSTRAINT fk_expense_responsible FOREIGN KEY (responsible_user_id) REFERENCES usuarios(id) ON DELETE RESTRICT,
  CONSTRAINT fk_expense_creator FOREIGN KEY (criado_por) REFERENCES usuarios(id) ON DELETE RESTRICT,
  CONSTRAINT fk_expense_canceller FOREIGN KEY (cancelado_por) REFERENCES usuarios(id) ON DELETE SET NULL,
  CONSTRAINT fk_expense_legacy_cash_entry FOREIGN KEY (legacy_cash_entry_id) REFERENCES cash_entries(id) ON DELETE RESTRICT,
  CONSTRAINT chk_expense_amount CHECK (valor > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS financial_movements (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, barbearia_id INT UNSIGNED NOT NULL,
  movement_type ENUM('income','expense','refund','reversal','adjustment') NOT NULL,
  operation VARCHAR(40) NOT NULL, origin_type ENUM('payment','expense','refund','manual_adjustment') NOT NULL,
  origin_id BIGINT UNSIGNED NOT NULL, idempotency_key VARCHAR(100) NULL,
  appointment_id INT UNSIGNED NULL, client_id INT UNSIGNED NULL, professional_id INT UNSIGNED NULL,
  financial_account_id INT UNSIGNED NOT NULL, category_id INT UNSIGNED NULL,
  payment_id BIGINT UNSIGNED NULL, expense_id BIGINT UNSIGNED NULL, amount DECIMAL(12,2) NOT NULL,
  movement_date DATETIME NOT NULL, description VARCHAR(240) NOT NULL,
  status ENUM('confirmed','reversed','cancelled') NOT NULL DEFAULT 'confirmed',
  created_by INT UNSIGNED NOT NULL, cancelled_by INT UNSIGNED NULL, cancelled_at DATETIME NULL,
  cancellation_reason VARCHAR(240) NULL, created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id), UNIQUE KEY uq_movement_origin_operation (barbearia_id,origin_type,origin_id,operation),
  UNIQUE KEY uq_movement_idempotency (barbearia_id,idempotency_key),
  KEY idx_movement_tenant_date_status (barbearia_id,movement_date,status),
  KEY idx_movement_tenant_professional_date (barbearia_id,professional_id,movement_date),
  KEY idx_movement_appointment (appointment_id), KEY idx_movement_payment (payment_id), KEY idx_movement_expense (expense_id),
  CONSTRAINT fk_movement_barbearia FOREIGN KEY (barbearia_id) REFERENCES barbearias(id) ON DELETE RESTRICT,
  CONSTRAINT fk_movement_appointment FOREIGN KEY (appointment_id) REFERENCES agendamentos(id) ON DELETE RESTRICT,
  CONSTRAINT fk_movement_client FOREIGN KEY (client_id) REFERENCES usuarios(id) ON DELETE RESTRICT,
  CONSTRAINT fk_movement_professional FOREIGN KEY (professional_id) REFERENCES colaboradores(id) ON DELETE RESTRICT,
  CONSTRAINT fk_movement_account FOREIGN KEY (financial_account_id) REFERENCES financial_accounts(id) ON DELETE RESTRICT,
  CONSTRAINT fk_movement_category FOREIGN KEY (category_id) REFERENCES financial_categories(id) ON DELETE RESTRICT,
  CONSTRAINT fk_movement_payment FOREIGN KEY (payment_id) REFERENCES payments(id) ON DELETE RESTRICT,
  CONSTRAINT fk_movement_expense FOREIGN KEY (expense_id) REFERENCES expenses(id) ON DELETE RESTRICT,
  CONSTRAINT fk_movement_creator FOREIGN KEY (created_by) REFERENCES usuarios(id) ON DELETE RESTRICT,
  CONSTRAINT fk_movement_canceller FOREIGN KEY (cancelled_by) REFERENCES usuarios(id) ON DELETE SET NULL,
  CONSTRAINT chk_movement_amount CHECK (amount > 0)
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
  ('007_link_cash_entries_to_appointments.sql'),
  ('008_financial_fiscal_accounting_core.sql'),
  ('009_financial_operational_core.sql'),
  ('010_financial_legacy_backfill.sql'),
  ('019_service_categories.sql');

-- Planos de sistema fazem parte do catalogo funcional, nao de dados de teste.
INSERT IGNORE INTO plans
  (codigo, nome, preco_mensal, limite_profissionais, recursos)
VALUES
  ('trial', 'Período de teste', 0.00, 3, JSON_OBJECT('dias', 14)),
  ('professional', 'Profissional', 99.90, 10,
   JSON_OBJECT('financeiro', true, 'notificacoes', true));

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
