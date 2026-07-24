import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/controllers/auth_controller.dart';

class MenuDrawer extends StatelessWidget {
  const MenuDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final nome = auth.nomeUsuario ?? '';
    final role = auth.role;

    return Drawer(
      backgroundColor: AppTheme.corFundoSecundario,
      child: SafeArea(
        child: Column(children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)),
            accountName: Text(nome,
                style: TextStyle(color: AppTheme.corTexto, fontWeight: FontWeight.bold)),
            accountEmail: Text(role,
                style: TextStyle(color: AppTheme.corTextoSecundario, fontSize: 12)),
            currentAccountPicture: CircleAvatar(
              backgroundColor:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
              child: Text(
                nome.isNotEmpty ? nome[0].toUpperCase() : '?',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 22),
              ),
            ),
          ),
          if (role == 'admin' || role == 'barbeiro')
            ListTile(
              leading: Icon(Icons.calendar_today,
                  color: Theme.of(context).colorScheme.primary),
              title: Text('Agenda', style: TextStyle(color: AppTheme.corTexto)),
              onTap: () => Navigator.pop(context),
            ),
          ListTile(
            leading: Icon(Icons.person_outline,
                color: Theme.of(context).colorScheme.primary),
            title: Text('Perfil', style: TextStyle(color: AppTheme.corTexto)),
            onTap: () => Navigator.pop(context),
          ),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: AppTheme.corErro),
            title: const Text('Sair', style: TextStyle(color: AppTheme.corErro)),
            onTap: () {
              Navigator.pop(context);
              auth.logout();
            },
          ),
        ]),
      ),
    );
  }
}