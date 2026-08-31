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

INSERT IGNORE INTO agendamento_servicos
  (agendamento_id, servico_id, preco_cobrado, duracao_min)
SELECT id, servico_id, valor_cobrado, duracao_min
FROM agendamentos;

