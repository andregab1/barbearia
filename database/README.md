# Banco de dados

Esta pasta separa responsabilidades que antes estavam misturadas em um unico
arquivo SQL.

## Fonte da verdade

- `../migrations/`: historico incremental usado pela aplicacao. Nao altere uma
  migracao que ja foi aplicada; crie a proxima migracao numerada.
- `schema.sql`: fotografia consolidada e legivel do estado apos a migracao 007.
  Serve para modelagem e para provisionar apenas bancos vazios.
- `seeds/development.sql`: usuarios, barbearia, servicos e horarios locais. Pode
  ser executado novamente sem duplicar os registros que ele gerencia.
- `maintenance/diagnostics.sql`: consultas de verificacao, sem escrita.
- `maintenance/cleanup_midnight_blocks.sql`: limpeza manual protegida por
  pre-visualizacao e transacao.

O dump `../barbearia.sql` continua separado porque representa dados de uma
instancia em um momento especifico; ele nao deve ser usado como modelo.

## Fluxo recomendado

Banco novo usado pela aplicacao:

1. Crie `barbearia_db` com `utf8mb4_unicode_ci`.
2. Configure `.env`.
3. Execute `npm run migrate`.
4. Opcionalmente rode `seeds/development.sql` somente no ambiente local.

Para estudar o modelo ou criar uma instancia vazia diretamente no Workbench,
execute `schema.sql`. Ele registra as migracoes 000-007 como aplicadas, portanto
as proximas migracoes continuam funcionando com `npm run migrate`.

Use `npm run db:validate-schema` para criar bases temporarias isoladas, comparar
o snapshot com todas as migracoes, aplicar o seed duas vezes e remover as bases
ao final.

## Regras de manutencao

- Estrutura fica em migracoes; dados de exemplo ficam em seeds.
- `SELECT` de diagnostico e comandos de limpeza ficam em `maintenance/`.
- Nunca misture `TRUNCATE`, `DELETE` ou senhas reais ao script de criacao.
- Relacionamentos usam chaves estrangeiras; IDs fixos nao sao usados nos seeds.
- `agendamentos.servico_id` permanece para compatibilidade e
  `agendamento_servicos` suporta um ou varios servicos no mesmo atendimento.
