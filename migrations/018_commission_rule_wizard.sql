ALTER TABLE commission_rules
  ADD COLUMN nome VARCHAR(100) NULL AFTER id,
  ADD COLUMN config_json JSON NULL AFTER base,
  ADD COLUMN lifecycle ENUM('draft','scheduled','active','ended') NOT NULL DEFAULT 'active' AFTER ativo;

CREATE TABLE IF NOT EXISTS commission_rule_drafts (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  barbearia_id INT UNSIGNED NOT NULL,
  criado_por INT UNSIGNED NOT NULL,
  status ENUM('editing','published','discarded') NOT NULL DEFAULT 'editing',
  revision INT UNSIGNED NOT NULL DEFAULT 1,
  payload JSON NOT NULL,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  atualizado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_commission_rule_draft_owner (barbearia_id, criado_por, status, atualizado_em),
  CONSTRAINT fk_commission_rule_draft_business FOREIGN KEY (barbearia_id) REFERENCES barbearias (id) ON DELETE RESTRICT,
  CONSTRAINT fk_commission_rule_draft_creator FOREIGN KEY (criado_por) REFERENCES usuarios (id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS commission_goal_assessments (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  barbearia_id INT UNSIGNED NOT NULL,
  profissional_id INT UNSIGNED NOT NULL,
  competencia CHAR(7) NOT NULL,
  rule_id BIGINT UNSIGNED NULL,
  base_cents BIGINT NOT NULL DEFAULT 0,
  target_cents BIGINT NOT NULL DEFAULT 0,
  complement_cents BIGINT NOT NULL DEFAULT 0,
  status ENUM('preview','confirmed','reversed') NOT NULL DEFAULT 'confirmed',
  snapshot_json JSON NOT NULL,
  criado_por INT UNSIGNED NULL,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_commission_goal_competence (barbearia_id, profissional_id, competencia, rule_id),
  CONSTRAINT fk_commission_goal_business FOREIGN KEY (barbearia_id) REFERENCES barbearias (id) ON DELETE RESTRICT,
  CONSTRAINT fk_commission_goal_professional FOREIGN KEY (profissional_id) REFERENCES colaboradores (id) ON DELETE RESTRICT,
  CONSTRAINT fk_commission_goal_rule FOREIGN KEY (rule_id) REFERENCES commission_rules (id) ON DELETE RESTRICT,
  CONSTRAINT fk_commission_goal_creator FOREIGN KEY (criado_por) REFERENCES usuarios (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
