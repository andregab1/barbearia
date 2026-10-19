ALTER TABLE agendamentos
  MODIFY COLUMN status ENUM('pendente','confirmado','cliente_chegou','em_atendimento','concluido','cancelado','nao_compareceu') NOT NULL DEFAULT 'confirmado';

ALTER TABLE agendamentos
  ADD COLUMN cliente_chegou_em DATETIME NULL AFTER concluido_em,
  ADD COLUMN iniciado_em DATETIME NULL AFTER cliente_chegou_em;
