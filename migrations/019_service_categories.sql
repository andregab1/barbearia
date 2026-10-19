CREATE TABLE IF NOT EXISTS categorias_servico (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  barbearia_id INT UNSIGNED NOT NULL,
  nome VARCHAR(80) NOT NULL,
  ativo TINYINT(1) NOT NULL DEFAULT 1,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  atualizado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_categoria_servico_tenant_nome (barbearia_id, nome),
  KEY idx_categoria_servico_tenant_ativo (barbearia_id, ativo),
  CONSTRAINT fk_categoria_servico_barbearia
    FOREIGN KEY (barbearia_id) REFERENCES barbearias (id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE servicos
  ADD COLUMN categoria_id INT UNSIGNED NULL AFTER barbearia_id,
  ADD KEY idx_servicos_categoria (categoria_id),
  ADD CONSTRAINT fk_servico_categoria
    FOREIGN KEY (categoria_id) REFERENCES categorias_servico (id)
    ON DELETE SET NULL ON UPDATE CASCADE;

INSERT INTO categorias_servico (barbearia_id, nome)
SELECT DISTINCT
  s.barbearia_id,
  CASE
    WHEN LOWER(s.nome) LIKE '%combo%' OR s.nome LIKE '%+%' THEN 'Combo'
    WHEN LOWER(s.nome) LIKE '%barba%' THEN 'Barba'
    WHEN LOWER(s.nome) LIKE '%limpeza%' THEN 'Limpeza'
    WHEN LOWER(s.nome) LIKE '%corte%' THEN 'Corte'
    ELSE 'Outros'
  END AS nome
FROM servicos s
ON DUPLICATE KEY UPDATE ativo = 1;

UPDATE servicos s
JOIN categorias_servico c
  ON c.barbearia_id = s.barbearia_id
 AND c.nome = CASE
   WHEN LOWER(s.nome) LIKE '%combo%' OR s.nome LIKE '%+%' THEN 'Combo'
   WHEN LOWER(s.nome) LIKE '%barba%' THEN 'Barba'
   WHEN LOWER(s.nome) LIKE '%limpeza%' THEN 'Limpeza'
   WHEN LOWER(s.nome) LIKE '%corte%' THEN 'Corte'
   ELSE 'Outros'
 END
SET s.categoria_id = c.id
WHERE s.categoria_id IS NULL;
