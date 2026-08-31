# Plano de Melhorias — GetCutt / Barbearia

**Data do diagnóstico:** 15 de agosto de 2026  
**Escopo analisado:** API Node.js/Express, aplicativo Flutter, banco de dados e organização do repositório.

## Objetivo

Este documento registra as melhorias técnicas identificadas no projeto e propõe uma ordem segura de implementação. O foco é proteger dados e operações, evitar inconsistências em agendamentos, facilitar a manutenção e preparar o sistema para publicação.

## Resumo executivo

O projeto possui uma base funcional, mas ainda precisa de reforços antes de ser tratado como pronto para produção. Os maiores riscos estão no versionamento de segredos, na autorização incompleta de algumas rotas, na possibilidade de o cliente controlar preço e duração de serviços e na ausência de proteção contra reservas simultâneas.

### Ordem recomendada

1. Remover e trocar credenciais expostas.
2. Corrigir autorização e isolamento de dados.
3. Fazer o servidor calcular preços e durações.
4. Garantir atomicidade na criação de agendamentos.
5. Limpar e organizar o repositório.
6. Validar entradas e proteger a API.
7. Reforçar sessões e refresh tokens.
8. Configurar ambientes do aplicativo.
9. Criar testes automatizados e CI.
10. Completar a documentação operacional.

---

## P0 — Segurança crítica

### 1. Remover credenciais do Git

**Situação:** o arquivo `.env` está versionado e contém dados de conexão com o banco e segredos JWT.

**Risco:** qualquer pessoa com acesso ao repositório ou ao histórico pode obter credenciais, emitir tokens ou acessar o banco.

**Ações recomendadas:**

- adicionar `.env` ao `.gitignore`;
- criar `.env.example` contendo apenas nomes e exemplos seguros;
- remover o `.env` do índice e do histórico do Git;
- trocar senha do banco, `JWT_SECRET` e `JWT_REFRESH_SECRET`;
- armazenar segredos no provedor de hospedagem ou gerenciador de segredos;
- impedir que a aplicação inicie quando segredos obrigatórios estiverem ausentes ou fracos.

**Critério de conclusão:** nenhum segredo real aparece no Git ou em artefatos distribuídos, e todas as credenciais anteriormente expostas foram rotacionadas.

### 2. Corrigir autorização e propriedade dos recursos

**Situação:** algumas rotas verificam apenas se existe um token ou se o usuário possui determinado papel. Elas não confirmam se o registro solicitado pertence ao usuário, profissional ou barbearia autenticada.

**Exemplos identificados:**

- um usuário autenticado pode consultar outro usuário por ID;
- um barbeiro pode tentar consultar ou concluir agendamentos de outro profissional;
- horários e bloqueios podem ser alterados usando o ID de outro colaborador;
- operações administrativas recebem `barbearia_id` da URL sem demonstrar isolamento consistente por tenant.

**Ações recomendadas:**

- clientes só podem ler e alterar os próprios dados e agendamentos;
- barbeiros só podem operar sobre o próprio `colaborador_id` e sua própria agenda;
- administradores só podem operar dentro da barbearia à qual pertencem;
- derivar usuário, colaborador e barbearia do token ou do banco, não confiar apenas em IDs enviados pelo cliente;
- centralizar verificações em middlewares/policies reutilizáveis;
- retornar `403` para ações sem permissão e evitar exposição desnecessária de existência de registros.

**Critério de conclusão:** testes automatizados comprovam que cada perfil acessa apenas seus próprios recursos e que tentativas cruzadas retornam erro.

### 3. Impedir que o cliente defina preço e duração

**Situação:** a criação de agendamentos aceita `valor_override` e `duracao_override` enviados pelo aplicativo.

**Risco:** uma requisição manipulada pode reduzir o preço, diminuir a duração para contornar conflitos ou criar períodos inválidos.

**Ações recomendadas:**

- remover esses campos da API pública de cliente;
- buscar preços e durações exclusivamente no banco;
- se houver múltiplos serviços, receber apenas os IDs e calcular totais no servidor;
- permitir overrides somente em uma rota administrativa específica, auditada e autorizada;
- validar limites monetários e usar tipo decimal de forma consistente.

**Critério de conclusão:** o mesmo conjunto de serviços sempre gera preço e duração calculados pelo backend, independentemente do corpo enviado pelo cliente.

---

## P1 — Integridade e confiabilidade

### 4. Evitar reserva simultânea do mesmo horário

**Situação:** a consulta de conflito e a inserção do agendamento são operações separadas.

**Risco:** duas requisições simultâneas podem passar pela consulta e reservar o mesmo período.

**Ações recomendadas:**

- executar verificação e inserção dentro de uma transação;
- aplicar bloqueio adequado nas linhas/faixas relevantes ou adotar uma tabela de slots com restrição única;
- tratar conflitos do banco como resposta HTTP `409`;
- incluir bloqueios do profissional na mesma regra atômica;
- testar concorrência com duas ou mais requisições simultâneas.

