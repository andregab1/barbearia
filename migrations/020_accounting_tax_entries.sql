CREATE TABLE IF NOT EXISTS accounting_tax_entries (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  barbearia_id INT UNSIGNED NOT NULL,
  tipo VARCHAR(40) NOT NULL,
  regime VARCHAR(30) NOT NULL DEFAULT 'nao_informado',
  valor DECIMAL(12,2) NOT NULL,
  data_competencia DATE NOT NULL,
  observacao VARCHAR(240) NULL,
  criado_por INT UNSIGNED NULL,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_accounting_tax_tenant_competence (barbearia_id, data_competencia),
  CONSTRAINT fk_accounting_tax_barbearia FOREIGN KEY (barbearia_id) REFERENCES barbearias (id) ON DELETE RESTRICT,
  CONSTRAINT fk_accounting_tax_creator FOREIGN KEY (criado_por) REFERENCES usuarios (id) ON DELETE SET NULL,
  CONSTRAINT chk_accounting_tax_amount_positive CHECK (valor > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
