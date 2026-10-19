ALTER TABLE payments
  ADD COLUMN financial_account_id INT UNSIGNED NULL AFTER agendamento_id,
  ADD COLUMN criado_por INT UNSIGNED NULL AFTER usuario_id,
  ADD COLUMN observacao VARCHAR(500) NULL AFTER moeda,
  ADD KEY idx_payment_tenant_appointment_status (barbearia_id, agendamento_id, status),
  ADD CONSTRAINT fk_payment_financial_account FOREIGN KEY (financial_account_id) REFERENCES financial_accounts (id) ON DELETE RESTRICT,
  ADD CONSTRAINT fk_payment_creator FOREIGN KEY (criado_por) REFERENCES usuarios (id) ON DELETE SET NULL;

CREATE TABLE IF NOT EXISTS expenses (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  barbearia_id INT UNSIGNED NOT NULL,
  category_id INT UNSIGNED NOT NULL,
  financial_account_id INT UNSIGNED NULL,
  responsible_user_id INT UNSIGNED NOT NULL,
  descricao VARCHAR(240) NOT NULL,
  valor DECIMAL(12,2) NOT NULL,
  data_competencia DATE NOT NULL,
  data_vencimento DATE NOT NULL,
  pago_em DATETIME NULL,
  status ENUM('pending','paid','cancelled') NOT NULL DEFAULT 'pending',
  observacao VARCHAR(500) NULL,
  criado_por INT UNSIGNED NOT NULL,
  cancelado_por INT UNSIGNED NULL,
  cancelado_em DATETIME NULL,
  motivo_cancelamento VARCHAR(240) NULL,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  atualizado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_expense_tenant_status_due (barbearia_id, status, data_vencimento),
  KEY idx_expense_tenant_category_competence (barbearia_id, category_id, data_competencia),
  CONSTRAINT fk_expense_barbearia FOREIGN KEY (barbearia_id) REFERENCES barbearias (id) ON DELETE RESTRICT,
  CONSTRAINT fk_expense_category FOREIGN KEY (category_id) REFERENCES financial_categories (id) ON DELETE RESTRICT,
  CONSTRAINT fk_expense_account FOREIGN KEY (financial_account_id) REFERENCES financial_accounts (id) ON DELETE RESTRICT,
  CONSTRAINT fk_expense_responsible FOREIGN KEY (responsible_user_id) REFERENCES usuarios (id) ON DELETE RESTRICT,
  CONSTRAINT fk_expense_creator FOREIGN KEY (criado_por) REFERENCES usuarios (id) ON DELETE RESTRICT,
  CONSTRAINT fk_expense_canceller FOREIGN KEY (cancelado_por) REFERENCES usuarios (id) ON DELETE SET NULL,
  CONSTRAINT chk_expense_amount CHECK (valor > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS financial_movements (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  barbearia_id INT UNSIGNED NOT NULL,
  movement_type ENUM('income','expense','refund','reversal','adjustment') NOT NULL,
  operation VARCHAR(40) NOT NULL,
  origin_type ENUM('payment','expense','refund','manual_adjustment') NOT NULL,
  origin_id BIGINT UNSIGNED NOT NULL,
  idempotency_key VARCHAR(100) NULL,
  appointment_id INT UNSIGNED NULL,
  client_id INT UNSIGNED NULL,
  professional_id INT UNSIGNED NULL,
  financial_account_id INT UNSIGNED NOT NULL,
  category_id INT UNSIGNED NULL,
  payment_id BIGINT UNSIGNED NULL,
  expense_id BIGINT UNSIGNED NULL,
  amount DECIMAL(12,2) NOT NULL,
  movement_date DATETIME NOT NULL,
  description VARCHAR(240) NOT NULL,
  status ENUM('confirmed','reversed','cancelled') NOT NULL DEFAULT 'confirmed',
  created_by INT UNSIGNED NOT NULL,
  cancelled_by INT UNSIGNED NULL,
  cancelled_at DATETIME NULL,
  cancellation_reason VARCHAR(240) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_movement_origin_operation (barbearia_id, origin_type, origin_id, operation),
  UNIQUE KEY uq_movement_idempotency (barbearia_id, idempotency_key),
  KEY idx_movement_tenant_date_status (barbearia_id, movement_date, status),
  KEY idx_movement_tenant_professional_date (barbearia_id, professional_id, movement_date),
  KEY idx_movement_appointment (appointment_id),
  KEY idx_movement_payment (payment_id),
  KEY idx_movement_expense (expense_id),
  CONSTRAINT fk_movement_barbearia FOREIGN KEY (barbearia_id) REFERENCES barbearias (id) ON DELETE RESTRICT,
  CONSTRAINT fk_movement_appointment FOREIGN KEY (appointment_id) REFERENCES agendamentos (id) ON DELETE RESTRICT,
  CONSTRAINT fk_movement_client FOREIGN KEY (client_id) REFERENCES usuarios (id) ON DELETE RESTRICT,
  CONSTRAINT fk_movement_professional FOREIGN KEY (professional_id) REFERENCES colaboradores (id) ON DELETE RESTRICT,
  CONSTRAINT fk_movement_account FOREIGN KEY (financial_account_id) REFERENCES financial_accounts (id) ON DELETE RESTRICT,
  CONSTRAINT fk_movement_category FOREIGN KEY (category_id) REFERENCES financial_categories (id) ON DELETE RESTRICT,
  CONSTRAINT fk_movement_payment FOREIGN KEY (payment_id) REFERENCES payments (id) ON DELETE RESTRICT,
  CONSTRAINT fk_movement_expense FOREIGN KEY (expense_id) REFERENCES expenses (id) ON DELETE RESTRICT,
  CONSTRAINT fk_movement_creator FOREIGN KEY (created_by) REFERENCES usuarios (id) ON DELETE RESTRICT,
  CONSTRAINT fk_movement_canceller FOREIGN KEY (cancelled_by) REFERENCES usuarios (id) ON DELETE SET NULL,
  CONSTRAINT chk_movement_amount CHECK (amount > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO financial_categories (barbearia_id, nome, tipo)
SELECT b.id, defaults.nome, 'expense'
FROM barbearias b
JOIN (
  SELECT 'Aluguel' nome UNION ALL SELECT 'Agua' UNION ALL SELECT 'Energia'
  UNION ALL SELECT 'Produtos' UNION ALL SELECT 'Marketing' UNION ALL SELECT 'Manutencao'
  UNION ALL SELECT 'Internet' UNION ALL SELECT 'Folha' UNION ALL SELECT 'Impostos'
  UNION ALL SELECT 'Outros'
) defaults;

INSERT IGNORE INTO financial_movements
  (barbearia_id, movement_type, operation, origin_type, origin_id, appointment_id,
   client_id, professional_id, financial_account_id, category_id, payment_id,
   amount, movement_date, description, status, created_by, created_at)
SELECT p.barbearia_id, 'income', 'payment_received', 'payment', p.id, p.agendamento_id,
       a.cliente_id, a.colaborador_id, fa.id, fc.id, p.id, p.valor, p.pago_em,
       CONCAT('Pagamento do atendimento #', p.agendamento_id), 'confirmed',
       COALESCE(p.criado_por, b.admin_id), p.criado_em
FROM payments p
JOIN barbearias b ON b.id = p.barbearia_id
JOIN agendamentos a ON a.id = p.agendamento_id
JOIN financial_accounts fa ON fa.barbearia_id = p.barbearia_id AND fa.nome = 'Caixa'
LEFT JOIN financial_categories fc ON fc.barbearia_id = p.barbearia_id
 AND fc.nome = 'Servicos' AND fc.tipo = 'income'
WHERE p.status IN ('paid','partially_refunded','refunded') AND p.tipo = 'service';

UPDATE payments p
JOIN financial_accounts fa ON fa.barbearia_id = p.barbearia_id AND fa.nome = 'Caixa'
SET p.financial_account_id = fa.id
WHERE p.financial_account_id IS NULL AND p.tipo = 'service';
