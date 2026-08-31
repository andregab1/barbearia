const fs = require('fs');
const path = require('path');

const capabilities = [
  ['ENV','Disponibilidade da API','infra','GET /health','visitante','consultar a saúde da API','a API responde 200 com status ok, sem detalhes sensíveis'],
  ['LAND','Landing page e navegação','frontend','/','visitante','navegar pela landing page, links e CTAs','conteúdo, navegação e modelo visual funcionam sem erros'],
  ['REGC','Cadastro de cliente','auth','POST /api/auth/cadastrar','visitante','cadastrar uma conta de cliente','a conta de cliente é criada uma única vez com dados normalizados'],
  ['REGO','Onboarding de proprietário','auth','POST /api/auth/register-owner','visitante','criar proprietário, barbearia e trial','usuário, tenant, membership e trial são criados atomicamente'],
  ['LOGIN','Login por e-mail ou telefone','auth','POST /api/auth/login','visitante','autenticar cada perfil','tokens e contexto do perfil correto são retornados'],
  ['TOKEN','Renovação de sessão','auth','POST /api/auth/refresh','usuário','renovar o access token','o refresh token é rotacionado e não pode ser reutilizado'],
  ['LOGOUT','Encerramento de sessão','auth','POST /api/auth/logout','usuário','encerrar a sessão','o refresh token é revogado e a sessão local é limpa'],
  ['PROFILE','Consulta e edição de perfil','usuarios','GET/PUT /api/usuarios/:id','usuário','consultar e alterar os próprios dados','somente dados autorizados são lidos e persistidos'],
  ['PASS','Alteração de senha','usuarios','PATCH /api/usuarios/me/senha','usuário','trocar a senha autenticada','a nova senha passa a valer e a antiga é invalidada'],
  ['SHOPPUB','Catálogo público de barbearias','barbearias','GET /api/barbearias','visitante','listar barbearias públicas','somente barbearias ativas e dados públicos são exibidos'],
  ['SHOP','Gestão da barbearia','barbearias','POST/GET/PUT /api/barbearias','admin','criar, consultar e editar a barbearia','alterações ficam restritas ao tenant administrado'],
  ['BRAND','Personalização e logo','barbearias','PATCH /api/barbearias/:id/personalizar','admin','alterar tema, informações e logo','tema e imagem válidos são salvos e refletidos no app'],
  ['STAFFPUB','Catálogo público de profissionais','colaboradores','GET /api/colaboradores/:barbearia_id','visitante','listar profissionais de uma barbearia','somente profissionais ativos do tenant são exibidos'],
  ['STAFF','Gestão de colaboradores','colaboradores','POST/PUT/PATCH/DELETE /api/colaboradores','admin','criar, editar, ativar e remover colaborador','equipe é atualizada sem escapar do tenant'],
  ['STAFFMAP','Vínculo usuário-profissional','colaboradores','GET /api/colaboradores/usuario/:usuario_id','usuário','resolver o colaborador do usuário','o vínculo correto e autorizado é retornado'],
  ['INVITE','Convites de equipe','invitations','GET/POST /api/invitations/:barbearia_id','admin','listar e emitir convite','convite único, com papel válido e expiração é criado'],
  ['INVACC','Aceite de convite','invitations','POST /api/invitations/accept','convidado','aceitar convite de equipe','membership e colaborador são criados sem duplicidade'],
  ['SERVPUB','Catálogo público de serviços','servicos','GET /api/servicos/:barbearia_id','visitante','listar serviços disponíveis','somente serviços ativos do tenant são exibidos'],
  ['SERV','Gestão de serviços','servicos','POST/PUT/DELETE /api/servicos','admin','criar, editar e desativar serviço','preço, duração e estado são persistidos no tenant correto'],
  ['SCHEDCFG','Configuração semanal de horários','horarios','GET/POST /api/horarios/:colaborador_id','admin ou barbeiro','consultar e salvar jornada semanal','intervalos válidos substituem a agenda do profissional atomicamente'],
  ['SLOTS','Horários disponíveis','agenda','GET /api/agenda/disponiveis/:colaborador_id','cliente','consultar horários disponíveis','slots respeitam jornada, duração, reservas e bloqueios'],
  ['BOOK','Criação de agendamento','agendamentos','POST /api/agendamentos','cliente','reservar serviço com profissional','uma reserva futura válida é criada sem conflito'],
  ['MYBOOK','Meus agendamentos','agendamentos','GET /api/agendamentos/meus','cliente','listar os próprios agendamentos','apenas reservas do cliente autenticado são retornadas'],
  ['PROBOOK','Agenda do profissional','agendamentos','GET /api/agendamentos/barbeiro/:colaborador_id','admin ou barbeiro','listar agenda profissional','somente agenda autorizada e filtros corretos são retornados'],
  ['CANCEL','Cancelamento de agendamento','agendamentos','PATCH /api/agendamentos/:id/cancelar','cliente, admin ou barbeiro','cancelar reserva permitida','status muda uma vez, respeitando antecedência e propriedade'],
  ['COMPLETE','Conclusão de atendimento','agendamentos','PATCH /api/agendamentos/:id/concluir','admin ou barbeiro','concluir atendimento confirmado','atendimento e lançamento financeiro são atualizados uma única vez'],
  ['BLOCK','Bloqueio simples de agenda','agendamentos','POST /api/agendamentos/bloquear','admin ou barbeiro','bloquear intervalo livre','o período fica indisponível sem sobrepor reserva ou bloqueio'],
  ['BLOCKPRE','Prévia de bloqueio','agendamentos','POST /api/agendamentos/bloquear/preview','admin ou barbeiro','simular bloqueio','conflitos são informados sem alterar dados'],
  ['BLOCKREC','Bloqueio recorrente','agendamentos','POST /api/agendamentos/bloquear/recorrente','admin ou barbeiro','criar bloqueios recorrentes','ocorrências válidas são criadas de modo consistente'],
  ['BLOCKLIST','Consulta e remoção de bloqueios','agendamentos','GET/DELETE /api/agendamentos/bloquear','admin ou barbeiro','listar e remover bloqueios','somente bloqueios autorizados são afetados'],
  ['DASH','Dashboard profissional','agenda','GET /api/agenda/dashboard/:colaborador_id','admin ou barbeiro','consultar indicadores e agenda do dia','dados agregados correspondem à agenda autorizada'],
  ['HISTORY','Histórico do cliente','agenda','GET /api/agenda/historico/:cliente_id','cliente','consultar histórico','somente o histórico autorizado é exibido em ordem correta'],
  ['CONTACTS','Contatos e clientes ativos','agendamentos','GET /api/agendamentos/clientes*','admin ou barbeiro','consultar clientes atendidos','dados mínimos e somente relações autorizadas são retornados'],
  ['NOTIFY','Central de notificações','notificacoes','GET /api/notificacoes','usuário','listar notificações','somente notificações do usuário são retornadas no estado correto'],
  ['DISPATCH','Disparo de notificações','notificacoes','POST /api/notificacoes/disparar','admin','processar notificações pendentes','entregas são registradas sem duplicidade e sem vazar segredo'],
  ['REPDAY','Relatório diário','relatorios','GET /api/relatorios/:barbearia_id/diario','admin','consultar faturamento diário','totais e itens refletem atendimentos do dia e tenant'],
  ['REPMONTH','Relatório mensal','relatorios','GET /api/relatorios/:barbearia_id/mensal','admin','consultar faturamento mensal','séries e totais consideram corretamente mês e status'],
  ['REPPER','Relatório por período','relatorios','GET /api/relatorios/:barbearia_id/periodo','admin','consultar intervalo de faturamento','limites de datas e somas estão corretos'],
  ['FINSUM','Resumo financeiro','finance','GET /api/finance/:barbearia_id/summary','admin','consultar receitas, despesas e saldo','resumo fecha com lançamentos do período e tenant'],
  ['FINENT','Extrato financeiro','finance','GET /api/finance/:barbearia_id/entries','admin','listar lançamentos financeiros','filtros, paginação e valores retornam dados consistentes'],
  ['FINEXP','Cadastro de despesa','finance','POST /api/finance/:barbearia_id/expenses','admin','registrar uma despesa','lançamento válido é persistido com autor e tenant'],
  ['BILL','Assinatura Mercado Pago','billing','POST /api/billing/:barbearia_id/subscriptions','admin','iniciar assinatura mensal','assinatura local e remota ficam correlacionadas com segurança'],
  ['WEBHOOK','Webhook Mercado Pago','webhooks','POST /api/webhooks/mercado-pago','provedor','processar evento assinado','assinatura é validada e evento repetido é idempotente'],
  ['TENANT','Isolamento multi-tenant','security','todas as rotas com barbearia_id','todos os perfis','tentar acessar recursos de outra barbearia','o acesso cruzado é negado sem revelar existência ou dados'],
  ['SEC','Segurança HTTP e rate limit','security','middlewares globais','visitante ou usuário','inspecionar headers e exceder limites','headers defensivos existem e abuso recebe 429'],
  ['RESP','Responsividade Flutter Web','frontend','todas as telas','todos os perfis','usar desktop, tablet e celular','layout permanece utilizável sem overflow ou conteúdo inacessível'],
  ['A11Y','Acessibilidade e teclado','frontend','todas as telas','todos os perfis','navegar por teclado e leitor de tela','foco, nomes, contraste e ordem semântica são adequados'],
  ['RESILIENCE','Resiliência e estados da UI','frontend','chamadas de API','todos os perfis','simular lentidão, timeout e erro','loading, vazio, retry e erro são claros e não duplicam ações']
];

