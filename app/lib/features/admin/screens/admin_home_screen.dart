// ==========================================
// TELA: Home Admin
// RF12 - Serviços | RF13 - Relatório | RF14 - Colaboradores | RF04 - Personalização
// ==========================================
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../features/auth/controllers/auth_controller.dart';
import '../controllers/admin_controller.dart';
import 'personalizacao_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _paginaAtual = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminController>().carregarServicos();
      context.read<AdminController>().carregarColaboradores();
      context.read<AdminController>().carregarRelatorio();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: [
        const _RelatorioTab(),
        const _ServicosTab(),
        const _ColaboradoresTab(),
        const PersonalizacaoScreen(),
      ][_paginaAtual],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _paginaAtual,
        onTap: (i) => setState(() => _paginaAtual = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined),   activeIcon: Icon(Icons.bar_chart),   label: 'Relatório'),
          BottomNavigationBarItem(icon: Icon(Icons.content_cut_outlined),  activeIcon: Icon(Icons.content_cut), label: 'Serviços'),
          BottomNavigationBarItem(icon: Icon(Icons.group_outlined),        activeIcon: Icon(Icons.group),       label: 'Equipe'),
          BottomNavigationBarItem(icon: Icon(Icons.palette_outlined),      activeIcon: Icon(Icons.palette),     label: 'Visual'),
        ],
      ),
    );
  }
}

// ==========================================
// TAB: Relatório de Faturamento
// RF13 - Faturamento Diário
// ==========================================
class _RelatorioTab extends StatelessWidget {
  const _RelatorioTab();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AdminController>();
    final auth = context.read<AuthController>();
    final rel  = ctrl.relatorio;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Olá, ${auth.nomeUsuario?.split(' ').first ?? 'Admin'}! 👑',
                  style: TextStyle(color: AppTheme.corTextoSecundario, fontSize: 14)),
              Text('Painel Admin',
                  style: TextStyle(color: AppTheme.corTexto, fontSize: 22, fontWeight: FontWeight.bold)),
            ]),
            IconButton(
              icon: Icon(Icons.logout, color: AppTheme.corTextoSecundario),
              onPressed: () => context.read<AuthController>().logout(),
            ),
          ]),
          const SizedBox(height: 24),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF2C2410), Color(0xFF3D3015)]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.corPrimaria.withOpacity(0.4)),
            ),
            child: ctrl.carregandoRelatorio
                ? Center(child: CircularProgressIndicator(color: AppTheme.corPrimaria))
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Faturamento de hoje', style: TextStyle(color: AppTheme.corTextoSecundario, fontSize: 13)),
                    const SizedBox(height: 8),
                    Text('R\$ ${rel['total_faturado'] ?? '0.00'}',
                        style: TextStyle(color: AppTheme.corPrimaria, fontSize: 36, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('${rel['total_atendimentos'] ?? 0} atendimentos concluídos',
                        style: TextStyle(color: AppTheme.corTextoSecundario, fontSize: 13)),
                  ]),
          ),
          SizedBox(height: 24),

          if (rel['atendimentos'] != null && (rel['atendimentos'] as List).isNotEmpty) ...[
            Text('Atendimentos do dia',
                style: TextStyle(color: AppTheme.corTexto, fontSize: 16, fontWeight: FontWeight.w600)),
            SizedBox(height: 12),
            ...(rel['atendimentos'] as List).map((a) {
              final data = DateTime.parse(a['data_hora']);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppTheme.corCard, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Text(DateFormat('HH:mm').format(data),
                      style: TextStyle(color: AppTheme.corPrimaria, fontWeight: FontWeight.bold)),
                  SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a['servico'], style: TextStyle(color: AppTheme.corTexto, fontWeight: FontWeight.w500)),
                    Text('${a['barbeiro']} · ${a['cliente']}',
                        style: TextStyle(color: AppTheme.corTextoSecundario, fontSize: 12)),
                  ])),
                  Text('R\$ ${double.parse(a['valor_cobrado'].toString()).toStringAsFixed(2)}',
                      style: TextStyle(color: AppTheme.corPrimaria, fontWeight: FontWeight.bold)),
                ]),
              );
            }),
          ] else
            Center(child: Text('Nenhum atendimento concluído hoje.',
                style: TextStyle(color: AppTheme.corTextoSecundario))),
        ]),
      ),
    );
  }
}

// ==========================================
// TAB: Gestão de Serviços
// RF12 - Serviços e Preços
// ==========================================
class _ServicosTab extends StatelessWidget {
  const _ServicosTab();

