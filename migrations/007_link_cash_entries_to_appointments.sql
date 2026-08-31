ALTER TABLE cash_entries
  ADD COLUMN appointment_id INT UNSIGNED NULL AFTER payment_id,
  ADD UNIQUE KEY uq_cash_appointment (appointment_id),
  ADD CONSTRAINT fk_cash_appointment
    FOREIGN KEY (appointment_id) REFERENCES agendamentos (id) ON DELETE SET NULL;
