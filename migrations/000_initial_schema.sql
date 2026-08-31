CREATE TABLE IF NOT EXISTS usuarios (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  nome VARCHAR(100) NOT NULL,
  email VARCHAR(150) NULL,
  telefone VARCHAR(20) NOT NULL,
  senha_hash VARCHAR(255) NOT NULL,
  role ENUM('cliente','barbeiro','admin') NOT NULL DEFAULT 'cliente',
  ativo TINYINT(1) NOT NULL DEFAULT 1,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  atualizado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_usuarios_telefone (telefone),
  UNIQUE KEY uq_usuarios_email (email),
  KEY idx_usuarios_role (role)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS barbearias (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  admin_id INT UNSIGNED NOT NULL,
  nome VARCHAR(150) NOT NULL,
  descricao TEXT NULL,
  logo_url VARCHAR(500) NULL,
  cor_primaria VARCHAR(7) DEFAULT '#1A1A1A',
  cor_secundaria VARCHAR(7) DEFAULT '#C9A84C',
  telefone VARCHAR(20) NULL,
  endereco VARCHAR(300) NULL,
  ativa TINYINT(1) NOT NULL DEFAULT 1,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  atualizado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_barbearias_admin (admin_id),
  CONSTRAINT fk_barbearia_admin FOREIGN KEY (admin_id) REFERENCES usuarios (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS colaboradores (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  barbearia_id INT UNSIGNED NOT NULL,
  usuario_id INT UNSIGNED NOT NULL,
  ativo TINYINT(1) NOT NULL DEFAULT 1,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_barbearia_usuario (barbearia_id, usuario_id),
  KEY idx_colaboradores_usuario (usuario_id),
  CONSTRAINT fk_colab_barbearia FOREIGN KEY (barbearia_id) REFERENCES barbearias (id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_colab_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS servicos (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  barbearia_id INT UNSIGNED NOT NULL,
  nome VARCHAR(100) NOT NULL,
  descricao TEXT NULL,
  preco DECIMAL(8,2) NOT NULL,
  duracao_min SMALLINT UNSIGNED NOT NULL,
  ativo TINYINT(1) NOT NULL DEFAULT 1,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  atualizado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_servicos_tenant_ativo (barbearia_id, ativo),
  CONSTRAINT fk_servico_barbearia FOREIGN KEY (barbearia_id) REFERENCES barbearias (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS horarios_funcionamento (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  colaborador_id INT UNSIGNED NOT NULL,
  dia_semana TINYINT NOT NULL,
  hora_inicio TIME NOT NULL,
  hora_fim TIME NOT NULL,
  ativo TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (id),
  KEY idx_horarios_colaborador_dia (colaborador_id, dia_semana),
  CONSTRAINT fk_horario_colaborador FOREIGN KEY (colaborador_id) REFERENCES colaboradores (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS agendamentos (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  cliente_id INT UNSIGNED NOT NULL,
  colaborador_id INT UNSIGNED NOT NULL,
  servico_id INT UNSIGNED NOT NULL,
  data_hora DATETIME NOT NULL,
  duracao_min SMALLINT NOT NULL,
  status ENUM('pendente','confirmado','concluido','cancelado') NOT NULL DEFAULT 'confirmado',
  valor_cobrado DECIMAL(8,2) NOT NULL,
  observacao TEXT NULL,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  atualizado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_agendamentos_colaborador_data (colaborador_id, data_hora),
  KEY idx_agendamentos_cliente_data (cliente_id, data_hora),
  KEY idx_agendamentos_status (status),
  CONSTRAINT fk_agend_cliente FOREIGN KEY (cliente_id) REFERENCES usuarios (id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_agend_colaborador FOREIGN KEY (colaborador_id) REFERENCES colaboradores (id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_agend_servico FOREIGN KEY (servico_id) REFERENCES servicos (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS horarios_bloqueados (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  colaborador_id INT UNSIGNED NOT NULL,
  data_hora_ini DATETIME NOT NULL,
  data_hora_fim DATETIME NOT NULL,
  motivo VARCHAR(200) NULL,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_bloqueios_colaborador_periodo (colaborador_id, data_hora_ini, data_hora_fim),
  CONSTRAINT fk_bloqueio_colaborador FOREIGN KEY (colaborador_id) REFERENCES colaboradores (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS notificacoes (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  usuario_id INT UNSIGNED NOT NULL,
  agendamento_id INT UNSIGNED NULL,
  tipo ENUM('lembrete','cancelamento','confirmacao','bloqueio') NOT NULL,
  titulo VARCHAR(150) NOT NULL,
  mensagem TEXT NOT NULL,
  enviada TINYINT(1) NOT NULL DEFAULT 0,
  enviada_em DATETIME NULL,
  agendada_para DATETIME NOT NULL,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_notificacoes_pendentes (enviada, agendada_para),
  KEY idx_notificacoes_usuario (usuario_id),
  CONSTRAINT fk_notif_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios (id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_notif_agendamento FOREIGN KEY (agendamento_id) REFERENCES agendamentos (id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS refresh_tokens (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  usuario_id INT UNSIGNED NOT NULL,
  token VARCHAR(500) NOT NULL,
  expira_em DATETIME NOT NULL,
  criado_em DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_refresh_token (token),
  KEY idx_refresh_usuario (usuario_id),
  CONSTRAINT fk_token_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
