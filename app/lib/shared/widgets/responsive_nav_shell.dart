import 'package:flutter/material.dart';
import 'premium_ui.dart';

class NavShellItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const NavShellItem(
      {required this.icon, required this.activeIcon, required this.label});
}

class ResponsiveNavShell extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<NavShellItem> items;
  final Widget body;
  final String? tituloMarca;
  final String? userName;
  final String? userRole;
  final VoidCallback? onLogout;

  const ResponsiveNavShell({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    required this.body,
    this.tituloMarca,
    this.userName,
    this.userRole,
    this.onLogout,
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
        bottomNavigationBar: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: onTap,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          destinations: items
              .map((item) => NavigationDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.activeIcon),
                    label: item.label,
                    tooltip: item.label,
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
            width: larguraTela >= 1200 ? 232 : 220,
            decoration: const BoxDecoration(
              color: PremiumColors.surface,
              border: Border(
                right: BorderSide(color: PremiumColors.border),
              ),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (tituloMarca != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 26, 20, 36),
                      child: Row(children: [
                        const Icon(
                          Icons.content_cut_rounded,
                          size: 23,
                          color: PremiumColors.gold,
                        ),
                        const SizedBox(width: 10),
                        Text(tituloMarca!,
                            style: const TextStyle(
                              color: PremiumColors.textPrimary,
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            )),
                      ]),
                    ),
                  for (int i = 0; i < items.length; i++)
                    _buildItemSidebar(context, i),
                  const Spacer(),
                  if (userName != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
                      child: InkWell(
                        onTap: onLogout,
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor:
                                  PremiumColors.gold.withValues(alpha: .14),
                              child: Text(
                                  userName!.isEmpty
                                      ? '?'
                                      : userName![0].toUpperCase(),
                                  style: const TextStyle(
                                      color: PremiumColors.gold,
                                      fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(userName!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: PremiumColors.textPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600)),
                                  Text(userRole ?? '',
                                      style: const TextStyle(
                                          color: PremiumColors.textMuted,
                                          fontSize: 11)),
                                ])),
                            if (onLogout != null)
                              const Icon(Icons.logout_rounded,
                                  size: 17, color: PremiumColors.textMuted),
                          ]),
                        ),
                      ),
                    ),
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onTap(i),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: selecionado
                  ? Colors.white.withValues(alpha: 0.045)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border(
                  left: BorderSide(
                      color:
                          selecionado ? PremiumColors.gold : Colors.transparent,
                      width: 2)),
            ),
            child: Row(children: [
              Icon(selecionado ? item.activeIcon : item.icon,
                  size: 21,
                  color: selecionado
                      ? PremiumColors.gold
                      : PremiumColors.textMuted),
              const SizedBox(width: 13),
              Text(item.label,
                  style: TextStyle(
                    color: selecionado
                        ? PremiumColors.textPrimary
                        : PremiumColors.textSecondary,
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
