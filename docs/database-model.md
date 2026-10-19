# Modelo do banco de dados

O modelo preserva as tabelas e os contratos SQL consumidos pela API. Para ficar
mais simples de entender, ele esta dividido por dominio.

| Dominio | Tabelas principais | Responsabilidade |
|---|---|---|
| Identidade e tenant | `usuarios`, `barbearias`, `memberships`, `invitations`, `colaboradores` | Pessoas, acesso e equipe por barbearia |
| Agenda | `servicos`, `horarios_funcionamento`, `horarios_bloqueados`, `agendamentos`, `agendamento_servicos` | Catalogo, disponibilidade e reservas |
| Comunicacao | `notificacoes`, `notification_preferences`, `notification_deliveries`, `device_tokens` | Mensagens e canais de entrega |
| Autenticacao | `refresh_tokens`, `otp_challenges` | Sessoes e desafios de acesso |
| Financeiro | `financial_accounts`, `financial_categories`, `financial_transactions`, `payments`, `payment_allocations`, `refunds`, `cash_entries` | Previsao, competencia, recebiveis, pagamentos e caixa |
| Fiscal | `fiscal_settings`, `fiscal_documents` | Configuracao por tenant e snapshots imutaveis de emissao |
| Contabilidade | `accounting_accounts`, `accounting_entries`, `accounting_entry_lines` | Plano flexivel e partidas dobradas gerenciais |
| Integracao interna | `outbox_events` | Eventos transacionais para processamento posterior confiavel |
| Operacao | `webhook_events`, `audit_logs`, `schema_migrations` | Integracoes, auditoria e versao |

## Relacionamentos centrais

```mermaid
erDiagram
  USUARIOS ||--o{ BARBEARIAS : administra
  USUARIOS ||--o{ MEMBERSHIPS : possui
  BARBEARIAS ||--o{ MEMBERSHIPS : autoriza
  USUARIOS ||--o{ COLABORADORES : representa
  BARBEARIAS ||--o{ COLABORADORES : contrata
  BARBEARIAS ||--o{ SERVICOS : oferece
  COLABORADORES ||--o{ HORARIOS_FUNCIONAMENTO : trabalha
  COLABORADORES ||--o{ HORARIOS_BLOQUEADOS : bloqueia
  USUARIOS ||--o{ AGENDAMENTOS : reserva
  COLABORADORES ||--o{ AGENDAMENTOS : atende
  SERVICOS ||--o{ AGENDAMENTOS : servico_principal
  AGENDAMENTOS ||--o{ AGENDAMENTO_SERVICOS : contem
  SERVICOS ||--o{ AGENDAMENTO_SERVICOS : compoe
  AGENDAMENTOS ||--o{ NOTIFICACOES : gera
  BARBEARIAS ||--o{ PAYMENTS : recebe
  AGENDAMENTOS ||--o{ PAYMENTS : liquida
  PAYMENTS ||--o{ REFUNDS : reembolsa
  AGENDAMENTOS ||--o| CASH_ENTRIES : contabiliza
  AGENDAMENTOS ||--o{ FINANCIAL_TRANSACTIONS : origina
  FINANCIAL_TRANSACTIONS ||--o{ PAYMENT_ALLOCATIONS : liquida
  PAYMENTS ||--o{ PAYMENT_ALLOCATIONS : distribui
  FINANCIAL_TRANSACTIONS ||--o{ ACCOUNTING_ENTRIES : classifica
  ACCOUNTING_ENTRIES ||--|{ ACCOUNTING_ENTRY_LINES : detalha
  AGENDAMENTOS ||--o| FISCAL_DOCUMENTS : documenta
  AGENDAMENTOS ||--o{ COMMISSIONS : remunera
```

## Decisoes de compatibilidade

- `usuarios.role` continua existindo para os fluxos legados; `memberships.papel`
  expressa a permissao dentro de cada barbearia no modelo SaaS.
- `barbearias.admin_id` continua identificando o administrador original;
  `memberships` permite proprietarios e equipe com papeis mais precisos.
- `agendamentos.servico_id` continua sendo o servico principal;
  `agendamento_servicos` registra os itens e seus valores historicos.
- Valores e duracoes cobrados ficam copiados no agendamento para que alteracoes
  futuras no catalogo nao modifiquem o historico.
- `cash_entries` permanece por compatibilidade. A fonte de verdade dos novos
  fluxos e `financial_transactions`; caixa nasce somente de pagamento confirmado.
- Pagamento parcial possui estrutura em `payment_allocations`, mas a API inicial
  exige liquidacao integral. Isso evita prometer uma operacao parcial incompleta.
- Fiscal nunca assume autorizacao: documento inicia `pending` e somente um adapter
  real de provedor pode confirmar `authorized`.
