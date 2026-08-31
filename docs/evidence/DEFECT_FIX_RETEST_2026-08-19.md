# Reteste das correções DEF-AUTH-001, DEF-UI-002 e DEF-UI-003

- Data: 2026-08-19
- Escopo: Flutter Web/cliente HTTP, tela Bloquear horário e ciclo de vida da tela Horários.
- Ambiente dinâmico local: aplicativo Flutter; tentativa E2E com banco `barbearia_flutter_e2e_test` descartável.
- Resultado geral dos defeitos retestados: `fully_validated` no escopo dos casos direcionados.

## DEF-AUTH-001

- Correção: respostas 401 de chamadas públicas (`auth: false`) não acionam refresh e preservam a mensagem do backend. Chamadas autenticadas continuam com refresh automático.
- Evidência estática: `AuthService.login` usa `ApiService.post(..., auth: false)` e `ApiService` agora encaminha o 401 público para o processador normal.
- Reteste dinâmico QA-E2E-050: `passed` no Chrome 151, código 0, preservando `Credenciais inválidas.` e mantendo o formulário utilizável.

## DEF-UI-002

- Correção: o `SwitchListTile` de repetição passou a ter um ancestral `Material` próprio, com `shape`, cor e clipping, mantendo splash e estados visuais sobre a mesma superfície.
- Reteste dinâmico da auditoria de botões: `passed`; `Bloquear horário` abriu sem a exceção anterior de `ListTile`/`DecoratedBox`.

## DEF-UI-003

- Correção: verificações de `mounted` foram adicionadas após operações assíncronas; respostas de horários recebem um identificador incremental e respostas obsoletas são ignoradas. Sair da seleção ou descartar a tela invalida a requisição ativa. A resposta atualiza os sete dias em um único `setState`.
- Reteste estático: `passed` pelo analisador Dart, sem erros ou warnings novos.
- Reteste dinâmico de navegação rápida: `passed`; não houve `setState after dispose` em `HorariosScreen`.

## DEF-UI-004

- Correção: `PerfilScreen._carregarDados` retorna após cada espera assíncrona quando o widget não está mais montado, antes de acessar qualquer `TextEditingController`.
- Reteste dinâmico: `passed`; a matriz navegou para Perfil nos três papéis e encerrou sem `TextEditingController was used after being disposed`.

## DEF-UI-005

- Descoberta durante o reteste: `BloquearHorarioScreen` atualizava estado após respostas tardias da API.
- Correção: proteções de `mounted` foram adicionadas após operações assíncronas e a carga de bloqueios passou a fazer uma atualização única do estado.
- Reteste dinâmico: `passed`; o fluxo do barbeiro navegou por Bloquear, Horários, Contatos e Perfil sem exceções tardias.

## Comandos executados

- `flutter analyze --no-pub --no-fatal-infos`: `passed`, código 0, 28 avisos informativos preexistentes.
- `flutter test`: `passed`, 1/1.
- `dart analyze`: `passed`, código 0, os mesmos 28 avisos informativos.
- `node scripts/run-flutter-catalog-e2e.js --login-only`: `passed`, 2/2 eventos do runner, código 0.
- `node scripts/run-flutter-catalog-e2e.js --button-audit`: `passed`, 4/4 eventos do runner, código 0, sem `EXCEPTION`, `[E]` ou `Failure Details`.

## Pendente para homologação

Os defeitos direcionados estão aprovados. A homologação integral ainda depende dos botões internos críticos, persistência, permissões, isolamento entre tenants e cenários de falha descritos no catálogo.
