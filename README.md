# GetCutt

Sistema de gestão de barbearias com API Node.js/Express, MySQL e aplicativo Flutter para Web e dispositivos móveis.

## Requisitos

- Node.js 20 ou superior
- MySQL 8
- Flutter estável com Dart 3

## Configuração local

1. Copie `.env.example` para `.env` e preencha banco e segredos.
2. Instale a API com `npm ci`.
3. Crie o banco e execute `npm run migrate`.
4. Inicie a API com `npm start`.
5. Em outro terminal, execute `cd app`, `flutter pub get` e `flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000/api`.

Para Android Emulator use `http://10.0.2.2:3000/api`. Em aparelho físico, use o IP local da máquina. Produção deve usar HTTPS.

## Verificações

- Backend: `npm run check` e `npm test`
- Flutter: `flutter analyze`, `flutter test` e `flutter build web --release`

## Migrações

Os arquivos em `migrations/` são aplicados em ordem e registrados em `schema_migrations`. Nunca altere uma migração aplicada; adicione uma nova.

O esquema consolidado, o seed local, as consultas de diagnóstico e as rotinas de
manutenção estão documentados em [`database/README.md`](database/README.md). Uma
visão por domínio e o diagrama de relacionamentos ficam em
[`docs/database-model.md`](docs/database-model.md).

## Perfis e acesso

- Cliente: gerencia apenas o próprio perfil e agendamentos.
- Profissional: opera somente sua agenda, horários e atendimentos.
- Administrador: gerencia apenas a barbearia à qual está vinculado.

## Onboarding SaaS

- `POST /api/auth/register-owner`: cria proprietário, barbearia, membership e assinatura trial em uma transação.
- `POST /api/invitations/:barbearia_id`: cria convite de equipe com validade de sete dias.
- `POST /api/invitations/accept`: aceita convite sem expor a senha ao administrador.
- `POST /api/billing/:barbearia_id/subscriptions`: inicia assinatura mensal no Mercado Pago.
- `POST /api/webhooks/mercado-pago`: recebe eventos assinados e idempotentes.
- `GET /api/finance/:barbearia_id/summary`: retorna o resumo financeiro por período.

As integrações financeiras exigem `MERCADO_PAGO_ACCESS_TOKEN`, `MERCADO_PAGO_WEBHOOK_SECRET` e `APP_PUBLIC_URL`. Use credenciais sandbox durante o desenvolvimento. O CI cria um MySQL vazio e executa todas as migrações para verificar que o schema é reproduzível.

Segredos não devem ser commitados. Rotacione imediatamente qualquer credencial que tenha aparecido no histórico do Git.
