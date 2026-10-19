# Assistente de agendamento

## Ativação

Configure `OPENAI_API_KEY` e `OPENAI_MODEL` no ambiente do backend e execute
`node scripts/migrate.js` antes de disponibilizar a nova versão.
A migração 011 adiciona somente o registro técnico de confirmações; não salva conversas.

## Contrato

`POST /api/assistente/conversar`: cliente autenticado, `message`, `barbearia_id`,
`history` limitado às últimas dez mensagens. Retorna `collecting`, `alternatives`
ou `proposal`. Propostas assinadas expiram em dez minutos.

`POST /api/assistente/confirmar`: recebe `proposal_token`. A transação verifica
preço e duração por serviço, disponibilidade e o registro de confirmação.
Repetições devolvem o mesmo ID. Mudanças de preço/duração devolvem nova proposta;
conflitos devolvem alternativas. A interface deve exigir outro clique para a nova proposta.

Valores DATETIME da agenda representam o horário local de São Paulo (UTC−03).
Conversas não são gravadas no banco. A API de IA usa `store: false` e prazo de
25 segundos; o aplicativo espera até 35 segundos na conversa.

## Verificação e reversão

Execute `node --test`, `flutter test` e `flutter build web --release --no-pub`.
O teste real da OpenAI exige chave e créditos. Testes automatizados usam respostas
simuladas e não comprovam qualidade linguística do modelo real.

Para reverter a aplicação, retorne ao código anterior e mantenha a tabela de
confirmações. Não exclua registros de agendamentos ou financeiros durante rollback.
