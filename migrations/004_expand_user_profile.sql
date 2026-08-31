ALTER TABLE usuarios
  ADD COLUMN username VARCHAR(50) NULL AFTER email,
  ADD COLUMN data_nascimento DATE NULL AFTER telefone,
  ADD COLUMN bio VARCHAR(280) NULL AFTER foto_url;

CREATE UNIQUE INDEX uq_usuarios_username ON usuarios (username);

