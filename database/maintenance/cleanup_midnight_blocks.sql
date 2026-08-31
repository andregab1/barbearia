-- Manutencao manual para bloqueios antigos criados incorretamente a meia-noite.
-- O DELETE fica intencionalmente comentado: primeiro valide a pre-visualizacao.

USE barbearia_db;

SELECT id, colaborador_id, data_hora_ini, data_hora_fim, motivo
FROM horarios_bloqueados
WHERE TIME(data_hora_ini) = '00:00:00'
ORDER BY data_hora_ini;

-- Depois de conferir o SELECT, execute conscientemente em uma transacao:
-- START TRANSACTION;
-- DELETE FROM horarios_bloqueados
-- WHERE TIME(data_hora_ini) = '00:00:00';
-- SELECT ROW_COUNT() AS bloqueios_removidos;
-- COMMIT;
-- Use ROLLBACK no lugar de COMMIT se o resultado nao for o esperado.
