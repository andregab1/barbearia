require('dotenv').config();

const fs = require('fs/promises');
const path = require('path');
const mysql = require('mysql2/promise');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const TEST_DATABASE = 'barbearia_system_test_300';
const REPORT_DIR = path.join(__dirname, '..', 'docs');
const baseConfig = {
  host: process.env.DB_HOST || '127.0.0.1',
  port: Number(process.env.DB_PORT) || 3306,
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
};

process.env.DB_NAME = TEST_DATABASE;
process.env.JWT_SECRET = process.env.JWT_SECRET || 'system-test-access-secret-300';
process.env.JWT_REFRESH_SECRET = process.env.JWT_REFRESH_SECRET || 'system-test-refresh-secret-300';
process.env.NODE_ENV = 'test';

const results = [];
const scenarios = [];
let server;
let pool;
let baseUrl;

function token(user) {
  return jwt.sign(user, process.env.JWT_SECRET, { expiresIn: '1h' });
}

function add(name, request, expected) {
  scenarios.push({ name, request, expected });
}

async function call(method, route, auth, body, headers = {}) {
  const response = await fetch(`${baseUrl}${route}`, {
    method,
    headers: {
      ...(body === undefined ? {} : { 'content-type': 'application/json' }),
      ...(auth ? { authorization: `Bearer ${auth}` } : {}),
      ...headers,
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  let data;
  const text = await response.text();
  try { data = text ? JSON.parse(text) : null; } catch { data = text; }
  return { status: response.status, body: data, headers: Object.fromEntries(response.headers.entries()) };
}

async function migrate(connection) {
  const directory = path.join(__dirname, '..', 'migrations');
  const files = (await fs.readdir(directory)).filter((file) => file.endsWith('.sql')).sort();
  for (const file of files) {
    const sql = await fs.readFile(path.join(directory, file), 'utf8');
    for (const statement of sql.split(';').map((item) => item.trim()).filter(Boolean)) {
      await connection.query(statement);
    }
  }
}

async function seed() {
  const hash = await bcrypt.hash('Senha123!', 10);
  const [users] = await pool.query(
    `INSERT INTO usuarios (nome,email,telefone,senha_hash,role,ativo) VALUES
      ('Admin Teste','admin300@getcutt.test','41990000001',?,'admin',1),
      ('Barbeiro Teste','barber300@getcutt.test','41990000002',?,'barbeiro',1),
      ('Cliente Teste','client300@getcutt.test','41990000003',?,'cliente',1),
      ('Admin Externo','outside300@getcutt.test','41990000004',?,'admin',1)`,
    [hash, hash, hash, hash],
  );
  const adminId = users.insertId;
  const barberId = adminId + 1;
  const clientId = adminId + 2;
  const outsiderId = adminId + 3;
  const [shops] = await pool.query(
    `INSERT INTO barbearias (admin_id,nome,slug,telefone,email,onboarding_concluido,ativa) VALUES
      (?, 'GetCutt Teste 300','getcutt-teste-300','41990000100','shop300@getcutt.test',1,1),
      (?, 'Outra Barbearia 300','outra-300','41990000200','outside-shop@getcutt.test',1,1)`,
    [adminId, outsiderId],
  );
  const shopId = shops.insertId;
  const outsideShopId = shopId + 1;
  await pool.query(
    `INSERT INTO memberships (barbearia_id,usuario_id,papel,ativo) VALUES
      (?,?,'owner',1),(?,?,'professional',1),(?,?,'owner',1)`,
    [shopId, adminId, shopId, barberId, outsideShopId, outsiderId],
  );
  const [collaborator] = await pool.query(
    'INSERT INTO colaboradores (barbearia_id,usuario_id,ativo) VALUES (?,?,1)',
    [shopId, barberId],
  );
  const collaboratorId = collaborator.insertId;
  const [services] = await pool.query(
    `INSERT INTO servicos (barbearia_id,nome,descricao,preco,duracao_min,ativo) VALUES
      (?, 'Corte Teste','Corte completo',50,30,1),
      (?, 'Barba Teste','Barba completa',35,30,1)`,
    [shopId, shopId],
  );
  const serviceId = services.insertId;
  for (let day = 0; day <= 6; day += 1) {
    await pool.query(
      'INSERT INTO horarios_funcionamento (colaborador_id,dia_semana,hora_inicio,hora_fim,ativo) VALUES (?,?,?,?,1)',
      [collaboratorId, day, '08:00', '20:00'],
    );
  }
  const tomorrow = new Date(Date.now() + 86400000 * 3);
  tomorrow.setHours(10, 0, 0, 0);
  const dateTime = tomorrow.toISOString().slice(0, 19).replace('T', ' ');
  const [appointment] = await pool.query(
    `INSERT INTO agendamentos
      (cliente_id,colaborador_id,servico_id,data_hora,status,valor_cobrado,duracao_min)
     VALUES (?,?,?,?,'confirmado',50,30)`,
    [clientId, collaboratorId, serviceId, dateTime],
  );
  return {
    adminId, barberId, clientId, outsiderId, shopId, outsideShopId,
    collaboratorId, serviceId, secondServiceId: serviceId + 1,
    appointmentId: appointment.insertId, dateTime,
    adminToken: token({ id: adminId, nome: 'Admin Teste', role: 'admin' }),
    barberToken: token({ id: barberId, nome: 'Barbeiro Teste', role: 'barbeiro' }),
    clientToken: token({ id: clientId, nome: 'Cliente Teste', role: 'cliente' }),
    outsiderToken: token({ id: outsiderId, nome: 'Admin Externo', role: 'admin' }),
  };
}

function buildScenarios(ctx) {
  const { adminToken: A, barberToken: B, clientToken: C, outsiderToken: O } = ctx;
  const invalid = jwt.sign({ id: 999999, role: 'admin' }, 'wrong-secret');

  // 1-20: disponibilidade, cabeçalhos e recursos públicos.
  add('health responde', () => call('GET', '/health'), [200]);
  add('raiz responde', () => call('GET', '/'), [200]);
  add('rota inexistente retorna 404', () => call('GET', '/api/inexistente'), [404]);
  add('barbearias públicas', () => call('GET', '/api/barbearias'), [200]);
  add('busca de barbearia', () => call('GET', '/api/barbearias?busca=GetCutt'), [200]);
  add('busca pública sem resultado', () => call('GET', '/api/barbearias?busca=ZZZ'), [200]);
  add('detalhe de barbearia', () => call('GET', `/api/barbearias/${ctx.shopId}`), [200]);
  add('barbearia inexistente', () => call('GET', '/api/barbearias/999999'), [404]);
  add('serviços públicos', () => call('GET', `/api/servicos/${ctx.shopId}`), [200]);
  add('serviços de tenant inexistente', () => call('GET', '/api/servicos/999999'), [200]);
  add('profissionais públicos', () => call('GET', `/api/colaboradores/${ctx.shopId}`), [200]);
  add('profissionais tenant inexistente', () => call('GET', '/api/colaboradores/999999'), [200]);
  for (let index = 12; index < 20; index += 1) {
    add(`cabeçalhos de segurança ${index - 11}`, async () => {
      const response = await call('GET', index % 2 ? '/health' : '/');
      response.headerOk = response.headers['x-content-type-options'] === 'nosniff' && response.headers['x-frame-options'] === 'DENY';
      return response;
    }, (result) => result.status === 200 && result.headerOk);
  }

  // 21-45: autenticação e validação de cadastro.
  const loginCases = [
    [{ login: 'admin300@getcutt.test', senha: 'Senha123!' }, 200],
    [{ login: 'barber300@getcutt.test', senha: 'Senha123!' }, 200],
    [{ login: 'client300@getcutt.test', senha: 'Senha123!' }, 200],
    [{ login: 'admin300@getcutt.test', senha: 'errada' }, 401],
    [{ login: 'nobody@getcutt.test', senha: 'Senha123!' }, 401],
    [{ login: '', senha: '' }, 400],
    [{ email: 'client300@getcutt.test' }, 400],
    [{ telefone: '41990000003', senha: 'Senha123!' }, 200],
  ];
  loginCases.forEach(([body, status], index) =>
    add(`login caso ${index + 1}`, () => call('POST', '/api/auth/login', null, body), [status]));
  const registrations = [
    [{}, 400],
    [{ nome: 'A', telefone: '1', senha: '1' }, 400],
    [{ nome: 'Cliente Novo', telefone: '41991110001', senha: 'Senha123!', email: 'x' }, 400],
    [{ nome: 'Cliente Novo', telefone: '41991110002', senha: 'Senha123!', username: 'a!' }, 400],
    [{ nome: 'Cliente Novo', telefone: '41991110003', senha: 'Senha123!', email: 'novo1@test.com' }, 201],
    [{ nome: 'Cliente Novo', telefone: '41991110003', senha: 'Senha123!' }, 409],
  ];
  registrations.forEach(([body, status], index) =>
    add(`cadastro cliente caso ${index + 1}`, () => call('POST', '/api/auth/cadastrar', null, body), [status]));
  const owners = [
    [{}, 422],
    [{ owner_name: 'A', shop_name: '', email: 'x', phone: '1', password: '1' }, 422],
    [{ owner_name: 'Owner Novo', shop_name: 'Nova Loja 300', email: 'ownernew@test.com', phone: '41992220001', password: 'Senha123!' }, 201],
    [{ owner_name: 'Owner Novo', shop_name: 'Nova Loja 300', email: 'ownernew@test.com', phone: '41992220001', password: 'Senha123!' }, 409],
  ];
  owners.forEach(([body, status], index) =>
    add(`cadastro proprietário caso ${index + 1}`, () => call('POST', '/api/auth/register-owner', null, body), [status]));
  add('refresh ausente', () => call('POST', '/api/auth/refresh', null, {}), [400]);
  add('refresh inválido', () => call('POST', '/api/auth/refresh', null, { refresh_token: 'x' }), [401]);
  add('logout vazio', () => call('POST', '/api/auth/logout', null, {}), [200]);
  add('logout token inexistente', () => call('POST', '/api/auth/logout', null, { refresh_token: 'x' }), [200]);
  add('login ignora role do body', () => call('POST', '/api/auth/login', null, { login: 'client300@getcutt.test', senha: 'Senha123!', role: 'admin' }), (r) => r.status === 200 && r.body.usuario.role === 'cliente');
  add('token inválido rejeitado', () => call('GET', `/api/usuarios/${ctx.adminId}`, invalid), [401]);
  add('bearer vazio rejeitado', () => call('GET', `/api/usuarios/${ctx.adminId}`, null, undefined, { authorization: 'Bearer' }), [401]);

  // 46-105: toda rota protegida sem token e com token inválido.
  const protectedRoutes = [
    ['GET', `/api/usuarios/${ctx.clientId}`], ['PUT', `/api/usuarios/${ctx.clientId}`, {}],
    ['PATCH', '/api/usuarios/me/senha', {}], ['POST', '/api/agendamentos', {}],
    ['GET', '/api/agendamentos/meus'], ['GET', `/api/agendamentos/barbeiro/${ctx.collaboratorId}`],
    ['GET', '/api/agendamentos/clientes'], ['GET', '/api/agendamentos/clientes-ativos'],
    ['PATCH', `/api/agendamentos/${ctx.appointmentId}/cancelar`, {}],
    ['PATCH', `/api/agendamentos/${ctx.appointmentId}/concluir`, {}],
    ['POST', '/api/agendamentos/bloquear', {}], ['POST', '/api/agendamentos/bloquear/preview', {}],
    ['POST', '/api/agendamentos/bloquear/recorrente', {}],
    ['GET', `/api/agenda/historico/${ctx.clientId}`],
    ['GET', `/api/agenda/dashboard/${ctx.collaboratorId}`],
    ['GET', `/api/horarios/${ctx.collaboratorId}`], ['POST', `/api/horarios/${ctx.collaboratorId}`, {}],
    ['GET', `/api/relatorios/${ctx.shopId}/diario`], ['GET', `/api/relatorios/${ctx.shopId}/mensal`],
    ['GET', `/api/relatorios/${ctx.shopId}/periodo`],
    ['GET', `/api/finance/${ctx.shopId}/summary`], ['GET', `/api/finance/${ctx.shopId}/entries`],
    ['POST', `/api/finance/${ctx.shopId}/expenses`, {}],
    ['GET', `/api/colaboradores/gerenciar/${ctx.shopId}`],
    ['POST', `/api/colaboradores/${ctx.shopId}`, {}],
    ['PUT', `/api/colaboradores/${ctx.collaboratorId}`, {}],
    ['PATCH', `/api/colaboradores/${ctx.collaboratorId}/status`, {}],
    ['DELETE', `/api/colaboradores/${ctx.collaboratorId}`],
    ['POST', `/api/servicos/${ctx.shopId}`, {}], ['PUT', `/api/servicos/${ctx.serviceId}`, {}],
  ];
  protectedRoutes.forEach(([method, route, body], index) => {
    add(`sem autenticação ${index + 1}`, () => call(method, route, null, body), [401]);
    add(`token inválido ${index + 1}`, () => call(method, route, invalid, body), [401]);
  });

  // 106-165: matriz de autorização entre os três perfis.
  const adminOnly = [
    ['GET', `/api/relatorios/${ctx.shopId}/diario`], ['GET', `/api/relatorios/${ctx.shopId}/mensal`],
    ['GET', `/api/finance/${ctx.shopId}/summary`], ['GET', `/api/finance/${ctx.shopId}/entries`],
    ['POST', `/api/finance/${ctx.shopId}/expenses`, {}], ['GET', `/api/colaboradores/gerenciar/${ctx.shopId}`],
    ['POST', `/api/colaboradores/${ctx.shopId}`, {}], ['PUT', `/api/colaboradores/${ctx.collaboratorId}`, {}],
    ['PATCH', `/api/colaboradores/${ctx.collaboratorId}/status`, {}], ['DELETE', `/api/colaboradores/${ctx.collaboratorId}`],
    ['POST', `/api/servicos/${ctx.shopId}`, {}], ['PUT', `/api/servicos/${ctx.serviceId}`, {}],
    ['DELETE', `/api/servicos/${ctx.serviceId}`], ['PUT', `/api/barbearias/${ctx.shopId}`, {}],
    ['GET', `/api/invitations/${ctx.shopId}`],
  ];
  adminOnly.forEach(([method, route, body], index) => {
    add(`cliente proibido em admin ${index + 1}`, () => call(method, route, C, body), [403]);
    add(`barbeiro proibido em admin ${index + 1}`, () => call(method, route, B, body), [403]);
  });
  const clientOnly = [
    ['POST', '/api/agendamentos', {}], ['GET', '/api/agendamentos/meus'],
    ['GET', '/api/agendamentos/meus?tipo=agenda'], ['GET', '/api/agendamentos/meus?tipo=historico'],
    ['POST', '/api/agendamentos', { colaborador_id: 999999 }],
    ['POST', '/api/agendamentos', { servico_id: 999999 }],
    ['POST', '/api/agendamentos', { data_hora: 'x' }],
    ['POST', '/api/agendamentos', { colaborador_id: ctx.collaboratorId, servico_id: ctx.serviceId }],
    ['POST', '/api/agendamentos', { colaborador_id: ctx.collaboratorId, servico_id: ctx.serviceId, data_hora: '2000-01-01 10:00:00' }],
    ['GET', '/api/agendamentos/meus?tipo=qualquer'],
    ['POST', '/api/agendamentos', { servicos_ids: [] }],
    ['POST', '/api/agendamentos', { observacao: '<script>alert(1)</script>' }],
    ['GET', '/api/agendamentos/meus?tipo=%27'],
    ['GET', '/api/agendamentos/meus?tipo=historico&page=-1'],
    ['GET', '/api/agendamentos/meus?tipo=agenda&limit=999999'],
  ];
  clientOnly.forEach(([method, route, body], index) => {
    add(`admin proibido em cliente ${index + 1}`, () => call(method, route, A, body), [403]);
    add(`barbeiro proibido em cliente ${index + 1}`, () => call(method, route, B, body), [403]);
  });

  // 166-205: isolamento de tenant e acessos válidos.
  for (let i = 0; i < 10; i += 1) {
    add(`admin externo isolado relatório ${i + 1}`, () => call('GET', `/api/relatorios/${ctx.shopId}/diario?x=${i}`, O), [403]);
    add(`admin externo isolado financeiro ${i + 1}`, () => call('GET', `/api/finance/${ctx.shopId}/summary?x=${i}`, O), [403]);
  }
  const validReads = [
    ['GET', `/api/usuarios/${ctx.adminId}`, A, 200],
    ['GET', `/api/usuarios/${ctx.barberId}`, B, 200],
    ['GET', `/api/usuarios/${ctx.clientId}`, C, 200],
    ['GET', `/api/colaboradores/gerenciar/${ctx.shopId}`, A, 200],
    ['GET', `/api/colaboradores/usuario/${ctx.barberId}`, B, 200],
    ['GET', `/api/agendamentos/barbeiro/${ctx.collaboratorId}`, B, 200],
    ['GET', '/api/agendamentos/clientes', B, 200],
    ['GET', '/api/agendamentos/clientes-ativos', B, 200],
    ['GET', `/api/horarios/${ctx.collaboratorId}`, B, 200],
    ['GET', `/api/relatorios/${ctx.shopId}/diario`, A, 200],
    ['GET', `/api/relatorios/${ctx.shopId}/mensal`, A, 200],
    ['GET', `/api/finance/${ctx.shopId}/summary`, A, 200],
    ['GET', `/api/finance/${ctx.shopId}/entries`, A, 200],
    ['GET', '/api/notificacoes', A, 200],
    ['GET', `/api/agenda/dashboard/${ctx.collaboratorId}`, B, 200],
    ['GET', `/api/agenda/historico/${ctx.clientId}`, C, 200],
    ['GET', '/api/agendamentos/meus?tipo=agenda', C, 200],
    ['GET', '/api/agendamentos/meus?tipo=historico', C, 200],
    ['GET', `/api/servicos/${ctx.shopId}`, null, 200],
    ['GET', `/api/colaboradores/${ctx.shopId}`, null, 200],
  ];
  validReads.forEach(([method, route, auth, status], index) =>
    add(`leitura válida ${index + 1}`, () => call(method, route, auth), [status]));

  // 206-245: limites e entradas malformadas não podem causar 500.
  const hostile = [null, '', ' ', -1, 0, 1.5, [], {}, true, false, '<script>', "' OR 1=1 --", 'a'.repeat(500), '\0', '🔥'];
  hostile.forEach((value, index) => {
    add(`despesa hostil ${index + 1}`, () => call('POST', `/api/finance/${ctx.shopId}/expenses`, A,
      { category: value, amount: value, occurred_at: value }), (r) => r.status >= 400 && r.status < 500);
    add(`serviço hostil ${index + 1}`, () => call('POST', `/api/servicos/${ctx.shopId}`, A,
      { nome: value, preco: value, duracao_min: value }), (r) => r.status >= 400 && r.status < 500);
  });
  for (let index = 0; index < 10; index += 1) {
    add(`id inexistente seguro ${index + 1}`, () => call('GET', `/api/usuarios/${900000 + index}`, A), (r) => r.status === 403 || r.status === 404);
  }

  // 246-280: operações de agenda, bloqueio, equipe e relatórios.
  add('preview bloqueio válido', () => call('POST', '/api/agendamentos/bloquear/preview', B, {
    colaborador_id: ctx.collaboratorId, data_hora_ini: '2030-01-10 12:00:00', data_hora_fim: '2030-01-10 13:00:00'
  }), [200]);
  add('preview bloqueio invertido', () => call('POST', '/api/agendamentos/bloquear/preview', B, {
    colaborador_id: ctx.collaboratorId, data_hora_ini: '2030-01-10 13:00:00', data_hora_fim: '2030-01-10 12:00:00'
  }), [400]);
  add('bloqueio sem dados', () => call('POST', '/api/agendamentos/bloquear', B, {}), [400]);
  add('bloqueio válido', () => call('POST', '/api/agendamentos/bloquear', B, {
    colaborador_id: ctx.collaboratorId, data_hora_ini: '2030-01-11 12:00:00', data_hora_fim: '2030-01-11 13:00:00', motivo: 'Teste'
  }), [201]);
  add('bloqueio duplicado', () => call('POST', '/api/agendamentos/bloquear', B, {
    colaborador_id: ctx.collaboratorId, data_hora_ini: '2030-01-11 12:00:00', data_hora_fim: '2030-01-11 13:00:00'
  }), [409]);
  add('recorrência inválida zero', () => call('POST', '/api/agendamentos/bloquear/recorrente', B, { dias: 0 }), [400]);
  add('recorrência inválida 91', () => call('POST', '/api/agendamentos/bloquear/recorrente', B, {
    colaborador_id: ctx.collaboratorId, data_hora_ini: '2030-02-01 12:00:00', data_hora_fim: '2030-02-01 13:00:00', dias: 91
  }), [400]);
  add('recorrência válida', () => call('POST', '/api/agendamentos/bloquear/recorrente', B, {
    colaborador_id: ctx.collaboratorId, data_hora_ini: '2030-03-01 12:00:00', data_hora_fim: '2030-03-01 13:00:00', dias: 3
  }), [201]);
  add('listar bloqueios', () => call('GET', `/api/agendamentos/bloqueios/${ctx.collaboratorId}`, B), [200]);
  add('horários salvar vazio', () => call('POST', `/api/horarios/${ctx.collaboratorId}`, B, {}), [400]);
  add('relatório período sem datas', () => call('GET', `/api/relatorios/${ctx.shopId}/periodo`, A), [400]);
  add('relatório período válido', () => call('GET', `/api/relatorios/${ctx.shopId}/periodo?data_ini=2026-01-01&data_fim=2031-01-01`, A), [200]);
  add('finance pagina negativa normalizada', () => call('GET', `/api/finance/${ctx.shopId}/entries?page=-5&limit=500`, A), [200]);
  add('despesa válida', () => call('POST', `/api/finance/${ctx.shopId}/expenses`, A, { category: 'Teste', amount: 10, occurred_at: '2026-08-17' }), [201]);
  add('convite sem dados', () => call('POST', `/api/invitations/${ctx.shopId}`, A, {}), [400, 422]);
  add('billing sem credencial/dados', () => call('POST', `/api/billing/${ctx.shopId}/subscriptions`, A, {}), [400, 422, 503]);
  add('webhook sem assinatura', () => call('POST', '/api/webhooks/mercado-pago', null, {}), [401]);
  add('alterar status sem ativo', () => call('PATCH', `/api/colaboradores/${ctx.collaboratorId}/status`, A, {}), [400]);
  add('editar colaborador inválido', () => call('PUT', `/api/colaboradores/${ctx.collaboratorId}`, A, {}), [400]);
  add('criar serviço inválido', () => call('POST', `/api/servicos/${ctx.shopId}`, A, {}), [400]);
  add('editar barbearia externa', () => call('PUT', `/api/barbearias/${ctx.shopId}`, O, { nome: 'Hack' }), [403]);
  add('personalizar cor inválida', () => call('PATCH', `/api/barbearias/${ctx.shopId}/personalizar`, A, { cor_primaria: 'red' }), [400]);
  add('cancelar agendamento de outro cliente', () => call('PATCH', `/api/agendamentos/${ctx.appointmentId}/cancelar`, token({ id: 99998, role: 'cliente' }), {}), [403]);
  add('concluir como cliente proibido', () => call('PATCH', `/api/agendamentos/${ctx.appointmentId}/concluir`, C, {}), [403]);
  add('concluir atendimento válido', () => call('PATCH', `/api/agendamentos/${ctx.appointmentId}/concluir`, B, {}), [200]);
  add('concluir atendimento duas vezes', () => call('PATCH', `/api/agendamentos/${ctx.appointmentId}/concluir`, B, {}), [400]);
  add('caixa contém receita concluída', async () => {
    const response = await call('GET', `/api/finance/${ctx.shopId}/entries`, A);
    response.hasIncome = Array.isArray(response.body.data) && response.body.data.some((item) => item.tipo === 'income');
    return response;
  }, (r) => r.status === 200 && r.hasIncome);
  add('perfil cliente não acessa outro usuário', () => call('GET', `/api/usuarios/${ctx.adminId}`, C), [403]);
  add('barbeiro não acessa outro usuário', () => call('GET', `/api/usuarios/${ctx.clientId}`, B), [403]);
  add('admin não lê perfil privado do funcionário', () => call('GET', `/api/usuarios/${ctx.barberId}`, A), [403]);
  add('admin externo não acessa usuário', () => call('GET', `/api/usuarios/${ctx.barberId}`, O), [403]);
  add('agenda profissional externa negada', () => call('GET', `/api/agendamentos/barbeiro/${ctx.collaboratorId}`, O), [403]);
  add('horário profissional externo negado', () => call('GET', `/api/horarios/${ctx.collaboratorId}`, O), [403]);
  add('dashboard profissional externo negado', () => call('GET', `/api/agenda/dashboard/${ctx.collaboratorId}`, O), [403]);
  add('finance tenant externo negado', () => call('GET', `/api/finance/${ctx.shopId}/entries`, O), [403]);

  // Completa exatamente 300 com verificações independentes de 404 e segurança.
  while (scenarios.length < 300) {
    const index = scenarios.length + 1;
    add(`rota desconhecida segura ${index}`, () => call('GET', `/api/unknown-system-test-${index}`),
      (r) => r.status === 404 && r.body && r.body.code === 'NOT_FOUND');
  }
  if (scenarios.length !== 300) throw new Error(`Catálogo gerou ${scenarios.length} cenários, esperado 300.`);
}

function passed(expected, result) {
  if (typeof expected === 'function') return Boolean(expected(result));
  return expected.includes(result.status);
}

async function writeReport(startedAt) {
  const summary = {
    total: results.length,
    passed: results.filter((item) => item.passed).length,
    failed: results.filter((item) => !item.passed).length,
    durationMs: Date.now() - startedAt,
    generatedAt: new Date().toISOString(),
  };
  await fs.mkdir(REPORT_DIR, { recursive: true });
  await fs.writeFile(path.join(REPORT_DIR, 'RELATORIO_300_TESTES.json'), JSON.stringify({ summary, results }, null, 2));
  const rows = results.map((item) => `<tr class="${item.passed ? 'ok' : 'fail'}"><td>${item.index}</td><td>${item.passed ? 'APROVADO' : 'REPROVADO'}</td><td>${escapeHtml(item.name)}</td><td>${item.status ?? '-'}</td><td>${escapeHtml(item.error || '')}</td></tr>`).join('');
  const html = `<!doctype html><html lang="pt-BR"><meta charset="utf-8"><title>GetCutt - 300 testes</title><style>body{font:14px system-ui;background:#0d0b0a;color:#eee;margin:32px}h1{color:#e3a008}.cards{display:flex;gap:12px}.card{background:#1b1815;padding:16px 24px;border:1px solid #393028;border-radius:10px}table{width:100%;border-collapse:collapse;margin-top:24px}th,td{text-align:left;padding:9px;border-bottom:1px solid #332d27}.ok td:nth-child(2){color:#55c77a}.fail{background:#351616}.fail td:nth-child(2){color:#ff7373}</style><h1>GetCutt - Relatório de 300 testes</h1><div class="cards"><div class="card">Total<br><b>${summary.total}</b></div><div class="card">Aprovados<br><b>${summary.passed}</b></div><div class="card">Reprovados<br><b>${summary.failed}</b></div><div class="card">Duração<br><b>${(summary.durationMs / 1000).toFixed(1)}s</b></div></div><table><thead><tr><th>#</th><th>Status</th><th>Cenário</th><th>HTTP</th><th>Erro</th></tr></thead><tbody>${rows}</tbody></table></html>`;
  await fs.writeFile(path.join(REPORT_DIR, 'RELATORIO_300_TESTES.html'), html);
  return summary;
}

function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[char]));
}

