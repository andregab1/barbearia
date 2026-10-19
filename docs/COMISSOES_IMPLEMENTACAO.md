# GetCutt — matriz de implementação de comissões

Fonte de requisitos: `PROMPT_CODEX_COMISSOES_GETCUTT_COMPLETO.md` (26/09/2026).

| Requisito | Reuso atual | Implementação nesta etapa | Prova |
|---|---|---|---|
| Regras versionadas e snapshot | `commission_rules`, `commission_entitlements.snapshot_json` | Draft persistente publica combinações de escopo em uma transação; vigência e status são derivados pela data atual | testes do calculador, publicação e reconciliação |
| Base, desconto e memória de cálculo | `commission-calculator.js`, relatório | Extrato mostra bruto, desconto, base, regra, exceção e total; lançamento possui endpoint de detalhe | build + endpoints de statement/entries/:id |
| Liberação parcial/idempotente | `commission_entries`, `reconcileEntitlement` | Liberação por delta, sem duplicação | testes de comissão e pagamentos |
| Estorno de recebimento | fluxo financeiro operacional | Recalcula comissão e cria reversão no ledger | endpoint de refund |
| Adiantamentos | `commission_advances` e alocações | Saída financeira única e compensação no fechamento | fluxo de advance/settlement |
| Fechamento e pagamento parcial | `commission_settlements` | Fechamento separado da saída e pagamento idempotente | npm test + validação HTTP |
| Ajuste manual | `commission_entries.kind=manual_adjustment` | Motivo obrigatório, actor, idempotência e histórico preservado | rota de adjustment |
| Reversão autorizada | financeiro + auditoria | Reverte pagamento/adiantamento sem apagar histórico; adiantamento já aplicado é protegido | rotas de reversal |
| Visão por profissional | read-model de comissões | Overview inclui `professionals` com saldo disponível e pendências | endpoint overview |
| Extrato acumulado | ledger de commission entries | Inclui saldo inicial, pagamentos, compensações e saldo por linha | endpoint statement |
| Permissões/tenant | `tenantContext` + capabilities | Todas as mutações validam tenant e capability no backend | testes de capability |

## Limitações explícitas do schema atual

- Não há domínio separado de produtos/vendas, pacotes ou participação de múltiplos profissionais; não são simulados como se existissem.
- O fluxo atual de regras possui draft persistente e wizard com seleção real de profissionais/serviços; metas/faixas ainda são configuração armazenada e não apuração persistida.
- Exportação assíncrona, anexos privados, paginação por cursor e telas dedicadas de operação ainda dependem de modelagem adicional.
- Reversão de adiantamento já aplicado é recusada com conflito para não criar crédito incorreto; deve ser complementada com lançamento compensatório em uma próxima migration.

## Decisões

- Não foi criado um segundo motor de cálculo: o cálculo autoritativo continua em `src/services/commission-calculator.js`.
- Exceções do draft são aplicadas pelo mesmo resolvedor usado no simulador e na reconciliação, sem somar a regra padrão.
- Seleções específicas são expandidas em regras versionadas por combinação, com validação de referências, conflito de vigência e publicação atômica.
- Pagamento e adiantamento continuam sendo registros externos documentados e geram uma única saída financeira interna.
- Correções são append-only; nenhum lançamento original é apagado ou editado.
- Produtos estão explicitamente bloqueados no wizard enquanto o schema não possuir venda, item vendido e vendedor; não há comissão fictícia nem atribuição arbitrária.
