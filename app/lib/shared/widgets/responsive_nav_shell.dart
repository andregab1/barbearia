// ==========================================
// WIDGET: Shell de navegação responsivo
// Web (>=900px): menu lateral fixo, estilo painel/dashboard
// Mobile (<900px): menu inferior, como já era antes
// ==========================================
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class NavShellItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const NavShellItem({required this.icon, required this.activeIcon, required this.label});
}

class ResponsiveNavShell extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<NavShellItem> items;
  final Widget body;
  final String? tituloMarca;

  const ResponsiveNavShell({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    required this.body,
    this.tituloMarca,
  });

  static const double _breakpoint = 900;

  @override
  Widget build(BuildContext context) {
    final larguraTela = MediaQuery.sizeOf(context).width;
    final isWeb = larguraTela >= _breakpoint;

    // ------------------------------------------
    // MOBILE: igual era antes — menu inferior
    // ------------------------------------------
    if (!isWeb) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: body,
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: onTap,
          items: items
              .map((i) => BottomNavigationBarItem(
                    icon: Icon(i.icon),
                    activeIcon: Icon(i.activeIcon),
                    label: i.label,
                  ))
              .toList(),
        ),
      );
    }

    // ------------------------------------------
    // WEB: menu lateral fixo (estilo dashboard)
    // ------------------------------------------
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 240,
            decoration: BoxDecoration(
              color: AppTheme.corCard,
              border: Border(right: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (tituloMarca != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                      child: Row(children: [
                        Icon(Icons.content_cut, size: 20, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 10),
                        Text(tituloMarca!,
                            style: TextStyle(color: AppTheme.corTexto, fontSize: 18, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  for (int i = 0; i < items.length; i++) _buildItemSidebar(context, i),
                ],
              ),
            ),
          ),
          Expanded(child: SafeArea(child: body)),
        ],
      ),
    );
  }

  Widget _buildItemSidebar(BuildContext context, int i) {
    final item = items[i];
    final selecionado = i == currentIndex;
    final cor = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onTap(i),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: selecionado ? cor.withOpacity(0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              Icon(selecionado ? item.activeIcon : item.icon,
                  size: 20, color: selecionado ? cor : AppTheme.corTextoSecundario),
              const SizedBox(width: 12),
              Text(item.label, style: TextStyle(
                color: selecionado ? AppTheme.corTexto : AppTheme.corTextoSecundario,
                fontWeight: selecionado ? FontWeight.w600 : FontWeight.w400,
                fontSize: 14,
              )),
            ]),
          ),
        ),
      ),
    );
  }
}