  void _mostrarFormServico(BuildContext context, {Map<String, dynamic>? servico}) {
    final nomeCtrl    = TextEditingController(text: servico?['nome']);
    final precoCtrl   = TextEditingController(text: servico?['preco']?.toString());
    final duracaoCtrl = TextEditingController(text: servico?['duracao_min']?.toString());
    final descCtrl    = TextEditingController(text: servico?['descricao']);
    final editando    = servico != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.corFundoSecundario,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (modalCtx) => Padding(
        padding: MediaQuery.of(modalCtx).viewInsets,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(editando ? 'Editar Serviço' : 'Novo Serviço',
                style: TextStyle(color: AppTheme.corTexto, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(controller: nomeCtrl, style: TextStyle(color: AppTheme.corTexto),
                decoration: const InputDecoration(labelText: 'Nome do serviço')),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: precoCtrl, keyboardType: TextInputType.number,
                  style: TextStyle(color: AppTheme.corTexto),
                  decoration: const InputDecoration(labelText: 'Preço (R\$)'))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: duracaoCtrl, keyboardType: TextInputType.number,
                  style: TextStyle(color: AppTheme.corTexto),
                  decoration: const InputDecoration(labelText: 'Duração (min)'))),
            ]),
            const SizedBox(height: 12),
            TextField(controller: descCtrl, style: TextStyle(color: AppTheme.corTexto),
                decoration: const InputDecoration(labelText: 'Descrição (opcional)')),
            const SizedBox(height: 20),
            Consumer<AdminController>(builder: (ctx, ctrl, _) {
              return ElevatedButton(
                onPressed: ctrl.salvando ? null : () async {
                  final ok = editando
                      ? await ctrl.atualizarServico(
                          id: servico!['id'], nome: nomeCtrl.text,
                          preco: double.tryParse(precoCtrl.text) ?? 0,
                          duracaoMin: int.tryParse(duracaoCtrl.text) ?? 30,
                          descricao: descCtrl.text.isEmpty ? null : descCtrl.text)
                      : await ctrl.criarServico(
                          nome: nomeCtrl.text,
                          preco: double.tryParse(precoCtrl.text) ?? 0,
                          duracaoMin: int.tryParse(duracaoCtrl.text) ?? 30,
                          descricao: descCtrl.text.isEmpty ? null : descCtrl.text);
                  if (ok && ctx.mounted) Navigator.pop(ctx);
                },
                child: ctrl.salvando
                    ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: AppTheme.corFundo, strokeWidth: 2))
                    : Text(editando ? 'Salvar Alterações' : 'Criar Serviço'),
              );
            }),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AdminController>();

    return SafeArea(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Serviços', style: TextStyle(color: AppTheme.corTexto, fontSize: 22, fontWeight: FontWeight.bold)),
            ElevatedButton.icon(
              onPressed: () => _mostrarFormServico(context),
              icon: Icon(Icons.add, size: 18),
              label: Text('Novo'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40)),
            ),
          ]),
        ),
        Expanded(
          child: ctrl.carregandoServicos
              ? Center(child: CircularProgressIndicator(color: AppTheme.corPrimaria))
              : ctrl.servicos.isEmpty
                  ? Center(child: Text('Nenhum serviço cadastrado.', style: TextStyle(color: AppTheme.corTextoSecundario)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: ctrl.servicos.length,
                      itemBuilder: (context, i) {
                        final s = ctrl.servicos[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(color: AppTheme.corCard, borderRadius: BorderRadius.circular(14)),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Color(0xFF2C2410),
                              child: Icon(Icons.content_cut, color: AppTheme.corPrimaria, size: 20),
                            ),
                            title: Text(s['nome'], style: TextStyle(color: AppTheme.corTexto, fontWeight: FontWeight.w600)),
                            subtitle: Text('${s['duracao_min']} min', style: TextStyle(color: AppTheme.corTextoSecundario, fontSize: 12)),
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              Text('R\$ ${double.parse(s['preco'].toString()).toStringAsFixed(2)}',
                                  style: TextStyle(color: AppTheme.corPrimaria, fontWeight: FontWeight.bold)),
                              SizedBox(width: 8),
                              PopupMenuButton<String>(
                                color: AppTheme.corCard,
                                icon: Icon(Icons.more_vert, color: AppTheme.corTextoSecundario),
                                onSelected: (v) async {
                                  if (v == 'editar')  _mostrarFormServico(context, servico: s);
                                  if (v == 'excluir') await ctrl.desativarServico(s['id']);
                                },
                                itemBuilder: (_) => [
                                  PopupMenuItem(value: 'editar',  child: Text('Editar',  style: TextStyle(color: AppTheme.corTexto))),
                                  PopupMenuItem(value: 'excluir', child: Text('Excluir', style: TextStyle(color: AppTheme.corErro))),
                                ],
                              ),
                            ]),
                          ),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}