**Critério de conclusão:** sob concorrência, no máximo uma reserva para o mesmo profissional e intervalo é confirmada.

### 5. Usar transações em operações compostas

**Situação:** existem fluxos com vários comandos dependentes, como criar usuário e colaborador, alterar múltiplos registros, criar agendamento e notificação ou substituir todos os horários.

**Risco:** falha intermediária pode deixar dados parcialmente atualizados.

**Ações recomendadas:**

- envolver operações compostas em `BEGIN`, `COMMIT` e `ROLLBACK`;
- validar tudo antes de remover horários existentes;
- estabelecer chaves estrangeiras, índices e restrições no banco;
- tornar operações importantes idempotentes quando aplicável.

**Critério de conclusão:** uma falha intermediária não deixa registros órfãos nem estado parcial.

### 6. Validar entradas e regras de negócio

**Situação:** muitos campos são verificados apenas quanto à presença.

**Ações recomendadas:**

- usar um validador de esquema para corpo, parâmetros e query string;
- normalizar e validar telefone e e-mail;
- validar IDs inteiros positivos;
- rejeitar datas inválidas, passadas ou fora do horário de funcionamento;
- garantir que início seja anterior ao fim;
- impor limites de duração, observação, nomes e uploads;
- validar se serviço e colaborador estão ativos e pertencem à mesma barbearia;
- padronizar respostas de erro sem expor SQL ou detalhes internos.

**Critério de conclusão:** todas as rotas mutáveis têm schemas e testes para entradas válidas, ausentes, malformadas e extremas.

---

## P1 — Proteção da API e sessões

### 7. Aplicar proteções HTTP

**Situação:** o CORS está aberto para qualquer origem e não foi identificado controle de tentativas.

**Ações recomendadas:**

- restringir CORS às origens conhecidas por ambiente;
- adicionar headers seguros com middleware apropriado;
- aplicar rate limit, especialmente em login, cadastro e refresh;
- limitar tamanho e tipo de uploads e gerar nomes seguros;
- adicionar tratamento centralizado de erros e logs estruturados;
- definir política de proxy confiável corretamente na hospedagem;
- não registrar credenciais, tokens ou dados pessoais nos logs.

**Critério de conclusão:** origens indevidas são bloqueadas, abuso de autenticação é limitado e erros seguem formato consistente.

### 8. Reforçar refresh tokens e logout

**Situação:** refresh tokens completos são armazenados no banco e o prazo persistido é fixo em sete dias.

**Risco:** acesso indevido ao banco permite reutilizar sessões ainda válidas; configuração do JWT pode divergir do prazo persistido.

**Ações recomendadas:**

- armazenar somente o hash do refresh token;
- rotacionar o token a cada refresh e invalidar o anterior;
- vincular sessões a um identificador e permitir revogação por dispositivo;
- calcular expiração com a mesma configuração usada na assinatura;
- revogar tokens de usuários desativados;
- remover tokens expirados periodicamente;
- considerar armazenamento seguro do token no dispositivo, especialmente em plataformas móveis.

**Critério de conclusão:** refresh tokens são rotativos, revogáveis e não ficam disponíveis em texto puro no banco.

---

## P2 — Organização e manutenção

### 9. Limpar o repositório e definir uma estrutura única

**Situação:** há cerca de 1.604 arquivos de `node_modules` versionados, um arquivo `app/lib.zip` e um repositório Git embutido em `backend/` sem configuração de submódulo visível. Também existem cópias semelhantes do backend e do Flutter.

**Risco:** alterações podem ser feitas na cópia errada; o repositório fica grande, confuso e difícil de implantar.

**Ações recomendadas:**

- decidir qual backend e qual aplicativo são oficiais;
- remover dependências e artefatos gerados do controle de versão;
- remover ou configurar corretamente o repositório embutido;
- ampliar o `.gitignore` para Node, Flutter, IDEs, builds, uploads locais, `.env` e arquivos temporários;
- adotar estrutura clara, por exemplo `backend/`, `app/`, `database/` e `docs/`;
- preservar dumps somente quando sanitizados e realmente necessários.

**Critério de conclusão:** há uma única fonte de verdade para cada componente e um clone novo pode ser preparado usando apenas os manifests e a documentação.

### 10. Configurar URLs e ambientes no Flutter

**Situação:** a URL da API está fixa como `http://localhost:3000/api`.

**Risco:** `localhost` aponta para o próprio dispositivo; a configuração não serve igualmente para web, emulador Android, aparelho físico e produção.

**Ações recomendadas:**

- usar `--dart-define` ou arquivos de configuração por ambiente;
- manter configurações separadas para desenvolvimento, homologação e produção;
- usar `10.0.2.2` para o emulador Android quando necessário;
- exigir HTTPS fora do desenvolvimento;
- documentar como informar o IP da máquina para aparelhos físicos;
- manter valores de produção fora do código quando forem sensíveis.

