// ==========================================
// TELA: Home Admin
// RF12 - Serviços | RF13 - Relatório | RF14 - Colaboradores | RF04 - Personalização
// ==========================================
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/barbearia_theme_service.dart';
import '../../../features/auth/controllers/auth_controller.dart';
import '../../../features/barbeiro/screens/horarios_screen.dart';
import '../../../shared/widgets/perfil_screen.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/responsive_nav_shell.dart';
import '../controllers/admin_controller.dart';
import 'personalizacao_screen.dart';
import 'financeiro_screen.dart';

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
    final auth = context.watch<AuthController>();
    final paginas = [
      const _RelatorioTab(),
      const _ServicosTab(),
      const _ColaboradoresTab(),
      const FinanceiroScreen(),
      const PersonalizacaoScreen(),
      const PerfilScreen(),
    ];
    const itens = [
      NavShellItem(
          icon: Icons.bar_chart_outlined,
          activeIcon: Icons.bar_chart,
          label: 'Relatório'),
      NavShellItem(
          icon: Icons.content_cut_outlined,
          activeIcon: Icons.content_cut,
          label: 'Serviços'),
      NavShellItem(
          icon: Icons.group_outlined, activeIcon: Icons.group, label: 'Equipe'),
      NavShellItem(
          icon: Icons.account_balance_wallet_outlined,
          activeIcon: Icons.account_balance_wallet,
          label: 'Financeiro'),
      NavShellItem(
          icon: Icons.palette_outlined,
          activeIcon: Icons.palette,
          label: 'Visual'),
      NavShellItem(
          icon: Icons.person_outline_rounded,
          activeIcon: Icons.person_rounded,
          label: 'Perfil'),
    ];
    return ResponsiveNavShell(
      currentIndex: _paginaAtual,
      onTap: (i) => setState(() => _paginaAtual = i),
      items: itens,
      tituloMarca: 'GetCutt',
      userName: auth.nomeUsuario ?? 'Administrador',
      userRole: 'Administrador',
      onLogout: auth.logout,
      body: paginas[_paginaAtual],
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
    context.watch<BarbeariaThemeService>();
    final ctrl = context.watch<AdminController>();
    final auth = context.read<AuthController>();
    final rel = ctrl.relatorio;
    final cor = Theme.of(context).colorScheme.primary;

    return _TabShell(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Header
              Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                          'Olá, ${auth.nomeUsuario?.split(' ').first ?? 'Admin'}',
                          style: GoogleFonts.inter(
                              color: AppTheme.corTextoSecundario,
                              fontSize: 14)),
                      const SizedBox(height: 4),
                      Text('Relatório',
                          style: GoogleFonts.inter(
                              color: AppTheme.corTexto,
                              fontSize: 26,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text('Acompanhe o faturamento e os atendimentos do dia.',
                          style: GoogleFonts.inter(
                              color: AppTheme.corTextoSecundario,
                              fontSize: 14,
                              letterSpacing: 0.3)),
                    ])),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    final atual =
                        DateTime.tryParse(rel['data']?.toString() ?? '') ??
                            DateTime.now();
                    final data = await showDatePicker(
                      context: context,
                      initialDate: atual,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (data != null && context.mounted) {
                      await context.read<AdminController>().carregarRelatorio(
                          data: DateFormat('yyyy-MM-dd').format(data));
                    }
                  },
                  icon: const Icon(Icons.calendar_month_outlined, size: 18),
                  label: Text(rel['data'] == null
                      ? 'Escolher data'
                      : DateFormat('dd/MM/yyyy')
                          .format(DateTime.parse(rel['data']))),
                ),
              ]),
              const SizedBox(height: 28),

              // Hero — faturamento do dia
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      cor.withValues(alpha: 0.16),
                      cor.withValues(alpha: 0.03)
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cor.withValues(alpha: 0.25)),
                ),
                child: ctrl.carregandoRelatorio
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Row(children: [
                              Icon(Icons.account_balance_wallet_outlined,
                                  color: cor, size: 18),
                              const SizedBox(width: 8),
                              Text('Faturamento de hoje',
                                  style: GoogleFonts.inter(
                                      color: AppTheme.corTextoSecundario,
                                      fontSize: 13)),
                            ]),
                            const SizedBox(height: 12),
                            Text('R\$ ${rel['total_faturado'] ?? '0.00'}',
                                style: GoogleFonts.inter(
                                    color: AppTheme.corTexto,
                                    fontSize: 36,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 14),
                            Row(children: [
                              const Icon(Icons.check_circle_outline,
                                  color: AppTheme.sucesso, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                  '${rel['total_atendimentos'] ?? 0} atendimentos concluídos',
                                  style: GoogleFonts.inter(
                                      color: AppTheme.corTextoSecundario,
                                      fontSize: 13)),
                            ]),
                            const SizedBox(height: 16),
                            Wrap(spacing: 24, runSpacing: 10, children: [
                              _ReportDetail(
                                  label: 'Receita prevista',
                                  value:
                                      'R\$ ${rel['total_previsto'] ?? '0.00'}'),
                              _ReportDetail(
                                  label: 'Agendamentos pendentes',
                                  value:
                                      '${rel['confirmados_pendentes'] ?? 0}'),
                            ]),
                          ]),
              ),
              const SizedBox(height: 28),

              // Atendimentos do dia
              Text('Atendimentos do dia',
                  style: GoogleFonts.inter(
                      color: AppTheme.corTexto,
                      fontSize: 18,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              if (rel['atendimentos'] != null &&
                  (rel['atendimentos'] as List).isNotEmpty)
                ...(rel['atendimentos'] as List).map((a) {
                  final data = DateTime.parse(a['data_hora']);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElev,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: cor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(DateFormat('HH:mm').format(data),
                            style: GoogleFonts.inter(
                                color: cor,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(a['servico'],
                                style: GoogleFonts.inter(
                                    color: AppTheme.corTexto,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14)),
                            const SizedBox(height: 2),
                            Text('${a['barbeiro']} · ${a['cliente']}',
                                style: GoogleFonts.inter(
                                    color: AppTheme.corTextoSecundario,
                                    fontSize: 12)),
                          ])),
                      const SizedBox(width: 12),
                      Text(
                          'R\$ ${double.parse(a['valor_cobrado'].toString()).toStringAsFixed(2)}',
                          style: GoogleFonts.inter(
                              color: cor,
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                    ]),
                  );
                })
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElev,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                      child: Text('Nenhum atendimento concluído hoje.',
                          style: GoogleFonts.inter(
                              color: AppTheme.corTextoSecundario,
                              fontSize: 14))),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ==========================================
