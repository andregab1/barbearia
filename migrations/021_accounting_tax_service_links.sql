ALTER TABLE accounting_tax_entries
  ADD COLUMN modo_calculo ENUM('fixed', 'percentage') NOT NULL DEFAULT 'fixed' AFTER regime;

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
