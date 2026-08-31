-- Consultas somente leitura para conferir o estado do banco.

USE barbearia_db;

SELECT id, nome, email, telefone, role, ativo, criado_em
FROM usuarios
ORDER BY id;

SELECT id, nome, slug, logo_url, cor_primaria, cor_secundaria, ativa
FROM barbearias
ORDER BY id;

SELECT c.id AS colaborador_id,
       c.barbearia_id,
       u.id AS usuario_id,
       u.nome,
       c.ativo
FROM colaboradores c
JOIN usuarios u ON u.id = c.usuario_id
ORDER BY c.barbearia_id, u.nome;

SELECT c.id AS colaborador_id,
       u.nome,
       hf.dia_semana,
       hf.hora_inicio,
       hf.hora_fim,
       hf.ativo
FROM horarios_funcionamento hf
JOIN colaboradores c ON c.id = hf.colaborador_id
JOIN usuarios u ON u.id = c.usuario_id
ORDER BY c.id, hf.dia_semana, hf.hora_inicio;

SELECT id, colaborador_id, data_hora_ini, data_hora_fim, motivo
FROM horarios_bloqueados
ORDER BY data_hora_ini DESC
LIMIT 50;

SELECT name, applied_at
FROM schema_migrations
ORDER BY name;