class _ReportDetail extends StatelessWidget {
  final String label;
  final String value;
  const _ReportDetail({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: AppTheme.black.withValues(alpha: .22),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: GoogleFonts.inter(
                  color: AppTheme.corTextoSecundario, fontSize: 11)),
          const SizedBox(height: 3),
          Text(value,
              style: GoogleFonts.inter(
                  color: AppTheme.corTexto,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
        ]),
      );
}

// TAB: Gestão de Serviços
// RF12 - Serviços e Preços
// ==========================================
class _ServicosTab extends StatelessWidget {
  const _ServicosTab();

  String? _tagServico(Map<String, dynamic> s) {
    if (s['tag'] != null && s['tag'].toString().isNotEmpty)
      return s['tag'].toString();
    if (s['destaque'] == true || s['destaque'] == 1) return 'Destaque';
    return null;
  }

  void _mostrarFormServico(BuildContext context,
      {Map<String, dynamic>? servico}) {
    final nomeCtrl = TextEditingController(text: servico?['nome']);
    final precoCtrl =
        TextEditingController(text: servico?['preco']?.toString());
    final duracaoCtrl =
        TextEditingController(text: servico?['duracao_min']?.toString());
    final descCtrl = TextEditingController(text: servico?['descricao']);
    final editando = servico != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceElev,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (modalCtx) => Padding(
        padding: MediaQuery.of(modalCtx).viewInsets,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                    child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppTheme.border,
                      borderRadius: BorderRadius.circular(2)),
                )),
                const SizedBox(height: 20),
                Text(editando ? 'Editar Serviço' : 'Novo Serviço',
                    style: GoogleFonts.inter(
                        color: AppTheme.corTexto,
                        fontSize: 20,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                TextField(
                    controller: nomeCtrl,
                    style: GoogleFonts.inter(color: AppTheme.corTexto),
                    decoration:
                        const InputDecoration(labelText: 'Nome do serviço')),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: TextField(
                          controller: precoCtrl,
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.inter(color: AppTheme.corTexto),
                          decoration:
                              const InputDecoration(labelText: 'Preço (R\$)'))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: TextField(
                          controller: duracaoCtrl,
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.inter(color: AppTheme.corTexto),
                          decoration: const InputDecoration(
                              labelText: 'Duração (min)'))),
                ]),
                const SizedBox(height: 12),
                TextField(
                    controller: descCtrl,
                    style: GoogleFonts.inter(color: AppTheme.corTexto),
                    decoration: const InputDecoration(
                        labelText: 'Descrição (opcional)')),
                const SizedBox(height: 24),
                Consumer<AdminController>(builder: (ctx, ctrl, _) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed:
                            ctrl.salvando ? null : () => Navigator.pop(ctx),
                        child: Text('Cancelar',
                            style: GoogleFonts.inter(
                                color: AppTheme.corTextoSecundario)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: ctrl.salvando
                            ? null
                            : () async {
                                final ok = editando
                                    ? await ctrl.atualizarServico(
                                        id: servico['id'],
                                        nome: nomeCtrl.text,
                                        preco:
                                            double.tryParse(precoCtrl.text) ??
                                                0,
                                        duracaoMin:
                                            int.tryParse(duracaoCtrl.text) ??
                                                30,
                                        descricao: descCtrl.text.isEmpty
                                            ? null
                                            : descCtrl.text)
                                    : await ctrl.criarServico(
                                        nome: nomeCtrl.text,
                                        preco:
                                            double.tryParse(precoCtrl.text) ??
                                                0,
                                        duracaoMin:
                                            int.tryParse(duracaoCtrl.text) ??
                                                30,
                                        descricao: descCtrl.text.isEmpty
                                            ? null
                                            : descCtrl.text);
                                if (ok && ctx.mounted) Navigator.pop(ctx);
                              },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: ctrl.salvando
                            ? SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                    color: AppTheme.corTexto, strokeWidth: 2))
                            : Text(editando ? 'Salvar' : 'Criar'),
                      ),
                    ],
                  );
                }),
              ]),
        ),
      ),
    );
  }

  Widget _buildServicoCard(BuildContext context, Map<String, dynamic> s) {
    final cor = Theme.of(context).colorScheme.primary;
    final nome = s['nome'] ?? 'Serviço';
    final duracao = '${s['duracao_min'] ?? 0} min';
    final preco =
        'R\$ ${(double.tryParse(s['preco'].toString()) ?? 0).toStringAsFixed(2)}';
    final categoria = s['categoria'];
    final tag = _tagServico(s);

    return _HoverCard(
      child: Row(children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.content_cut, color: cor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(nome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            color: AppTheme.corTexto,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 5),
                    Row(children: [
                      Icon(Icons.schedule,
                          color: AppTheme.corTextoSecundario, size: 13),
                      const SizedBox(width: 4),
                      Text(duracao,
                          style: GoogleFonts.inter(
                              color: AppTheme.corTextoSecundario,
                              fontSize: 13)),
                      Text(' · ',
                          style: GoogleFonts.inter(
                              color: AppTheme.corTextoSecundario,
                              fontSize: 13)),
                      Icon(Icons.attach_money,
                          color: AppTheme.corTextoSecundario, size: 13),
                      const SizedBox(width: 4),
                      Text(preco,
                          style: GoogleFonts.inter(
                              color: AppTheme.corTextoSecundario,
                              fontSize: 13)),
                      if (categoria != null &&
                          categoria.toString().isNotEmpty) ...[
                        Text(' · ',
                            style: GoogleFonts.inter(
                                color: AppTheme.corTextoSecundario,
                                fontSize: 13)),
                        Icon(Icons.person_outline,
                            color: AppTheme.corTextoSecundario, size: 13),
                        const SizedBox(width: 4),
                        Flexible(
                            child: Text(categoria.toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                    color: AppTheme.corTextoSecundario,
                                    fontSize: 13))),
                      ],
                    ]),
                  ])),
            ]),
            if (tag != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(tag.toUpperCase(),
                    style: GoogleFonts.inter(
                        color: cor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5)),
              ),
            ],
          ]),
        ),
        const SizedBox(width: 16),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          const _BadgeAtivo(),
          const SizedBox(height: 10),
          Text(preco,
              style: GoogleFonts.inter(
                  color: cor, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          _CardMenuButton(
            items: [
              PopupMenuItem(
                  value: 'editar',
                  child: Text('Editar',
                      style: GoogleFonts.inter(color: AppTheme.corTexto))),
              PopupMenuItem(
                  value: 'excluir',
                  child: Text('Excluir',
                      style: GoogleFonts.inter(color: AppTheme.corErro))),
            ],
            onSelected: (v) async {
              if (v == 'editar') _mostrarFormServico(context, servico: s);
              if (v == 'excluir')
                await context.read<AdminController>().desativarServico(s['id']);
            },
          ),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<BarbeariaThemeService>();
    final ctrl = context.watch<AdminController>();
    final cor = Theme.of(context).colorScheme.primary;

    return _TabShell(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Serviços',
                          style: GoogleFonts.inter(
                              color: AppTheme.corTexto,
                              fontSize: 26,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(
                          'Gerencie os serviços oferecidos pela sua barbearia.',
                          style: GoogleFonts.inter(
                              color: AppTheme.corTextoSecundario,
                              fontSize: 14,
                              letterSpacing: 0.3)),
                    ])),
                const SizedBox(width: 16),
                _PrimaryButton(
                  label: '+ Novo serviço',
                  icon: Icons.add,
                  onPressed: () => _mostrarFormServico(context),
                ),
              ]),
              const SizedBox(height: 28),
              Expanded(
                child: ctrl.carregandoServicos
                    ? Center(child: CircularProgressIndicator(color: cor))
                    : ctrl.servicos.isEmpty
                        ? const _EmptyState(
                            icon: Icons.content_cut_outlined,
                            message: 'Nenhum serviço cadastrado.')
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 8),
                            itemCount: ctrl.servicos.length,
                            itemBuilder: (context, i) =>
                                _buildServicoCard(context, ctrl.servicos[i]),
                          ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// TAB: Gestão de Colaboradores