// ==========================================
// TAB: Gestão de Colaboradores
// RF14 - Gestão Multiusuário
// ==========================================
class _ColaboradoresTab extends StatelessWidget {
  const _ColaboradoresTab();

  void _mostrarFormColaborador(BuildContext context) {
    final nomeCtrl     = TextEditingController();
    final telefoneCtrl = TextEditingController();
    final senhaCtrl    = TextEditingController();
    final loading      = ValueNotifier<bool>(false);
    final erroMsg      = ValueNotifier<String>('');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.corFundoSecundario,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => Padding(
        padding: MediaQuery.of(sheetCtx).viewInsets,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text('Novo Colaborador', style: TextStyle(
                color: AppTheme.corTexto, fontSize: 18,
                fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
                controller: nomeCtrl,
                style: TextStyle(color: AppTheme.corTexto),
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nome completo')),
            const SizedBox(height: 12),
            TextField(
                controller: telefoneCtrl,
                keyboardType: TextInputType.phone,
                style: TextStyle(color: AppTheme.corTexto),
                decoration: const InputDecoration(labelText: 'Telefone')),
            const SizedBox(height: 12),
            TextField(
                controller: senhaCtrl,
                obscureText: true,
                style: TextStyle(color: AppTheme.corTexto),
                decoration: const InputDecoration(labelText: 'Senha inicial')),
            const SizedBox(height: 20),
            // Erro
            ValueListenableBuilder<String>(
              valueListenable: erroMsg,
              builder: (_, msg, __) => msg.isEmpty
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(msg, style: const TextStyle(
                          color: AppTheme.corErro, fontSize: 13))),
            ),
            // Botão
            ValueListenableBuilder<bool>(
              valueListenable: loading,
              builder: (_, isLoading, __) => ElevatedButton(
                onPressed: isLoading ? null : () async {
                  if (nomeCtrl.text.trim().isEmpty ||
                      telefoneCtrl.text.trim().isEmpty ||
                      senhaCtrl.text.trim().isEmpty) {
                    erroMsg.value = 'Preencha todos os campos.';
                    return;
                  }
                  loading.value = true;
                  erroMsg.value = '';

                  final result = await ApiService.post(
                    '/colaboradores/1',
                    {
                      'nome':     nomeCtrl.text.trim(),
                      'telefone': telefoneCtrl.text.trim(),
                      'senha':    senhaCtrl.text.trim(),
                    },
                  );

                  loading.value = false;

                  if (result.containsKey('erro')) {
                    erroMsg.value = result['erro'] ?? 'Erro ao cadastrar.';
                  } else {
                    // Sucesso
                    context.read<AdminController>().carregarColaboradores();
                    if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('✅ Colaborador cadastrado!'),
                            backgroundColor: AppTheme.corSucesso));
                    }
                  }
                },
                child: isLoading
                    ? SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(
                            color: AppTheme.corFundo, strokeWidth: 2))
                    : const Text('Cadastrar Colaborador'),
              ),
            ),
          ],
        ),
        ),  // SingleChildScrollView
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AdminController>();

    return SafeArea(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Equipe', style: TextStyle(color: AppTheme.corTexto, fontSize: 22, fontWeight: FontWeight.bold)),
            ElevatedButton.icon(
              onPressed: () => _mostrarFormColaborador(context),
              icon: Icon(Icons.person_add, size: 18),
              label: Text('Adicionar'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40)),
            ),
          ]),
        ),
        Expanded(
          child: ctrl.carregandoColaboradores
              ? Center(child: CircularProgressIndicator(color: AppTheme.corPrimaria))
              : ctrl.colaboradores.isEmpty
                  ? Center(child: Text('Nenhum colaborador cadastrado.',
                      style: TextStyle(color: AppTheme.corTextoSecundario)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: ctrl.colaboradores.length,
                      itemBuilder: (context, i) {
                        final c = ctrl.colaboradores[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(color: AppTheme.corCard, borderRadius: BorderRadius.circular(14)),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.corPrimaria.withOpacity(0.2),
                              child: Text(c['nome'][0].toUpperCase(),
                                  style: TextStyle(color: AppTheme.corPrimaria, fontWeight: FontWeight.bold)),
                            ),
                            title: Text(c['nome'], style: TextStyle(color: AppTheme.corTexto, fontWeight: FontWeight.w600)),
                            subtitle: Text(c['telefone'] ?? '',
                                style: TextStyle(color: AppTheme.corTextoSecundario, fontSize: 12)),
                            trailing: Switch(
                              value: c['ativo'] == 1,
                              activeColor: AppTheme.corPrimaria,
                              onChanged: (_) => ctrl.carregarColaboradores(),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}