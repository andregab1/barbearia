import 'package:flutter/material.dart';
import '../layout/responsive.dart';
import 'premium_ui.dart';
import 'logo_widget.dart';

class NavShellItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const NavShellItem({required this.icon, required this.activeIcon, required this.label});
}

class ResponsiveNavShell extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<NavShellItem> items;
  final Widget body;
  final String? tituloMarca;
  final String? userName;
  final String? userRole;
  final VoidCallback? onLogout;
  final VoidCallback? onProfile;

  const ResponsiveNavShell({super.key, required this.currentIndex, required this.onTap, required this.items, required this.body, this.tituloMarca, this.userName, this.userRole, this.onLogout, this.onProfile});

  @override
  State<ResponsiveNavShell> createState() => _ResponsiveNavShellState();
}

class _ResponsiveNavShellState extends State<ResponsiveNavShell> {
  bool _userMenuOpen = false;

  int get currentIndex => widget.currentIndex;
  ValueChanged<int> get onTap => widget.onTap;
  List<NavShellItem> get items => widget.items;
  Widget get body => widget.body;
  String? get tituloMarca => widget.tituloMarca;
  String? get userName => widget.userName;
  String? get userRole => widget.userRole;
  VoidCallback? get onLogout => widget.onLogout;
  VoidCallback? get onProfile => widget.onProfile;

  @override
  Widget build(BuildContext context) {
    if (!ResponsiveBreakpoints.isExpanded(context)) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: onTap,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          destinations: items.map((item) => NavigationDestination(icon: Icon(item.icon), selectedIcon: Icon(item.activeIcon), label: item.label, tooltip: item.label)).toList(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: PremiumColors.background,
      body: Column(children: [
        _buildTopBar(context),
        Expanded(child: body),
      ]),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Material(
      color: PremiumColors.surface,
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(builder: (context, constraints) {
          final width = constraints.maxWidth;
          final visibleItems = items.asMap().entries
              .where((entry) => entry.value.label != 'Perfil')
              .toList();
          final compactBrand = width < 1120;

          return Container(
            height: 70,
            padding: EdgeInsets.symmetric(horizontal: width < 1120 ? 18 : 32),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: PremiumColors.border))),
            child: Row(children: [
              if (tituloMarca != null) ...[
                OfficialLogo(width: compactBrand ? 142 : 182, height: 58),
                SizedBox(width: compactBrand ? 18 : 46),
              ],
              Expanded(child: Row(children: [for (final entry in visibleItems) _buildTopItem(context, entry.key)])),
              if (userName != null) _buildUserMenu(context),
            ]),
          );
        }),
      ),
    );
  }

  Widget _buildTopItem(BuildContext context, int index) {
    final item = items[index];
    final selected = index == currentIndex;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => onTap(index),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minWidth: 86, minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: selected ? Colors.white.withValues(alpha: .045) : Colors.transparent, borderRadius: BorderRadius.circular(10), border: Border(bottom: BorderSide(color: selected ? PremiumColors.gold : Colors.transparent, width: 2))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(selected ? item.activeIcon : item.icon, size: 19, color: selected ? PremiumColors.gold : PremiumColors.textMuted),
            const SizedBox(width: 8),
            Text(item.label, style: TextStyle(color: selected ? PremiumColors.textPrimary : PremiumColors.textSecondary, fontWeight: selected ? FontWeight.w600 : FontWeight.w400, fontSize: 13)),
          ]),
        ),
      ),
    );
  }

  Widget _buildUserMenu(BuildContext context) {
    final name = userName!.isEmpty ? '?' : userName![0].toUpperCase();
    return PopupMenuButton<String>(
      tooltip: 'Opções da conta',
      onOpened: () => setState(() => _userMenuOpen = true),
      onCanceled: () => setState(() => _userMenuOpen = false),
      onSelected: (value) {
        setState(() => _userMenuOpen = false);
        if (value == 'profile') onProfile?.call();
        if (value == 'logout') onLogout?.call();
      },
      color: PremiumColors.surfaceSecondary,
      itemBuilder: (_) => [
        PopupMenuItem<String>(enabled: false, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(userName!, style: const TextStyle(color: PremiumColors.textPrimary, fontWeight: FontWeight.w600)), Text(userRole ?? '', style: const TextStyle(color: PremiumColors.textMuted, fontSize: 12))])),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(value: 'profile', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.person_outline_rounded, color: PremiumColors.gold), title: Text('Meu perfil'))),
        const PopupMenuItem<String>(value: 'logout', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.logout_rounded, color: PremiumColors.error), title: Text('Sair da conta'))),
      ],
      child: Row(children: [
        CircleAvatar(radius: 18, backgroundColor: PremiumColors.gold.withValues(alpha: .14), child: Text(name, style: const TextStyle(color: PremiumColors.gold, fontWeight: FontWeight.w700))),
        const SizedBox(width: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 142),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(userName!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: PremiumColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)), Text(userRole ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: PremiumColors.textMuted, fontSize: 11))]),
        ),
        const SizedBox(width: 8),
        Icon(_userMenuOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: PremiumColors.textMuted, size: 18),
      ]),
    );
  }
}
