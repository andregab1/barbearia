import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/controllers/auth_controller.dart';
import '../controllers/agendamento_controller.dart';
import 'agendar_screen.dart';
import 'meus_agendamentos_screen.dart';
import 'historico_screen.dart';
import '../../../shared/widgets/perfil_screen.dart';
import '../../../shared/widgets/responsive_nav_shell.dart';

class ClienteHomeScreen extends StatefulWidget {
  const ClienteHomeScreen({super.key});

  @override
  State<ClienteHomeScreen> createState() => _ClienteHomeScreenState();
}

class _ClienteHomeScreenState extends State<ClienteHomeScreen> {
  int _paginaAtual = 0;

  final List<Widget> _paginas = const [
    AgendarScreen(),
    MeusAgendamentosScreen(),
    HistoricoScreen(),
    PerfilScreen(),
  ];

  static const _itens = [
    NavShellItem(
        icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Início'),
    NavShellItem(
        icon: Icons.calendar_month_outlined,
        activeIcon: Icons.calendar_month,
        label: 'Agenda'),
    NavShellItem(
        icon: Icons.history_outlined,
        activeIcon: Icons.history,
        label: 'Histórico'),
    NavShellItem(
        icon: Icons.person_outline, activeIcon: Icons.person, label: 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    return ResponsiveNavShell(
      currentIndex: _paginaAtual,
      onTap: (i) => setState(() => _paginaAtual = i),
      items: _itens,
      tituloMarca: 'GetCutt',
      body: _paginas[_paginaAtual],
    );
  }
}

class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AgendamentoController>().carregarBarbearias();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AgendamentoController>();
    final auth = context.read<AuthController>();
    final cor = Theme.of(context).colorScheme.primary;

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              'Olá, ${auth.nomeUsuario?.split(' ').first ?? 'Cliente'}',
                              style: GoogleFonts.inter(
                                  color: AppTheme.corTextoSecundario,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400)),
                          const SizedBox(height: 4),
                          Text('O que vai ser hoje?',
                              style: GoogleFonts.playfairDisplay(
                                  color: AppTheme.corTexto,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.6)),
                        ]),
                    Material(
                      color: AppTheme.surfaceElev,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: () => context.read<AuthController>().logout(),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          child: Icon(Icons.logout_rounded,
                              color: AppTheme.corTextoSecundario, size: 20),
                        ),
                      ),
                    ),
                  ]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 14),
              child: Text('Serviços',
                  style: GoogleFonts.playfairDisplay(
                      color: AppTheme.corTexto,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3)),
            ),
          ),
          if (ctrl.carregandoServicos)
            const SliverToBoxAdapter(
                child: Center(
                    child: Padding(
                        padding: EdgeInsets.all(28),
                        child: CircularProgressIndicator())))
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final s = ctrl.servicos[i];
                    return GestureDetector(
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChangeNotifierProvider.value(
                                value: ctrl, child: AgendarScreen(servico: s)),
                          )),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceElev,
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: cor.withValues(alpha: 0.15)),
                        ),
                        padding: const EdgeInsets.all(18),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                    color: cor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10)),
                                child: Icon(Icons.content_cut_rounded,
                                    color: cor, size: 20),
                              ),
                              Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s['nome'],
                                        style: GoogleFonts.inter(
                                            color: AppTheme.corTexto,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Text(
                                        'R\$ ${double.parse(s['preco'].toString()).toStringAsFixed(2)}',
                                        style: GoogleFonts.inter(
                                            color: cor,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13)),
                                    Text('${s['duracao_min']} min',
                                        style: GoogleFonts.inter(
                                            color: AppTheme.corTextoSecundario,
                                            fontSize: 11)),
                                  ]),
                            ]),
                      ),
                    );
                  },
                  childCount: ctrl.servicos.length,
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 14),
              child: Text('Profissionais',
                  style: GoogleFonts.playfairDisplay(
                      color: AppTheme.corTexto,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3)),
            ),
          ),
          if (ctrl.carregandoColaboradores)
            const SliverToBoxAdapter(
                child: Center(child: CircularProgressIndicator()))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final c = ctrl.colaboradores[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                          color: AppTheme.surfaceElev,
                          borderRadius: BorderRadius.circular(14)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: cor.withValues(alpha: 0.2),
                          child: Text(c['nome'][0].toUpperCase(),
                              style: GoogleFonts.playfairDisplay(
                                  color: cor, fontWeight: FontWeight.w700)),
                        ),
                        title: Text(c['nome'],
                            style: GoogleFonts.inter(
                                color: AppTheme.corTexto,
                                fontWeight: FontWeight.w600)),
                        trailing:
                            Icon(Icons.arrow_forward_ios, color: cor, size: 16),
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChangeNotifierProvider.value(
                                  value: ctrl,
                                  child: AgendarScreen(colaborador: c)),
                            )),
                      ),
                    );
                  },
                  childCount: ctrl.colaboradores.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
