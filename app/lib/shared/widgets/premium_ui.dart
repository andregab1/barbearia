import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/barbearia_theme_service.dart';
import '../layout/responsive.dart';

class PremiumColors {
  static Color get background =>
      AppTheme.modoClaro ? AppTheme.canvasLight : AppTheme.black;
  static Color get surface =>
      AppTheme.modoClaro ? AppTheme.surfaceLight : AppTheme.surface;
  static Color get surfaceSecondary =>
      AppTheme.modoClaro ? AppTheme.corCard : AppTheme.surfaceElev;
  static Color get card => AppTheme.corCard;
  static Color get cardHover =>
      AppTheme.modoClaro ? AppTheme.surfaceLight : const Color(0xFF2C2522);
  static Color get gold => AppTheme.gold;
  static Color get goldBright => AppTheme.goldLight;
  static Color get textPrimary => AppTheme.corTexto;
  static Color get textSecondary => AppTheme.corTextoSecundario;
  static Color get textMuted => AppTheme.modoClaro
      ? const Color(0xFFA8A29E)
      : const Color(0xFF77706C);
  static Color get border => AppTheme.modoClaro
      ? const Color(0xFFE7E5E4)
      : const Color(0x2639312E);
  static const success = Color(0xFF70B77E);
  static const error = Color(0xFFD76565);
}

class PremiumPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final List<Widget> actions;
  final EdgeInsetsGeometry? padding;
  final double? headingFontSize;
  final double? horizontalPadding;

  const PremiumPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.actions = const [],
    this.padding,
    this.headingFontSize,
    this.horizontalPadding,
  });

  @override
  Widget build(BuildContext context) {
    context.watch<BarbeariaThemeService>();
    final compact = ResponsiveBreakpoints.isCompact(context);
    final pageHorizontalPadding = horizontalPadding ??
        responsivePageHorizontalPadding(MediaQuery.sizeOf(context).width);
    return DefaultTextStyle.merge(
      style: TextStyle(decoration: TextDecoration.none),
      child: ColoredBox(
        color: PremiumColors.background,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  0,
                  compact ? 20 : 28,
                  0,
                  20,
                ),
                child: ResponsivePagePadding(
                  horizontalPadding: pageHorizontalPadding,
                  child: PremiumPageHeader(
                    title: title,
                    subtitle: subtitle,
                    actions: actions,
                    headingFontSize: headingFontSize,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: padding ??
                      EdgeInsets.fromLTRB(
                        0,
                        0,
                        0,
                        compact ? 20 : 32,
                      ),
                  child: ResponsivePagePadding(
                    horizontalPadding: pageHorizontalPadding,
                    child: SizedBox(width: double.infinity, child: child),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PremiumPageFrame extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final double topPadding;
  final double bottomPadding;

  const PremiumPageFrame({
    super.key,
    required this.child,
    this.maxWidth = 1440,
    this.topPadding = 28,
    this.bottomPadding = 28,
  });

  @override
  Widget build(BuildContext context) {
    context.watch<BarbeariaThemeService>();
    final horizontal =
        responsivePageHorizontalPadding(MediaQuery.sizeOf(context).width);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final frameWidth = availableWidth.clamp(0.0, maxWidth).toDouble();
        final availableHeight = constraints.hasBoundedHeight
            ? (constraints.maxHeight - topPadding - bottomPadding)
                .clamp(0.0, double.infinity)
                .toDouble()
            : 0.0;
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: frameWidth,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: availableHeight),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  topPadding,
                  horizontal,
                  bottomPadding,
                ),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

class PremiumPageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> actions;
  final double? headingFontSize;

  const PremiumPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.actions = const [],
    this.headingFontSize,
  });

  @override
  Widget build(BuildContext context) {
    final compact = ResponsiveBreakpoints.isCompact(context);
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            color: PremiumColors.textPrimary,
            fontSize: headingFontSize ?? 28,
            fontWeight: FontWeight.w600,
            height: 1.2,
            decoration: TextDecoration.none,
          ),
        ),
        SizedBox(height: 5),
        Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: PremiumColors.textSecondary,
            fontSize: 13,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );

    final pageActions = Align(
      alignment: Alignment.topRight,
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        runSpacing: 8,
        children: actions,
      ),
    );

    return compact
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading,
              if (actions.isNotEmpty) ...[
                SizedBox(height: 16),
                pageActions,
              ],
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: heading),
              if (actions.isNotEmpty) ...[
                SizedBox(width: 16),
                Expanded(child: pageActions),
              ],
            ],
          );
  }
}

class PremiumSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  const PremiumSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    context.watch<BarbeariaThemeService>();
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? PremiumColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PremiumColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class PremiumEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const PremiumEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: PremiumColors.gold.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: PremiumColors.gold, size: 28),
              ),
              SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: PremiumColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: PremiumColors.textMuted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
}

class PremiumLoadingState extends StatelessWidget {
  final String label;
  const PremiumLoadingState({super.key, required this.label});

  @override
  Widget build(BuildContext context) => Semantics(
        label: label,
        liveRegion: true,
          child: Center(
          child: CircularProgressIndicator(
            color: PremiumColors.gold,
            strokeWidth: 2,
          ),
        ),
      );
}

class PremiumStatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const PremiumStatusBadge({
    super.key,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

String premiumCurrency(dynamic value) {
  final amount = double.tryParse(value.toString()) ?? 0;
  return 'R\$ ${amount.toStringAsFixed(2).replaceAll('.', ',')}';
}