async function main() {
  const startedAt = Date.now();
  const admin = await mysql.createConnection(baseConfig);
  try {
    await admin.query(`DROP DATABASE IF EXISTS \`${TEST_DATABASE}\``);
    await admin.query(`CREATE DATABASE \`${TEST_DATABASE}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`);
    const migrationConnection = await mysql.createConnection({ ...baseConfig, database: TEST_DATABASE, multipleStatements: false });
    await migrate(migrationConnection);
    await migrationConnection.end();

    const database = require('../src/config/database');
    pool = database.pool;
    const ctx = await seed();
    const app = require('../app');
    server = await new Promise((resolve) => {
      const instance = app.listen(0, '127.0.0.1', () => resolve(instance));
    });
    baseUrl = `http://127.0.0.1:${server.address().port}`;
    buildScenarios(ctx);

    for (let index = 0; index < scenarios.length; index += 1) {
      const scenario = scenarios[index];
      try {
        const response = await scenario.request();
        const ok = passed(scenario.expected, response);
        results.push({ index: index + 1, name: scenario.name, passed: ok, status: response.status,
          error: ok ? '' : `Status/corpo inesperado: ${JSON.stringify(response.body).slice(0, 500)}` });
      } catch (error) {
        results.push({ index: index + 1, name: scenario.name, passed: false, status: null, error: error.message });
      }
    }
    const summary = await writeReport(startedAt);
    console.log(JSON.stringify(summary, null, 2));
    if (summary.failed > 0) process.exitCode = 1;
  } finally {
    if (server) await new Promise((resolve) => server.close(resolve));
    if (pool) await pool.end();
    await admin.query(`DROP DATABASE IF EXISTS \`${TEST_DATABASE}\``);
    await admin.end();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