// RF14 - Gestão Multiusuário
// ==========================================
class _ColaboradoresTab extends StatelessWidget {
  const _ColaboradoresTab();

  Future<void> _mostrarEdicaoColaborador(
      BuildContext context, Map<String, dynamic> colaborador) async {
    final nomeCtrl = TextEditingController(text: colaborador['nome'] ?? '');
    final telefoneCtrl =
        TextEditingController(text: colaborador['telefone'] ?? '');
    final emailCtrl = TextEditingController(text: colaborador['email'] ?? '');
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surfaceElev,
        title: Text('Editar profissional',
            style: GoogleFonts.inter(
                color: AppTheme.corTexto, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 440,
          child: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: nomeCtrl,
                decoration: const InputDecoration(labelText: 'Nome completo'),
                validator: (value) =>
                    (value ?? '').trim().length < 2 ? 'Informe o nome.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: telefoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Telefone'),
                validator: (value) => (value ?? '').trim().length < 8
                    ? 'Informe um telefone válido.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration:
                    const InputDecoration(labelText: 'E-mail (opcional)'),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              final controller = context.read<AdminController>();
              final sucesso = await controller.atualizarColaborador(
                id: colaborador['id'],
                nome: nomeCtrl.text.trim(),
                telefone: telefoneCtrl.text.trim(),
                email: emailCtrl.text.trim(),
              );
              if (!dialogContext.mounted) return;
              if (sucesso) {
                Navigator.pop(dialogContext);
              } else {
                AppToast.show(context, controller.erro,
                    type: AppToastType.error);
              }
            },
            child: const Text('Salvar alterações'),
          ),
        ],
      ),
    );
    nomeCtrl.dispose();
    telefoneCtrl.dispose();
    emailCtrl.dispose();
  }

  void _mostrarFormColaborador(BuildContext context) {
    final nomeCtrl = TextEditingController();
    final telefoneCtrl = TextEditingController();
    final senhaCtrl = TextEditingController();
    final loading = ValueNotifier<bool>(false);
    final erroMsg = ValueNotifier<String>('');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceElev,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => Padding(
        padding: MediaQuery.of(sheetCtx).viewInsets,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                    child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppTheme.border,
                      borderRadius: BorderRadius.circular(2)),
                )),
                const SizedBox(height: 20),
                Text('Novo Colaborador',
                    style: GoogleFonts.inter(
                        color: AppTheme.corTexto,
                        fontSize: 20,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                TextField(
                    controller: nomeCtrl,
                    style: GoogleFonts.inter(color: AppTheme.corTexto),
                    textCapitalization: TextCapitalization.words,
                    decoration:
                        const InputDecoration(labelText: 'Nome completo')),
                const SizedBox(height: 12),
                TextField(
                    controller: telefoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: GoogleFonts.inter(color: AppTheme.corTexto),
                    decoration: const InputDecoration(labelText: 'Telefone')),
                const SizedBox(height: 12),
                TextField(
                    controller: senhaCtrl,
                    obscureText: true,
                    style: GoogleFonts.inter(color: AppTheme.corTexto),
                    decoration:
                        const InputDecoration(labelText: 'Senha inicial')),
                const SizedBox(height: 20),
                ValueListenableBuilder<String>(
                  valueListenable: erroMsg,
                  builder: (_, msg, __) => msg.isEmpty
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(msg,
                              style: GoogleFonts.inter(
                                  color: AppTheme.corErro, fontSize: 13))),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: loading,
                  builder: (_, isLoading, __) => Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed:
                            isLoading ? null : () => Navigator.pop(sheetCtx),
                        child: Text('Cancelar',
                            style: GoogleFonts.inter(
                                color: AppTheme.corTextoSecundario)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : () async {
                                if (nomeCtrl.text.trim().isEmpty ||
                                    telefoneCtrl.text.trim().isEmpty ||
                                    senhaCtrl.text.trim().isEmpty) {
                                  erroMsg.value = 'Preencha todos os campos.';
                                  return;
                                }
                                loading.value = true;
                                erroMsg.value = '';

                                final adminController =
                                    context.read<AdminController>();
                                final sucesso =
                                    await adminController.cadastrarColaborador(
                                  nome: nomeCtrl.text.trim(),
                                  telefone: telefoneCtrl.text.trim(),
                                  senha: senhaCtrl.text.trim(),
                                );

                                loading.value = false;

                                if (!sucesso) {
                                  erroMsg.value = adminController.erro;
                                } else {
                                  if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                                  if (context.mounted) {
                                    AppToast.show(
                                        context, 'Colaborador cadastrado!');
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: isLoading
                            ? SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                    color: AppTheme.corTexto, strokeWidth: 2))
                            : const Text('Cadastrar'),
                      ),
                    ],
                  ),
                ),
              ]),
        ),
      ),
    );
  }

  Widget _buildColaboradorCard(BuildContext context, Map<String, dynamic> c) {
    final cor = Theme.of(context).colorScheme.primary;
    final ctrl = context.read<AdminController>();
    final nome = c['nome'] ?? '';
    final telefone = c['telefone'] ?? '';
    final roleRaw = (c['role'] ?? 'barbeiro').toString();
    final roleLabel =
        roleRaw.toUpperCase().contains('ADMIN') ? 'ADMIN' : 'BARBEIRO';

    return _HoverCard(
      child: Row(children: [
        CircleAvatar(
          radius: 23,
          backgroundColor: cor.withValues(alpha: 0.15),
          child: Text(nome.isNotEmpty ? nome[0].toUpperCase() : '?',
              style: GoogleFonts.inter(
                  color: cor, fontSize: 16, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(nome,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                  color: AppTheme.corTexto,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(telefone,
              style: GoogleFonts.inter(
                  color: AppTheme.corTextoSecundario, fontSize: 13)),
        ])),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(roleLabel,
              style: GoogleFonts.inter(
                  color: AppTheme.corTextoSecundario,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
        ),
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: (c['ativo'] == 1 ? AppTheme.corSucesso : AppTheme.corErro)
                .withValues(alpha: .12),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(c['ativo'] == 1 ? 'ATIVO' : 'INATIVO',
              style: GoogleFonts.inter(
                  color:
                      c['ativo'] == 1 ? AppTheme.corSucesso : AppTheme.corErro,
                  fontSize: 10,
                  fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 12),
        Switch(
          value: c['ativo'] == 1,
          activeThumbColor: cor,
          activeTrackColor: cor.withValues(alpha: 0.3),
          onChanged: (v) async {
            await ctrl.alterarStatusColaborador(c['id'], v);
          },
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Editar profissional',
          onPressed: () => _mostrarEdicaoColaborador(context, c),
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          tooltip: 'Configurar horários',
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const HorariosScreen())),
          icon: const Icon(Icons.schedule_outlined),
        ),
        _CardMenuButton(
          items: [
            PopupMenuItem(
                value: 'excluir',
                child: Text('Excluir',
                    style: GoogleFonts.inter(color: AppTheme.corErro))),
          ],
          onSelected: (v) async {
            if (v == 'excluir') {
              final confirmar = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: AppTheme.surfaceElev,
                  title: Text('Excluir colaborador?',
                      style: GoogleFonts.inter(
                          color: AppTheme.corTexto,
                          fontSize: 18,
                          fontWeight: FontWeight.w600)),
                  content: Text('Tem certeza que deseja excluir $nome?',
                      style: GoogleFonts.inter(
                          color: AppTheme.corTextoSecundario, fontSize: 14)),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text('Cancelar',
                            style: GoogleFonts.inter(
                                color: AppTheme.corTextoSecundario))),
                    TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text('Excluir',
                            style: GoogleFonts.inter(
                                color: AppTheme.corErro,
                                fontWeight: FontWeight.w600))),
                  ],
                ),
              );
              if (confirmar == true) {
                await ctrl.removerColaborador(c['id']);
              }
            }
          },
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<BarbeariaThemeService>();
    final ctrl = context.watch<AdminController>();
    final cor = Theme.of(context).colorScheme.primary;

    return _TabShell(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Equipe',
                          style: GoogleFonts.inter(
                              color: AppTheme.corTexto,
                              fontSize: 26,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text('Gerencie os membros da sua equipe.',
                          style: GoogleFonts.inter(
                              color: AppTheme.corTextoSecundario,
                              fontSize: 14,
                              letterSpacing: 0.3)),
                    ])),
                const SizedBox(width: 16),
                _PrimaryButton(
                  label: '+ Adicionar membro',
                  icon: Icons.person_add,
                  onPressed: () => _mostrarFormColaborador(context),
                ),
              ]),
              const SizedBox(height: 28),
              Expanded(
                child: ctrl.carregandoColaboradores
                    ? Center(child: CircularProgressIndicator(color: cor))
                    : ctrl.colaboradores.isEmpty
                        ? const _EmptyState(
                            icon: Icons.group_outlined,
                            message: 'Nenhum colaborador cadastrado.')
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 8),
                            itemCount: ctrl.colaboradores.length,
                            itemBuilder: (context, i) => _buildColaboradorCard(
                                context, ctrl.colaboradores[i]),
                          ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// SHELL: Fundo com brilho radial + SafeArea