const perspectives = [
  ['HAPPY','P0','funcional','Preparar dados válidos e sessão do perfil indicado.','Executar {action} pelo fluxo principal com dados válidos.','dados válidos e representativos','{expected}. Confirmar resposta, interface e banco.','Remover ou restaurar os dados criados.','sim'],
  ['REQUIRED','P0','validação','Manter a sessão válida e identificar campos obrigatórios.','Executar {action} omitindo, um por vez, cada campo obrigatório.','campo ausente, null, vazio e apenas espaços','A operação é recusada com 400/validação por campo; nenhuma escrita parcial ocorre.','Confirmar que não houve alteração persistida.','sim'],
  ['BOUNDARY','P1','limites','Identificar tamanhos, datas e valores aceitos pelo contrato.','Executar {action} no mínimo, máximo, imediatamente abaixo e imediatamente acima dos limites.','0, 1, máximo-1, máximo e máximo+1; datas limítrofes','Valores dentro do contrato são aceitos; fora dele são recusados de forma consistente, sem truncamento silencioso.','Restaurar valores padrão.','sim'],
  ['MALFORMED','P0','robustez','Usar ambiente isolado e preservar evidências da resposta.','Executar {action} com tipos errados, Unicode, caracteres de controle e payload malformado.','string no lugar de número, arrays/objetos, emoji, HTML e SQL textual','A entrada inválida é rejeitada com erro seguro; não há crash, injeção, XSS nem mensagem interna.','Excluir dados de teste eventualmente aceitos.','sim'],
  ['AUTHN','P0','autenticação','Separar chamadas sem token, token inválido, expirado e mal formatado.','Executar {action} em cada condição de autenticação inválida.','sem Authorization; Basic; Bearer vazio; JWT alterado/expirado','Rotas protegidas retornam 401 e não leem nem modificam recursos; rotas públicas mantêm o contrato público.','Invalidar tokens usados no teste.','sim'],
  ['AUTHZ','P0','autorização','Criar contas cliente, barbeiro e admin com dados equivalentes.','Executar {action} com cada perfil permitido e proibido.','cliente, barbeiro, admin e conta desativada','Somente papéis explicitamente autorizados executam a ação; demais recebem 403 sem efeito colateral.','Remover contas temporárias.','sim'],
  ['TENANT','P0','isolamento','Criar dois tenants A e B com recursos de IDs conhecidos.','Autenticado no tenant A, executar {action} apontando IDs e barbearia_id do tenant B.','IDs válidos de outro tenant, inexistentes e trocados','Nenhum dado do tenant B é exposto ou alterado; erro é consistente e auditável.','Remover tenants e recursos temporários.','sim'],
  ['CONCUR','P0','concorrência','Preparar duas sessões e sincronizar requisições simultâneas.','Disparar 2, 10 e 50 execuções concorrentes de {action} sobre o mesmo recurso.','requisições idênticas e conflitantes no mesmo milissegundo','Invariantes são preservadas: sem duplicação, double-spend, lost update ou estado impossível.','Reconciliar dados e limpar resultados.','sim'],
  ['RETRY','P1','idempotência','Capturar a mesma requisição e seu identificador quando existir.','Executar {action}, repetir imediatamente e repetir após timeout simulado.','mesmo payload, mesmo idempotency key/evento e chave diferente','Repetições não criam efeitos duplicados; conflito ou resultado anterior é retornado de forma determinística.','Remover registros únicos criados.','sim'],
  ['FAIL','P1','resiliência','Permitir simular banco/API externa indisponível ou timeout.','Interromper a dependência durante {action} e restaurá-la antes de tentar novamente.','timeout, conexão recusada, 500 externo e resposta incompleta','Falha é tratada sem segredo ou stack trace; transação faz rollback e retry posterior é seguro.','Restaurar dependência e confirmar consistência.','parcial'],
  ['PERSIST','P1','persistência','Registrar estado inicial no banco e na interface.','Executar {action}, atualizar a tela, relogar e reiniciar o serviço antes da conferência.','dados com timezone, acentos e valores monetários decimais','{expected}. O estado permanece consistente após reload/relogin e não perde precisão.','Restaurar snapshot inicial.','sim'],
  ['UXOBS','P2','UX, acessibilidade e observabilidade','Abrir ferramentas de rede/log e usar viewport 390x844 e teclado.','Executar {action} em tela estreita, usando somente teclado, e correlacionar request ID/logs.','loading lento, resposta vazia, sucesso e erro','Não há overflow nem ação duplicada; foco e mensagens são claros; logs permitem correlação sem PII ou segredo.','Limpar logs/dados de teste conforme política.','parcial']
];

