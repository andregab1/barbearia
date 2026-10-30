import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../features/auth/controllers/auth_controller.dart';
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
    final auth = context.watch<AuthController>();
    return ResponsiveNavShell(
      currentIndex: _paginaAtual,
      onTap: (i) => setState(() => _paginaAtual = i),
      items: _itens,
      tituloMarca: 'GetCutt',
      userName: auth.nomeUsuario ?? 'Cliente',
      userRole: 'Cliente',
      onLogout: auth.logout,
      onProfile: () => setState(() => _paginaAtual = _itens.length - 1),
      body: _paginas[_paginaAtual],
    );
  }
}
