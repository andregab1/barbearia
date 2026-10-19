# Passagem de contexto — Assistente de agendamento com Gemini

Atualizado em 15/09/2026.

## Objetivo entregue

O sistema de barbearia agora possui, para o cliente, uma aba **Assistente**. Nela, o cliente pode escrever pedidos como:

> "Agenda corte + barba e limpeza de pele para mim na terça às 15h com o André"

O backend interpreta a mensagem com IA, confere o catálogo e a disponibilidade real e apresenta uma proposta. O agendamento só é criado depois da confirmação explícita do cliente.

## Estado atual

- Provedor de IA: **Google Gemini API**.
- Modelo configurado: `gemini-3.6-flash`.
- SDK: `@google/genai`.
- A chave `GEMINI_API_KEY` foi salva no `.env` local e foi validada sem expor seu valor.
- A resposta simples e a resposta JSON estruturada foram testadas diretamente contra a API Gemini com sucesso.
- Backend disponível localmente em `http://127.0.0.1:3000` quando iniciado com `node server.js`.
- Testes do backend: **26 passando**.

> Importante: a chave não está neste documento e não deve ser enviada por chat, commit ou incluída no Flutter.

## Como iniciar em outro computador

### 1. Pré-requisitos

- Node.js 20 ou superior.
- MySQL com o banco configurado para o projeto.
- Flutter, caso seja necessário recompilar o frontend web.

### 2. Instalar dependências do backend

No diretório `C:\barbearia` (ou no diretório equivalente no outro computador):

```powershell
npm.cmd install
```

### 3. Criar o `.env`

Copie `.env.example` para `.env` e preencha banco de dados, JWTs e a chave do Gemini.

Variáveis relevantes do assistente:

```env
GEMINI_API_KEY=sua_chave_do_google_ai_studio
GEMINI_MODEL=gemini-3.6-flash
```

A chave pode ser criada no Google AI Studio:

`https://aistudio.google.com/app/apikey`

### 4. Aplicar migrations

```powershell
node scripts/migrate.js
```

A migration necessária para a confirmação idempotente pelo assistente é:

```text
migrations/011_assistant_confirmations.sql
```

### 5. Compilar o Flutter web, se necessário

```powershell
Set-Location app
flutter pub get
flutter build web --release --no-pub
Set-Location ..
```

### 6. Iniciar o sistema

```powershell
node server.js
```

Abra:

```text
http://127.0.0.1:3000
```

Teste de saúde do backend:

```powershell
Invoke-WebRequest -UseBasicParsing http://127.0.0.1:3000/health
```

Resposta esperada:

```json
{"status":"ok"}
```

## Arquitetura do assistente

```text
Cliente (Flutter)
  -> POST /api/assistente/conversar
  -> Gemini interpreta a intenção em JSON
  -> Backend valida serviços, profissional, data e hora
  -> Serviço de disponibilidade consulta agenda real
  -> proposta assinada é enviada ao cliente
  -> POST /api/assistente/confirmar
  -> agendamento é criado em transação
```

O modelo não cria reservas diretamente. Ele apenas devolve dados estruturados. O backend continua sendo a fonte de verdade para catálogo, preço, duração, horários e criação do agendamento.

## Endpoints

Ambos exigem autenticação do cliente.

### Conversar

```text
POST /api/assistente/conversar
```

Entrada principal:

```json
{
  "message": "Corte e barba na terça às 15h com André",
  "barbearia_id": 1,
  "history": []
}
```

Saídas possíveis:

- `collecting`: ainda falta alguma informação.
- `alternatives`: o horário não está disponível e o servidor oferece opções reais.
- `proposal`: existe uma proposta pronta para confirmação.

### Confirmar proposta

```text
POST /api/assistente/confirmar
```

Entrada:

```json
{
  "proposal_token": "token-assinado-recebido-no-passo-anterior"
}
```

O token expira em 10 minutos. A confirmação é idempotente: repetir a mesma confirmação retorna o agendamento original, sem criar duplicidade.

## Arquivos importantes