**Critério de conclusão:** cada plataforma aponta para a API correta sem edição manual do código-fonte.

### 11. Padronizar codificação, erros e qualidade estática

**Situação:** a saída de vários arquivos mostra caracteres acentuados corrompidos em alguns contextos, e `flutter analyze` ficou travado durante o diagnóstico sem produzir resultado.

**Ações recomendadas:**

- padronizar arquivos em UTF-8 e configurar editor/repositório;
- corrigir textos que estejam realmente gravados com mojibake;
- investigar o travamento do analisador, caches ou processos do Flutter;
- executar formatter e linter no CI;
- adicionar lint para JavaScript e padronização de estilo;
- reduzir comentários repetitivos e manter comentários voltados às decisões de negócio.

**Critério de conclusão:** análise estática e formatação terminam com sucesso de forma reproduzível.

---

## P2 — Testes, observabilidade e documentação

### 12. Criar uma suíte de testes automatizados

**Situação:** o backend não possui script de teste e o Flutter tem apenas um smoke test que monta o widget.

**Testes prioritários:**

- cadastro, login, refresh, logout e usuário desativado;
- autorização entre cliente, barbeiro e administrador;
- isolamento entre barbearias;
- cálculo de preço e duração no servidor;
- conflito e concorrência de agendamentos;
- cancelamento e conclusão por proprietário correto;
- horários de funcionamento e bloqueios;
- falha intermediária e rollback de transações;
- controllers/services do Flutter;
- fluxos principais de login e agendamento.

**Critério de conclusão:** testes rodam localmente e no CI, cobrindo regras críticas e impedindo regressões de segurança.

### 13. Criar integração contínua

**Ações recomendadas:**

- instalar dependências a partir dos arquivos de lock;
- executar testes e lint do Node;
- executar `flutter analyze`, testes e verificação de formatação;
- verificar dependências vulneráveis e segredos acidentalmente adicionados;
- impedir merge quando verificações obrigatórias falharem;
- gerar builds somente após as verificações.

**Critério de conclusão:** todo commit ou pull request recebe uma verificação automática reproduzível.

### 14. Melhorar documentação e operação

**Situação:** o README do aplicativo ainda contém o texto padrão criado pelo Flutter.

**Ações recomendadas:**

- criar README principal com arquitetura, requisitos e comandos;
- documentar variáveis de ambiente sem valores reais;
- documentar criação/migração do banco;
- incluir exemplos de execução para web, Android e backend;
- descrever papéis e regras de autorização;
- documentar endpoints com OpenAPI/Swagger;
- criar health checks e procedimento de backup/restauração;
- registrar decisões arquiteturais relevantes.

**Critério de conclusão:** uma pessoa nova consegue instalar, configurar, testar e executar o sistema apenas seguindo a documentação.

### 15. Melhorar observabilidade e privacidade

**Ações recomendadas:**

- usar logs estruturados com nível, correlação e contexto mínimo necessário;
- acompanhar erros, latência e disponibilidade;
- adicionar endpoints distintos de saúde e prontidão;
- evitar retorno ou registro excessivo de telefone, e-mail e outros dados pessoais;
- estabelecer retenção e exclusão de dados compatíveis com a LGPD;
- auditar operações administrativas sensíveis.

**Critério de conclusão:** falhas podem ser diagnosticadas sem expor segredos ou dados pessoais, e ações administrativas relevantes deixam trilha de auditoria.

---

## Backlog resumido

| Prioridade | Item | Resultado esperado |
|---|---|---|
| P0 | Segredos fora do Git e rotacionados | Credenciais antigas deixam de funcionar |
| P0 | Autorização por proprietário/barbearia | Sem acesso cruzado a dados ou operações |
| P0 | Preço e duração calculados no servidor | Cliente não consegue manipular cobrança ou agenda |
| P1 | Reserva atômica | Sem agendamento duplo sob concorrência |
| P1 | Transações e validação | Dados consistentes e entradas confiáveis |
| P1 | CORS, rate limit e headers | Menor superfície de abuso da API |
| P1 | Refresh token seguro | Sessões rotativas e revogáveis |
| P2 | Limpeza da estrutura | Uma única fonte de verdade e Git leve |
| P2 | Configuração por ambiente | App funciona em todas as plataformas |
| P2 | Testes e CI | Regressões detectadas automaticamente |
| P2 | Documentação e observabilidade | Operação e manutenção previsíveis |

## Observações finais

Este plano registra o estado observado em 15 de agosto de 2026. Antes de cada mudança, deve-se preservar o trabalho local existente e criar um backup do banco. Alterações de segurança devem começar pela rotação dos segredos, pois apenas retirar o `.env` do commit atual não remove valores já presentes no histórico.

