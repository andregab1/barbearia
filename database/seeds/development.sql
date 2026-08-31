-- Dados locais repetiveis. Nunca execute este arquivo em producao.
-- Senha das contas abaixo: password (hash bcrypt de desenvolvimento).

USE barbearia_db;

START TRANSACTION;

SET @senha_dev = '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi';

INSERT INTO usuarios (nome, email, telefone, senha_hash, role)
VALUES ('Administrador Local', 'admin@local.test', '41990000001', @senha_dev, 'admin')
ON DUPLICATE KEY UPDATE
  id = LAST_INSERT_ID(id), nome = VALUES(nome), senha_hash = VALUES(senha_hash),
  role = VALUES(role), ativo = 1;
SET @admin_id = LAST_INSERT_ID();

INSERT INTO usuarios (nome, email, telefone, senha_hash, role)
VALUES ('Barbeiro Local', 'barbeiro@local.test', '41990000002', @senha_dev, 'barbeiro')
ON DUPLICATE KEY UPDATE
  id = LAST_INSERT_ID(id), nome = VALUES(nome), senha_hash = VALUES(senha_hash),
  role = VALUES(role), ativo = 1;
SET @barbeiro_id = LAST_INSERT_ID();

INSERT INTO usuarios (nome, email, telefone, senha_hash, role)
VALUES ('Cliente Local', 'cliente@local.test', '41990000003', @senha_dev, 'cliente')
ON DUPLICATE KEY UPDATE
  id = LAST_INSERT_ID(id), nome = VALUES(nome), senha_hash = VALUES(senha_hash),
  role = VALUES(role), ativo = 1;

INSERT INTO barbearias
  (admin_id, nome, slug, descricao, cor_primaria, cor_secundaria,
   timezone, ativa, onboarding_concluido)
VALUES
  (@admin_id, 'Barbearia Local', 'barbearia-local', 'Ambiente de desenvolvimento',
   '#C9A84C', '#1A1A1A', 'America/Sao_Paulo', 1, 1)
ON DUPLICATE KEY UPDATE
  id = LAST_INSERT_ID(id), admin_id = VALUES(admin_id), ativa = 1;
SET @barbearia_id = LAST_INSERT_ID();

INSERT INTO memberships (barbearia_id, usuario_id, papel, ativo)
VALUES (@barbearia_id, @admin_id, 'owner', 1)
ON DUPLICATE KEY UPDATE papel = VALUES(papel), ativo = 1;

INSERT INTO colaboradores (barbearia_id, usuario_id, ativo)
VALUES (@barbearia_id, @barbeiro_id, 1)
ON DUPLICATE KEY UPDATE id = LAST_INSERT_ID(id), ativo = 1;
SET @colaborador_id = LAST_INSERT_ID();

INSERT INTO memberships (barbearia_id, usuario_id, papel, ativo)
VALUES (@barbearia_id, @barbeiro_id, 'professional', 1)
ON DUPLICATE KEY UPDATE papel = VALUES(papel), ativo = 1;

INSERT INTO servicos (barbearia_id, nome, descricao, preco, duracao_min, ativo)
SELECT @barbearia_id, seed.nome, seed.descricao, seed.preco, seed.duracao_min, 1
FROM (
  SELECT 'Corte Classico' nome, 'Corte tradicional' descricao, 35.00 preco, 30 duracao_min
  UNION ALL SELECT 'Corte + Barba', 'Combo completo', 55.00, 50
  UNION ALL SELECT 'Barba', 'Modelagem de barba', 25.00, 20
) AS seed
WHERE NOT EXISTS (
  SELECT 1 FROM servicos s
  WHERE s.barbearia_id = @barbearia_id AND s.nome = seed.nome
);

INSERT INTO horarios_funcionamento
  (colaborador_id, dia_semana, hora_inicio, hora_fim, ativo)
SELECT @colaborador_id, seed.dia_semana, '09:00:00', '20:00:00', 1
FROM (
  SELECT 2 dia_semana UNION ALL SELECT 3 UNION ALL SELECT 4
  UNION ALL SELECT 5 UNION ALL SELECT 6
) AS seed
WHERE NOT EXISTS (
  SELECT 1 FROM horarios_funcionamento h
  WHERE h.colaborador_id = @colaborador_id
    AND h.dia_semana = seed.dia_semana
    AND h.hora_inicio = '09:00:00'
    AND h.hora_fim = '20:00:00'
);

COMMIT;

SELECT @barbearia_id AS barbearia_id,
       @admin_id AS admin_id,
       @barbeiro_id AS barbeiro_id,
       @colaborador_id AS colaborador_id;
