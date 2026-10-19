ALTER TABLE usuarios
  ADD COLUMN cpf VARCHAR(14) NULL AFTER telefone,
  ADD UNIQUE KEY uq_usuarios_cpf (cpf);
