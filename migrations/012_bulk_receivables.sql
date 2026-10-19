CREATE TABLE IF NOT EXISTS financial_receivable_exclusions (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  barbearia_id INT UNSIGNED NOT NULL,
  agendamento_id INT UNSIGNED NOT NULL,
  excluido_por INT UNSIGNED NOT NULL,
  motivo VARCHAR(240) NOT NULL,
  excluido_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_receivable_exclusion (barbearia_id, agendamento_id),
  KEY idx_receivable_exclusion_appointment (agendamento_id),
  CONSTRAINT fk_receivable_exclusion_barbearia FOREIGN KEY (barbearia_id) REFERENCES barbearias (id) ON DELETE RESTRICT,
  CONSTRAINT fk_receivable_exclusion_appointment FOREIGN KEY (agendamento_id) REFERENCES agendamentos (id) ON DELETE RESTRICT,
  CONSTRAINT fk_receivable_exclusion_user FOREIGN KEY (excluido_por) REFERENCES usuarios (id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