const esc = value => `"${String(value).replace(/"/g, '""')}"`;
const cases = [];
for (const [code, capability, module, target, actor, action, expected] of capabilities) {
  perspectives.forEach(([suffix, priority, type, precondition, step, data, result, cleanup, automated], index) => {
    cases.push({
      id: `AI-${code}-${String(index + 1).padStart(2, '0')}`,
      module,
      capability,
      priority,
      type,
      target,
      actor,
      precondition,
      steps: step.replaceAll('{action}', action),
      testData: data,
      expected: result.replaceAll('{expected}', expected),
      cleanup,
      automatable: automated,
      perspective: suffix
    });
  });
}

const journeys = [
  ['Login completo de cliente por e-mail','auth','P0','cliente','Abrir Login; informar e-mail válido e senha; clicar Entrar; atualizar o navegador; fechar e abrir nova aba.','Cliente entra na home de cliente, continua autenticado e não vê menus administrativos.'],
  ['Login completo de cliente por telefone','auth','P0','cliente','Abrir Login; informar telefone com máscara e senha; clicar Entrar.','Telefone é normalizado e o cliente entra na própria home.'],
  ['Login completo de barbeiro','auth','P0','barbeiro','Entrar com as credenciais do barbeiro recém-cadastrado.','Abre o painel profissional com somente sua agenda, horários, bloqueios e contatos autorizados.'],
  ['Login completo de administrador','auth','P0','admin','Entrar com credenciais do proprietário.','Abre o painel administrativo do tenant correto com relatório, serviços, equipe, financeiro e personalização.'],
  ['Login inválido e recuperação da interface','auth','P0','visitante','Tentar senha errada três vezes; corrigir a senha sem recarregar; entrar.','Erros não revelam se a conta existe, formulário continua utilizável e login correto funciona.'],
  ['Logout e uso do botão Voltar','auth','P0','usuário','Fazer logout; usar Voltar do navegador; tentar abrir diretamente uma rota protegida.','Dados privados não reaparecem e o usuário volta ao login/landing.'],
  ['Cadastro completo de cliente e primeiro login','auth','P0','visitante','Escolher Sou cliente; preencher nome, telefone, e-mail, username e senha; cadastrar; fazer login.','Conta cliente é criada uma vez e todos os dados aparecem corretamente no perfil.'],
  ['Cadastro completo de proprietário e tenant','auth','P0','visitante','Escolher Tenho barbearia; preencher dados pessoais e da empresa; concluir; entrar no painel.','Admin, barbearia, membership e trial de 14 dias existem e pertencem ao mesmo tenant.'],
  ['Editar perfil e verificar reflexo no sistema','usuarios','P0','cliente','Alterar nome, username, telefone e e-mail; salvar; relogar; abrir Meus agendamentos.','Novos dados persistem e são usados em perfil e referências futuras sem mudar o proprietário dos agendamentos.'],
  ['Alterar senha e invalidar senha anterior','usuarios','P0','usuário','Trocar senha informando a atual; sair; tentar a senha antiga; entrar com a nova.','Senha antiga falha e nova senha autentica; nenhuma senha aparece em logs ou respostas.'],
  ['Cadastrar barbeiro e validar efeito para cliente','colaboradores','P0','admin','Abrir Equipe; Novo colaborador; preencher nome, telefone e senha inicial; cadastrar; sair; entrar como cliente e abrir Agendar.','Barbeiro aparece ativo na equipe, consegue logar e aparece como opção de profissional na barbearia correta.'],
  ['Editar dados do barbeiro e conferir propagação','colaboradores','P1','admin','Editar nome, telefone e e-mail do barbeiro; salvar; consultar equipe, agenda e seleção do cliente.','Dados atualizados aparecem em todos os pontos sem criar outro usuário ou colaborador.'],
  ['Desativar barbeiro com agenda futura','colaboradores','P0','admin','Criar agendamento futuro; desativar o barbeiro; entrar como cliente e consultar profissionais/horários; conferir agendamento existente.','Barbeiro não recebe novas reservas; reserva existente permanece íntegra e tratável pelo admin conforme regra.'],
  ['Reativar barbeiro','colaboradores','P1','admin','Reativar profissional desativado; configurar horários; abrir fluxo de cliente.','Profissional volta às opções e somente slots válidos são disponibilizados.'],
  ['Excluir barbeiro sem atendimentos','colaboradores','P1','admin','Cadastrar profissional temporário; clicar Excluir; cancelar confirmação; repetir e confirmar.','Cancelar não altera nada; confirmar remove/desativa conforme contrato e ele deixa de aparecer ao cliente.'],
  ['Tentar excluir barbeiro com histórico','colaboradores','P0','admin','Escolher profissional com atendimento concluído; tentar excluir.','Histórico financeiro e referencial não é corrompido; sistema bloqueia ou faz remoção lógica segura.'],
  ['Criar serviço de corte','servicos','P0','admin','Abrir Serviços; Novo serviço; informar Corte Tradicional, R$ 35,00, 30 minutos e descrição; salvar.','Serviço aparece para admin e cliente com preço e duração corretos.'],
  ['Criar segundo serviço para combinação','servicos','P0','admin','Cadastrar Barba Completa por R$ 25,00 e 20 minutos.','Segundo serviço ativo fica disponível para seleção conjunta.'],
  ['Editar preço e duração de serviço','servicos','P0','admin','Alterar Corte Tradicional para R$ 40,00 e 45 minutos; salvar; iniciar novo agendamento.','Novas reservas usam R$ 40,00/45 min; reservas já criadas preservam valor e duração capturados.'],
  ['Desativar serviço com reserva futura','servicos','P0','admin','Criar reserva futura; excluir/desativar o serviço; abrir catálogo como cliente.','Serviço não aceita novas reservas e o agendamento existente continua legível e consistente.'],
  ['Configurar semana completa do barbeiro','horarios','P0','admin','Selecionar barbeiro; ativar segunda a sexta 09:00–18:00; sábado 09:00–13:00; domingo inativo; salvar e recarregar.','Configuração persiste exatamente e gera slots apenas dentro dos períodos.'],
  ['Barbeiro altera os próprios horários','horarios','P0','barbeiro','Entrar como barbeiro; alterar quarta-feira para 10:00–16:00; salvar; consultar como cliente.','Barbeiro altera somente a própria agenda e os slots de quarta refletem a mudança.'],
  ['Admin tenta alterar horário de barbeiro de outro tenant','horarios','P0','admin tenant A','Usar a API/UI manipulada para enviar o ID de um barbeiro do tenant B.','Recebe 403 e nenhum horário do tenant B é lido ou alterado.'],
  ['Agendar um corte com um barbeiro','agendamentos','P0','cliente','Escolher Barbearia A; selecionar Corte Tradicional; escolher Barbeiro A; data futura e slot livre; confirmar.','Um agendamento confirmado aparece para cliente e barbeiro com preço/duração corretos.'],
  ['Agendar dois serviços com um barbeiro','agendamentos','P0','cliente','Escolher Barbearia A; marcar Corte Tradicional e Barba Completa; escolher Barbeiro A; selecionar data e slot; confirmar.','É criado um único agendamento com dois serviços, total R$ 65,00 e duração total 65 min; todo o intervalo fica ocupado.'],
  ['Remover um dos dois serviços antes de confirmar','agendamentos','P1','cliente','Selecionar Corte e Barba; escolher profissional/data/hora; remover Barba no resumo.','Preço e duração são recalculados, horário é revalidado e somente Corte é enviado.'],
  ['Selecionar o mesmo serviço duas vezes','agendamentos','P0','cliente','Clicar duas vezes rapidamente em Corte e observar seleção/resumo; tentar confirmar.','Serviço não é duplicado; segundo clique apenas alterna a seleção e não cobra duas vezes.'],
  ['Combinação de serviços que ultrapassa o expediente','agendamentos','P0','cliente','Selecionar serviços cuja duração total ultrapasse o fim da jornada; escolher o último horário aparente.','Slot incompatível não aparece ou confirmação é rejeitada sem reserva parcial.'],
  ['Trocar barbeiro depois de escolher horário','agendamentos','P0','cliente','Selecionar serviços, Barbeiro A, data e hora; voltar e escolher Barbeiro B.','Data/hora anterior é limpa e disponibilidade é recalculada para o Barbeiro B.'],
  ['Trocar barbearia durante o agendamento','agendamentos','P0','cliente','Na Barbearia A selecionar serviços/profissional/data; clicar Trocar barbearia; escolher Barbearia B.','Serviços, profissional, data e hora da A são limpos; somente catálogo e equipe da B aparecem.'],
  ['Buscar e escolher outra barbearia','agendamentos','P0','cliente','Abrir seletor; pesquisar parte do nome, acentos, caixa diferente e termo inexistente; selecionar resultado.','Busca retorna somente correspondências ativas, trata texto corretamente e estado vazio é claro.'],
  ['Alternar repetidamente entre duas barbearias','agendamentos','P0','cliente','Alternar A→B→A cinco vezes e observar serviços, profissionais, logo e cor.','Não há mistura de dados entre tenants, duplicação de listas nem tema preso na barbearia errada.'],
  ['Concorrência pelo último horário','agendamentos','P0','dois clientes','Abrir o mesmo slot do mesmo barbeiro em duas sessões; confirmar simultaneamente.','Exatamente um agendamento é criado; o outro recebe conflito e pode escolher outro horário.'],
  ['Cancelar agendamento ativo pelo cliente','agendamentos','P0','cliente','Abrir Meus agendamentos; escolher reserva confirmada com mais de 1 hora; cancelar e confirmar diálogo.','Status vira cancelado, sai da agenda ativa, entra no histórico e o slot volta a ficar disponível.'],
  ['Cancelar o cancelamento no diálogo','agendamentos','P1','cliente','Abrir cancelamento de reserva ativa e clicar Voltar/Não.','Reserva permanece confirmada e o slot continua ocupado.'],
  ['Tentar cancelar com menos de uma hora','agendamentos','P0','cliente','Abrir reserva que começa em menos de 60 minutos e tentar cancelar.','Sistema recusa com mensagem clara e mantém reserva confirmada.'],
  ['Tentar cancelar reserva já cancelada','agendamentos','P0','cliente','Repetir via API o cancelamento do mesmo ID já cancelado.','Retorna erro determinístico e não gera notificação ou alteração duplicada.'],
  ['Barbeiro conclui atendimento','agendamentos','P0','barbeiro','Abrir agenda; localizar atendimento confirmado; concluir; atualizar painel e relatório admin.','Status vira concluído uma vez e receita correspondente aparece no financeiro/relatório.'],
  ['Concluir duas vezes o mesmo atendimento','agendamentos','P0','barbeiro','Dar duplo clique ou repetir PATCH de conclusão.','Somente uma conclusão e um lançamento financeiro são criados.'],
  ['Bloquear horário livre e tentar agendar','agendamentos','P0','barbeiro e cliente','Barbeiro bloqueia 14:00–15:00 por compromisso; cliente consulta o mesmo dia.','Intervalo desaparece dos slots e nenhum agendamento é aceito nele.'],
  ['Bloquear horário com reserva existente','agendamentos','P0','barbeiro','Escolher período que sobrepõe reserva confirmada; consultar prévia; confirmar bloqueio.','Prévia lista impacto e criação é bloqueada ou exige fluxo seguro; reserva não some silenciosamente.'],
  ['Criar e remover bloqueio recorrente','agendamentos','P1','barbeiro','Bloquear diariamente por 7 dias; verificar ocorrências; remover uma; depois excluir todas.','Ocorrências são corretas, remoção unitária preserva demais e exclusão total libera os slots.'],
  ['Alterar cor principal por paleta','personalizacao','P0','admin','Abrir Personalização; escolher cada cor predefinida; observar preview; salvar; recarregar e relogar.','Cor escolhida aplica-se aos componentes, persiste e mantém contraste legível.'],
  ['Alterar cor principal por RGB','personalizacao','P0','admin','Abrir seletor RGB; testar #000000, #FFFFFF, cor da marca e código inválido; salvar valores válidos.','RGB válido atualiza preview/app; entrada inválida é recusada; texto e ícones mantêm contraste.'],
  ['Alternar tema claro e escuro','personalizacao','P0','admin','Alternar Claro/Escuro várias vezes; navegar por todas as páginas; recarregar.','Tema muda imediatamente, persiste e nenhuma tela fica ilegível ou com cor antiga.'],
  ['Enviar e substituir logo','personalizacao','P0','admin','Enviar PNG válido; salvar; conferir cabeçalho/login/agendamento; substituir por JPG válido.','Logo correto persiste no tenant e não aparece em outra barbearia.'],
  ['Rejeitar logo inválido ou maior que 5 MB','personalizacao','P0','admin','Tentar SVG, PDF, executável renomeado, arquivo vazio e imagem acima de 5 MB.','Upload é recusado com mensagem segura e logo anterior permanece.'],
  ['Personalização não altera usuários','personalizacao','P0','admin','Mudar cor, tema e logo; verificar cliente e barbeiro existentes, senhas, perfis e agendamentos.','Somente identidade visual do tenant muda; usuários, permissões e dados operacionais permanecem intactos.'],
  ['Registrar despesa e conferir saldo','finance','P0','admin','Abrir Financeiro; Nova despesa; informar categoria, R$ 123,45 e descrição; registrar; recarregar.','Despesa aparece uma vez e saldo diminui exatamente R$ 123,45.'],
  ['Conferência financeira ponta a ponta','finance','P0','admin','Concluir dois atendimentos com valores conhecidos; criar uma despesa; comparar dashboard, extrato, diário e mensal.','Receitas, despesa e saldo fecham centavo a centavo, sem contar cancelados.'],
  ['Isolamento financeiro entre barbearias','finance','P0','admin tenant A','Tentar consultar resumo e lançar despesa usando barbearia_id do tenant B.','Acesso é negado e nenhum valor ou lançamento do tenant B é exposto/alterado.'],
  ['Jornada completa cliente→barbeiro→admin','end_to_end','P0','todos','Admin cria barbeiro, dois serviços e jornada; cliente troca para essa barbearia e agenda ambos; barbeiro conclui; admin confere relatório; cliente vê histórico.','Todos os módulos apresentam o mesmo atendimento, serviços, preço, duração, status e tenant, sem duplicidade.'],
  ['Jornada completa de cancelamento e reutilização do slot','end_to_end','P0','todos','Cliente A agenda; cancela dentro da regra; Cliente B atualiza disponibilidade e reserva o slot liberado; barbeiro abre agenda.','Slot é liberado após cancelamento e pertence somente ao Cliente B após nova reserva.'],
  ['Persistência após reinício e nova sessão','end_to_end','P1','todos','Criar personalização, serviço, barbeiro, horários, reserva e despesa; reiniciar API/app; entrar novamente em cada perfil.','Todos os dados persistentes reaparecem corretos e estados transitórios/loading não ficam travados.']
];

