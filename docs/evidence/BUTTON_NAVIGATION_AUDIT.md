# Auditoria E2E dos botões de navegação por perfil

## Escopo e ambiente

- Data: 2026-08-18
- Plataforma: Flutter Web em Chrome 151, viewport 1440x900
- API: servidor local em porta efêmera
- Banco: `barbearia_flutter_e2e_test`, criado e removido pelo executor
- Comando: `node scripts/run-flutter-catalog-e2e.js --button-audit`
- Controles cobertos: navegação principal visível após login; ações CRUD internas ainda não fazem parte desta rodada

## Resultado reproduzido

| Perfil | Controles exercitados | Resultado |
|---|---|---|
| Administrador | Serviços, Equipe, Financeiro, Visual, Perfil | Todos abriram o destino esperado. O fluxo revelou posteriormente uma exceção assíncrona ao desmontar `HorariosScreen`. |
| Barbeiro | Bloquear, Horários, Contatos, Perfil | Os destinos foram acionados, porém `Bloquear` produz exceções Flutter e o perfil foi reprovado. |
| Cliente | Agenda, Histórico, Perfil, Início | Todos abriram o destino esperado sem exceção capturada nesta rodada. |

## DEF-UI-002 — exceção ao abrir Bloquear horário

- Severidade: média
- Prioridade: alta
- Sintoma: ao acionar `Bloquear`, a tela abre, mas o framework registra duas exceções: `ListTile background color or ink splashes may be invisible`.
- Esperado: abrir a tela sem exceção, com feedback visual de clique/seleção visível.
- Causa confirmada por rastreamento estático: `SwitchListTile` está diretamente dentro de um `Container`/`DecoratedBox` colorido, sem um ancestral `Material` próprio.
- Local: `app/lib/features/barbeiro/screens/bloquear_horario_screen.dart`, região das linhas 379–406.
- Impacto: o controle pode parecer não responder porque o splash/estado visual fica oculto; em testes de integração a asserção reprova a tela.
- Recomendação: envolver o conteúdo em `Material` com a decoração apropriada ou remover a cor intermediária; adicionar widget test que toque no switch e valide estado e ausência de exceção.

## DEF-UI-003 — atualização assíncrona após descarte em Horários

- Severidade: alta
- Prioridade: alta
- Sintoma: após navegar para `Horários` e sair rapidamente, uma resposta de API chama `setState()` em `_HorariosScreenState` já descartado.
- Esperado: respostas tardias serem ignoradas quando o widget não está mais montado.
- Evidência: `setState() called after dispose()` com stack em `horarios_screen.dart:99`, originado após `ApiService.get('/horarios/$colaboradorId')`.
- Causa confirmada: `_carregarHorarios` aguarda a API e executa `setState` no laço sem verificar `mounted`; outros `setState` assíncronos próximos também devem ser auditados.
- Impacto: exceção de ciclo de vida, possível instabilidade/memory leak e percepção de botões quebrados em navegação rápida.
- Recomendação: validar `mounted` após cada `await` e antes de atualizar estado; idealmente cancelar/invalidar requisições obsoletas; cobrir navegação rápida com teste de regressão.

## Observação sobre o teste do cliente

Na primeira execução, o oráculo aguardava o texto antigo `Escolha onde deseja agendar`. A tela atual exibe `Agendar`; o teste foi corrigido e repetido. Essa primeira falha foi de automação, não do produto, e não foi contabilizada como defeito.

## Limitação atual

Esta evidência não afirma que todos os botões do sistema foram validados. Ela cobre 13 destinos de navegação principal. Botões de criar, editar, excluir, salvar, concluir, cancelar, filtros, calendários, contatos/WhatsApp, logout e o fluxo completo de agendamento ainda precisam de casos funcionais próprios, com verificação de API e persistência.
