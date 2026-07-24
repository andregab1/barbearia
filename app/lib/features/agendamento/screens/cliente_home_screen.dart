// ==========================================
// TELA: Home do Cliente
// RF04 - Cores dinâmicas em todo o app
// ==========================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/controllers/auth_controller.dart';
import '../controllers/agendamento_controller.dart';
import 'agendar_screen.dart';
import 'meus_agendamentos_screen.dart';
import 'historico_screen.dart';
import '../../../shared/widgets/perfil_screen.dart';

class ClienteHomeScreen extends StatefulWidget {
  const ClienteHomeScreen({super.key});

  @override
  State<ClienteHomeScreen> createState() => _ClienteHomeScreenState();
}

class _ClienteHomeScreenState extends State<ClienteHomeScreen> {
  int _paginaAtual = 0;

  final List<Widget> _paginas = const [
    _HomeTab(),
    MeusAgendamentosScreen(),
    HistoricoScreen(),
    PerfilScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _paginas[_paginaAtual],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _paginaAtual,
        onTap: (i) => setState(() => _paginaAtual = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined),           activeIcon: Icon(Icons.home),           label: 'Início'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month_outlined), activeIcon: Icon(Icons.calendar_month), label: 'Agenda'),
          BottomNavigationBarItem(icon: Icon(Icons.history_outlined),        activeIcon: Icon(Icons.history),        label: 'Histórico'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline),          activeIcon: Icon(Icons.person),         label: 'Perfil'),
        ],
      ),
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
      context.read<AgendamentoController>().carregarServicos();
      context.read<AgendamentoController>().carregarColaboradores();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AgendamentoController>();
    final auth = context.read<AuthController>();
    final cor  = Theme.of(context).colorScheme.primary;

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Olá, ${auth.nomeUsuario?.split(' ').first ?? 'Cliente'}! 👋',
                      style: TextStyle(color: AppTheme.corTextoSecundario, fontSize: 14)),
                  Text('O que vai ser hoje?',
                      style: TextStyle(color: AppTheme.corTexto, fontSize: 22, fontWeight: FontWeight.bold)),
                ]),
                IconButton(
                  icon: Icon(Icons.logout, color: AppTheme.corTextoSecundario),
                  onPressed: () => context.read<AuthController>().logout(),
                ),
              ]),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 28, 24, 12),
              child: Text('Serviços', style: TextStyle(color: AppTheme.corTexto, fontSize: 18, fontWeight: FontWeight.w600)),
            ),
          ),

          if (ctrl.carregandoServicos)
            SliverToBoxAdapter(child: Center(child: Padding(padding: const EdgeInsets.all(24), child: CircularProgressIndicator(color: cor))))
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, childAspectRatio: 1.4, crossAxisSpacing: 12, mainAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final s = ctrl.servicos[i];
                    return GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => ChangeNotifierProvider.value(value: ctrl, child: AgendarScreen(servico: s)),
                      )),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.corCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cor.withOpacity(0.3)),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Icon(Icons.content_cut, color: cor, size: 28),
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(s['nome'], style: TextStyle(color: AppTheme.corTexto, fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                              SizedBox(height: 2),
                              Text('R\$ ${double.parse(s['preco'].toString()).toStringAsFixed(2)}',
                                  style: TextStyle(color: cor, fontWeight: FontWeight.bold, fontSize: 13)),
                              Text('${s['duracao_min']} min', style: TextStyle(color: AppTheme.corTextoSecundario, fontSize: 11)),
                            ]),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: ctrl.servicos.length,
                ),
              ),
            ),

          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: Text('Profissionais', style: TextStyle(color: AppTheme.corTexto, fontSize: 18, fontWeight: FontWeight.w600)),
            ),
          ),

          if (ctrl.carregandoColaboradores)
            SliverToBoxAdapter(child: Center(child: CircularProgressIndicator(color: cor)))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final c = ctrl.colaboradores[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(color: AppTheme.corCard, borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: cor.withOpacity(0.2),
                          child: Text(c['nome'][0].toUpperCase(), style: TextStyle(color: cor, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(c['nome'], style: TextStyle(color: AppTheme.corTexto, fontWeight: FontWeight.w600)),
                        trailing: Icon(Icons.arrow_forward_ios, color: cor, size: 16),
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ChangeNotifierProvider.value(value: ctrl, child: AgendarScreen(colaborador: c)),
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