journeys.forEach(([title, module, priority, actor, steps, expected], index) => {
  cases.unshift({
    id: `QA-E2E-${String(journeys.length - index).padStart(3, '0')}`,
    module,
    capability: title,
    priority,
    type: 'jornada funcional concreta',
    target: 'Interface Flutter + API + persistência',
    actor,
    precondition: 'Usar ambiente QA com tenants A e B, dados identificáveis e evidências habilitadas.',
    steps,
    testData: 'Usar dados únicos prefixados pelo ID do caso e valores descritos nos passos.',
    expected,
    cleanup: 'Restaurar configurações e remover dados temporários sem apagar evidências.',
    automatable: 'parcial',
    perspective: 'E2E_REAL'
  });
});

const docs = path.resolve(__dirname, '..', 'docs');
fs.mkdirSync(docs, { recursive: true });
const jsonPath = path.join(docs, 'AI_TEST_CATALOG.json');
const csvPath = path.join(docs, 'AI_TEST_CATALOG.csv');
const guidePath = path.join(docs, 'AI_TEST_EXECUTION_GUIDE.md');
fs.writeFileSync(jsonPath, JSON.stringify({version: 1, generatedAt: new Date().toISOString(), total: cases.length, cases}, null, 2));
const headers = Object.keys(cases[0]);
fs.writeFileSync(csvPath, '\uFEFF' + [headers.map(esc).join(','), ...cases.map(item => headers.map(h => esc(item[h])).join(','))].join('\n'));