| Arquivo | Responsabilidade |
| --- | --- |
| `src/controllers/assistente.controller.js` | Integra Gemini, interpreta a mensagem, valida a proposta e confirma o agendamento. |
| `src/routes/assistente.routes.js` | Declara as rotas do assistente e suas proteções. |
| `src/services/appointment-availability.service.js` | Calcula horários disponíveis a partir de expediente, bloqueios e agenda existente. |
| `migrations/011_assistant_confirmations.sql` | Cria a tabela para confirmações idempotentes. |
| `app/lib/features/agendamento/screens/assistente_agendamento_screen.dart` | Tela de chat do cliente. |
| `app/lib/features/agendamento/screens/cliente_home_screen.dart` | Inclui a aba Assistente na área do cliente. |
| `app/lib/core/services/api_service.dart` | Suporte a timeout das requisições do chat. |
| `app.js` | Serve o build Flutter e registra as rotas da API. |
| `.env.example` | Modelo de configuração, sem segredos. |

## Migração OpenAI -> Gemini realizada

O sistema inicialmente usava OpenAI, mas a conta estava sem créditos de API. Foi trocado para Gemini.

Mudanças feitas:

- Dependência `openai` removida.
- Dependência `@google/genai` adicionada ao `package.json`.
- `OPENAI_API_KEY` e `OPENAI_MODEL` substituídos por `GEMINI_API_KEY` e `GEMINI_MODEL`.
- A integração usa `GoogleGenAI` e `models.generateContent`.
- O histórico converte o papel interno `assistant` para `model`, como esperado pelo Gemini.
- A resposta exige `application/json` com schema de serviço, profissional, data e hora.
- Erros HTTP 429/`RESOURCE_EXHAUSTED` são mostrados como limite de uso do Gemini.

O primeiro modelo testado, `gemini-2.5-flash`, retornou 404 para esta conta pois não está disponível para novos usuários. Por isso, a configuração atual usa `gemini-3.6-flash`.

## Segurança e regras de negócio

- A chave Gemini fica apenas no backend, em `.env`.
- Nunca use a chave em arquivos Flutter, JavaScript do navegador, screenshots ou commits.
- O chat tem limite de tamanho da mensagem e do histórico.
- As rotas exigem usuário autenticado e possuem rate limit.
- Serviços e profissionais são aceitos somente se existirem e estiverem ativos no catálogo da barbearia.
- O backend verifica disponibilidade antes de emitir proposta e novamente ao confirmar.
- Preço e duração usados na confirmação são conferidos contra os valores atuais para evitar alterações silenciosas.
- O token da proposta é assinado com `JWT_SECRET` e válido por 10 minutos.

## Testes e validação

Rodar testes do backend:

```powershell
node --test
```

Resultado validado nesta passagem:

```text
26 testes, 26 passando, 0 falhas
```

Rodar teste do Flutter:

```powershell
Set-Location app
flutter test
```

Validação manual recomendada após abrir o sistema:

1. Fazer login como cliente.
2. Abrir a aba **Assistente**.
3. Enviar: `Quais horários você tem disponíveis?`
4. Enviar um pedido completo com serviço, dia, hora e profissional existentes.
5. Conferir se aparece proposta com preço e duração corretos.
6. Confirmar e verificar se o agendamento aparece na agenda/histórico.
7. Repetir a confirmação não deve criar dois agendamentos.

## Histórico de problemas já resolvidos

### Tela branca

O Flutter chegou a ser servido por um servidor estático incorreto, que retornava `index.html` para arquivos JavaScript. A correção foi servir o build Flutter pelo Express em `app.js`. A página deve ser acessada por `http://127.0.0.1:3000`, não pelo servidor estático antigo.

### Tesoura 3D aparecendo no login

O efeito 3D foi removido da tela de login. Ele deve ser inicializado somente na tela inicial/landing page. Também foi protegida a limpeza de timers do helper web para evitar uma inicialização tardia.

### Erro “O assistente ainda não foi configurado”

Esse erro significava que a variável de ambiente da IA não estava disponível no processo do backend. Agora o backend usa `GEMINI_API_KEY`. Sempre reinicie `node server.js` depois de editar `.env`.

### Erro de modelo Gemini

Se aparecer erro 404 sobre o modelo, confira no `.env`:

```env
GEMINI_MODEL=gemini-3.6-flash
```

## Observações para continuidade

- O repositório já possuía várias alterações não relacionadas antes deste trabalho. Não use `git reset --hard` nem descarte mudanças sem revisar.
- O `npm install` informou vulnerabilidades de dependências. Não foi executado `npm audit fix` para evitar atualizações amplas sem revisão.
- O Gemini tem camada gratuita, porém limitada por cotas. Quando a cota acabar, o backend devolve uma mensagem orientando a tentar novamente mais tarde.
- Caso seja necessário usar produção, configure variáveis de ambiente diretamente no servidor/serviço de hospedagem, em vez de copiar o `.env` para o repositório.

