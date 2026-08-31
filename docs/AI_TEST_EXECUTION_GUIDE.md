# Plano de testes para agente de IA — GetCutt

Este catálogo contém **630 casos executáveis**, derivados diretamente das rotas, controladores, telas Flutter, migrações e regras de acesso do projeto. Os **54 primeiros casos** têm `perspective: E2E_REAL` e devem ser executados navegando e operando o produto como um QA. Os demais aprofundam validação, segurança, concorrência e resiliência.

## Arquivos

- `AI_TEST_CATALOG.json`: fonte estruturada recomendada para agentes de teste.
- `AI_TEST_CATALOG.csv`: versão para planilhas e importação em ferramentas de QA.
- `scripts/generate-ai-test-catalog.js`: gerador determinístico do catálogo.

## Ordem de execução

1. Execute primeiro todos os casos `E2E_REAL`, na ordem do catálogo.
2. Execute depois os demais P0, seguidos por P1 e P2.
3. Um teste funcional só passa se a ação foi realmente realizada no sistema; inspecionar código não conta como execução.
4. Quando o caso atravessar módulos, confira a mesma informação na tela do cliente, do barbeiro e do admin.

## Protocolo obrigatório para a IA executora

1. Use apenas ambiente de teste e credenciais sandbox; nunca efetue cobrança real.
2. Crie dois tenants isolados (A e B) e usuários cliente, barbeiro e admin em ambos.
3. Interaja pela interface Flutter. Use API e banco para preparar dados ou confirmar efeitos, nunca para substituir a jornada de UI descrita.
4. Antes de cada caso, registre build/commit, ambiente, navegador/dispositivo, data/hora e dados preparados.
5. Depois de cada passo relevante, capture evidência. Ao final, registre status `passed`, `failed`, `blocked` ou `skipped`, resposta HTTP, request ID e defeito relacionado.
6. Nunca marque como aprovado sem comparar interface, resposta da API e persistência quando o caso solicitar isso.
7. Faça o cleanup indicado. Se falhar, marque o ambiente como contaminado e não reutilize o mesmo dado em casos de concorrência.
8. Mascare senhas, JWTs, refresh tokens, tokens de convite, segredos de webhook e dados pessoais nas evidências.
9. Em caso de divergência entre UI e API, abra um defeito separado e associe todos os casos afetados.
10. Para casos parcialmente automatizáveis, automatize API/estado e mantenha inspeção visual para UX e acessibilidade.

## Formato do relatório de execução

`caseId, status, startedAt, finishedAt, environment, actor, requestIds, evidence, actualResult, defectId, cleanupStatus`.

## Critério de saída

- 100% dos E2E_REAL e P0 executados e aprovados.
- Nenhum vazamento entre tenants, bypass de autenticação/autorização, duplicidade financeira ou conflito de agenda aberto.
- P1 com pelo menos 95% de aprovação e riscos restantes explicitamente aceitos.
- P2 executados nos viewports 390×844, 768×1024 e 1440×900.

## Cobertura técnica complementar

| Código | Módulo | Capacidade | Casos |
|---|---|---|---:|
| ENV | infra | Disponibilidade da API | 12 |
| LAND | frontend | Landing page e navegação | 12 |
| REGC | auth | Cadastro de cliente | 12 |
| REGO | auth | Onboarding de proprietário | 12 |
| LOGIN | auth | Login por e-mail ou telefone | 12 |
| TOKEN | auth | Renovação de sessão | 12 |
| LOGOUT | auth | Encerramento de sessão | 12 |
| PROFILE | usuarios | Consulta e edição de perfil | 12 |
| PASS | usuarios | Alteração de senha | 12 |
| SHOPPUB | barbearias | Catálogo público de barbearias | 12 |
| SHOP | barbearias | Gestão da barbearia | 12 |
| BRAND | barbearias | Personalização e logo | 12 |
| STAFFPUB | colaboradores | Catálogo público de profissionais | 12 |
| STAFF | colaboradores | Gestão de colaboradores | 12 |
| STAFFMAP | colaboradores | Vínculo usuário-profissional | 12 |
| INVITE | invitations | Convites de equipe | 12 |
| INVACC | invitations | Aceite de convite | 12 |
| SERVPUB | servicos | Catálogo público de serviços | 12 |
| SERV | servicos | Gestão de serviços | 12 |
| SCHEDCFG | horarios | Configuração semanal de horários | 12 |
| SLOTS | agenda | Horários disponíveis | 12 |
| BOOK | agendamentos | Criação de agendamento | 12 |
| MYBOOK | agendamentos | Meus agendamentos | 12 |
| PROBOOK | agendamentos | Agenda do profissional | 12 |
| CANCEL | agendamentos | Cancelamento de agendamento | 12 |
| COMPLETE | agendamentos | Conclusão de atendimento | 12 |
| BLOCK | agendamentos | Bloqueio simples de agenda | 12 |
| BLOCKPRE | agendamentos | Prévia de bloqueio | 12 |
| BLOCKREC | agendamentos | Bloqueio recorrente | 12 |
| BLOCKLIST | agendamentos | Consulta e remoção de bloqueios | 12 |
| DASH | agenda | Dashboard profissional | 12 |
| HISTORY | agenda | Histórico do cliente | 12 |
| CONTACTS | agendamentos | Contatos e clientes ativos | 12 |
| NOTIFY | notificacoes | Central de notificações | 12 |
| DISPATCH | notificacoes | Disparo de notificações | 12 |
| REPDAY | relatorios | Relatório diário | 12 |
| REPMONTH | relatorios | Relatório mensal | 12 |
| REPPER | relatorios | Relatório por período | 12 |
| FINSUM | finance | Resumo financeiro | 12 |
| FINENT | finance | Extrato financeiro | 12 |
| FINEXP | finance | Cadastro de despesa | 12 |
| BILL | billing | Assinatura Mercado Pago | 12 |
| WEBHOOK | webhooks | Webhook Mercado Pago | 12 |
| TENANT | security | Isolamento multi-tenant | 12 |
| SEC | security | Segurança HTTP e rate limit | 12 |
| RESP | frontend | Responsividade Flutter Web | 12 |
| A11Y | frontend | Acessibilidade e teclado | 12 |
| RESILIENCE | frontend | Resiliência e estados da UI | 12 |

Jornadas funcionais concretas: **54**. Casos totais: **630**.