const counts = capabilities.map(([code, name, module]) => `| ${code} | ${module} | ${name} | 12 |`).join('\n');
const guide = `# Plano de testes para agente de IA — GetCutt\n\nEste catálogo contém **${cases.length} casos executáveis**, derivados diretamente das rotas, controladores, telas Flutter, migrações e regras de acesso do projeto. Os **${journeys.length} primeiros casos** têm \`perspective: E2E_REAL\` e devem ser executados navegando e operando o produto como um QA. Os demais aprofundam validação, segurança, concorrência e resiliência.\n\n## Arquivos\n\n- \`AI_TEST_CATALOG.json\`: fonte estruturada recomendada para agentes de teste.\n- \`AI_TEST_CATALOG.csv\`: versão para planilhas e importação em ferramentas de QA.\n- \`scripts/generate-ai-test-catalog.js\`: gerador determinístico do catálogo.\n\n## Ordem de execução\n\n1. Execute primeiro todos os casos \`E2E_REAL\`, na ordem do catálogo.\n2. Execute depois os demais P0, seguidos por P1 e P2.\n3. Um teste funcional só passa se a ação foi realmente realizada no sistema; inspecionar código não conta como execução.\n4. Quando o caso atravessar módulos, confira a mesma informação na tela do cliente, do barbeiro e do admin.\n\n## Protocolo obrigatório para a IA executora\n\n1. Use apenas ambiente de teste e credenciais sandbox; nunca efetue cobrança real.\n2. Crie dois tenants isolados (A e B) e usuários cliente, barbeiro e admin em ambos.\n3. Interaja pela interface Flutter. Use API e banco para preparar dados ou confirmar efeitos, nunca para substituir a jornada de UI descrita.\n4. Antes de cada caso, registre build/commit, ambiente, navegador/dispositivo, data/hora e dados preparados.\n5. Depois de cada passo relevante, capture evidência. Ao final, registre status \`passed\`, \`failed\`, \`blocked\` ou \`skipped\`, resposta HTTP, request ID e defeito relacionado.\n6. Nunca marque como aprovado sem comparar interface, resposta da API e persistência quando o caso solicitar isso.\n7. Faça o cleanup indicado. Se falhar, marque o ambiente como contaminado e não reutilize o mesmo dado em casos de concorrência.\n8. Mascare senhas, JWTs, refresh tokens, tokens de convite, segredos de webhook e dados pessoais nas evidências.\n9. Em caso de divergência entre UI e API, abra um defeito separado e associe todos os casos afetados.\n10. Para casos parcialmente automatizáveis, automatize API/estado e mantenha inspeção visual para UX e acessibilidade.\n\n## Formato do relatório de execução\n\n\`caseId, status, startedAt, finishedAt, environment, actor, requestIds, evidence, actualResult, defectId, cleanupStatus\`.\n\n## Critério de saída\n\n- 100% dos E2E_REAL e P0 executados e aprovados.\n- Nenhum vazamento entre tenants, bypass de autenticação/autorização, duplicidade financeira ou conflito de agenda aberto.\n- P1 com pelo menos 95% de aprovação e riscos restantes explicitamente aceitos.\n- P2 executados nos viewports 390×844, 768×1024 e 1440×900.\n\n## Cobertura técnica complementar\n\n| Código | Módulo | Capacidade | Casos |\n|---|---|---|---:|\n${counts}\n\nJornadas funcionais concretas: **${journeys.length}**. Casos totais: **${cases.length}**.\n`;
fs.writeFileSync(guidePath, guide);
console.log(JSON.stringify({total: cases.length, jsonPath, csvPath, guidePath}));
