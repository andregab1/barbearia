import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/barbearia_theme_service.dart';
import '../../../shared/layout/responsive.dart';
import '../../../shared/widgets/logo_widget.dart';

class AuthLayout extends StatelessWidget {
  final String eyebrow, title, subtitle, activeRoute;
  final Widget form;
  final BarbeariaThemeService themeService;
  final List<Widget> benefits;

  const AuthLayout(
      {super.key,
      required this.eyebrow,
      required this.title,
      required this.subtitle,
      required this.activeRoute,
      required this.form,
      required this.themeService,
      required this.benefits});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = ResponsiveBreakpoints.isExpanded(context);
    final border = theme.dividerColor.withValues(alpha: 0.55);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
          child: Column(children: [
        _Header(activeRoute: activeRoute, themeService: themeService),
        Expanded(
            child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                    isWide ? 56 : 20, isWide ? 36 : 24, isWide ? 56 : 20, 40),
                child: Center(
                    child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1440),
                  child: SizedBox(
                      width: double.infinity,
                      child: isWide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                  Expanded(
                                      flex: 5,
                                      child: _Intro(
                                          eyebrow: eyebrow,
                                          title: title,
                                          subtitle: subtitle,
                                          benefits: benefits,
                                          themeService: themeService)),
                                  const SizedBox(width: 64),
                                  Expanded(
                                      flex: 4,
                                      child: _FormCard(
                                          form: form, border: border)),
                                ])
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                  _Intro(
                                      eyebrow: eyebrow,
                                      title: title,
                                      subtitle: subtitle,
                                      benefits: benefits,
                                      themeService: themeService,
                                      compact: true),
                                  const SizedBox(height: 24),
                                  _FormCard(form: form, border: border),
                                ])),
                ))))
      ])),
    );
  }
}

class _Header extends StatelessWidget {
  final String activeRoute;
  final BarbeariaThemeService themeService;
  const _Header({required this.activeRoute, required this.themeService});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLogin = activeRoute == AppConstants.routeLogin;
    final compact = MediaQuery.sizeOf(context).width < 480;
    return Container(
      decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
              bottom: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.45)))),
      padding:
          EdgeInsets.symmetric(horizontal: compact ? 12 : 28, vertical: 14),
      child: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1440),
              child: SizedBox(
                  width: double.infinity,
                  child: Row(children: [
                    Expanded(
                        child: Row(children: [
                      const OfficialLogo(width: 132, height: 48),
                    ])),
                    if (compact)
                      IconButton(
                          tooltip: 'Inicio',
                          onPressed: () => context.go('/'),
                          icon: const Icon(Icons.home_outlined, size: 20))
                    else
                      TextButton.icon(
                          onPressed: () => context.go('/'),
                          icon: const Icon(Icons.home_outlined, size: 18),
                          label: const Text('Inicio')),
                    const SizedBox(width: 4),
                    if (compact)
                      IconButton(
                          tooltip: isLogin ? 'Criar conta' : 'Entrar',
                          onPressed: () => context.go(isLogin
                              ? AppConstants.routeCadastro
                              : AppConstants.routeLogin),
                          icon: Icon(isLogin
                              ? Icons.person_add_alt_1_outlined
                              : Icons.login_outlined))
                    else
                      isLogin
                          ? FilledButton(
                              onPressed: () =>
                                  context.go(AppConstants.routeCadastro),
                              child: const Text('Criar conta'))
                          : OutlinedButton(
                              onPressed: () =>
                                  context.go(AppConstants.routeLogin),
                              child: const Text('Entrar')),
                  ])))),
    );
  }
}

class _Intro extends StatelessWidget {
  final String eyebrow, title, subtitle;
  final List<Widget> benefits;
  final BarbeariaThemeService themeService;
  final bool compact;
  const _Intro(
      {required this.eyebrow,
      required this.title,
      required this.subtitle,
      required this.benefits,
      required this.themeService,
      this.compact = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Padding(
        padding: EdgeInsets.only(top: compact ? 0 : 44),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16)),
              child: Icon(Icons.content_cut_rounded, color: primary, size: 28)),
          const SizedBox(height: 28),
          Text(eyebrow.toUpperCase(),
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: primary)),
          const SizedBox(height: 12),
          Text(title,
              style: GoogleFonts.inter(
                  fontSize: compact ? 32 : 48,
                  height: 1.08,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.7)),
          const SizedBox(height: 18),
          ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Text(subtitle,
                  style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.55))),
          if (!compact) ...[const SizedBox(height: 36), ...benefits],
        ]));
  }
}

class _FormCard extends StatelessWidget {
  final Widget form;
  final Color border;
  const _FormCard({required this.form, required this.border});
  @override
  Widget build(BuildContext context) => Container(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 480 ? 20 : 28),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 24,
                offset: const Offset(0, 10))
          ]),
      child: form);
}

class AuthBenefit extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const AuthBenefit(
      {super.key,
      required this.icon,
      required this.title,
      required this.subtitle});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: theme.colorScheme.primary, size: 22),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(subtitle, style: theme.textTheme.bodyMedium)
              ])),
        ]));
  }
}

InputDecoration authInputDecoration(
        BuildContext context, String label, IconData icon,
        {String? hint, Widget? suffixIcon}) =>
    InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor:
            Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.55));