// ==========================================
class _TabShell extends StatelessWidget {
  final Widget child;
  const _TabShell({required this.child});

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.primary;
    return Container(
      color: AppTheme.black,
      child: Stack(children: [
        Positioned(
          top: -160,
          right: -140,
          child: _Glow(size: 480, cor: cor),
        ),
        Positioned(
          bottom: -180,
          left: -160,
          child: _Glow(size: 460, cor: cor, opacity: 0.04),
        ),
        Positioned.fill(child: SafeArea(child: child)),
      ]),
    );
  }
}

class _Glow extends StatelessWidget {
  final double size;
  final Color cor;
  final double opacity;
  const _Glow({required this.size, required this.cor, this.opacity = 0.05});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [cor.withValues(alpha: opacity), cor.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

// ==========================================
// BUTTON: Botão primário com hover
// ==========================================
class _PrimaryButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  const _PrimaryButton(
      {required this.label, required this.icon, required this.onPressed});

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.primary;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hover ? -1 : 0, 0),
        decoration: BoxDecoration(
          color: cor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: _hover
              ? [
                  BoxShadow(
                      color: cor.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8))
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: widget.onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(widget.icon, color: AppTheme.corTexto, size: 18),
                const SizedBox(width: 8),
                Text(widget.label,
                    style: GoogleFonts.inter(
                        color: AppTheme.corTexto,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// CARD: Cartão elevável com hover
// ==========================================
class _HoverCard extends StatefulWidget {
  final Widget child;
  const _HoverCard({required this.child});

  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.primary;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: AppTheme.surfaceElev,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: _hover ? cor.withValues(alpha: 0.2) : Colors.transparent),
          boxShadow: _hover
              ? [
                  BoxShadow(
                      color: cor.withValues(alpha: 0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 8))
                ]
              : null,
        ),
        child: widget.child,
      ),
    );
  }
}

// ==========================================
// MENU: Botão de três pontos com hover
// ==========================================
class _CardMenuButton extends StatefulWidget {
  final List<PopupMenuEntry<String>> items;
  final ValueChanged<String> onSelected;
  const _CardMenuButton({required this.items, required this.onSelected});

  @override
  State<_CardMenuButton> createState() => _CardMenuButtonState();
}

class _CardMenuButtonState extends State<_CardMenuButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _hover ? AppTheme.surfaceElev : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: PopupMenuButton<String>(
          color: AppTheme.surfaceElev,
          icon: Icon(Icons.more_vert,
              color: AppTheme.corTextoSecundario, size: 20),
          padding: EdgeInsets.zero,
          iconSize: 20,
          onSelected: widget.onSelected,
          itemBuilder: (_) => widget.items,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

// ==========================================
// BADGE: Status "Ativo"
// ==========================================
class _BadgeAtivo extends StatelessWidget {
  const _BadgeAtivo();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.sucesso.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
                color: AppTheme.sucesso, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text('ATIVO',
            style: GoogleFonts.inter(
                color: AppTheme.sucesso,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5)),
      ]),
    );
  }
}

// ==========================================
// EMPTY STATE: Nenhum registro
// ==========================================
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.primary;
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: cor.withValues(alpha: 0.3), size: 48),
        const SizedBox(height: 16),
        Text(message,
            style: GoogleFonts.inter(
                color: AppTheme.corTextoSecundario, fontSize: 14)),
      ]),
    );
  }
}
