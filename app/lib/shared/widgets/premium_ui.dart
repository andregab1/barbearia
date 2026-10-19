import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../layout/responsive.dart';

class PremiumColors {
  static const background = Color(0xFF100B0B);
  static const surface = Color(0xFF181514);
  static const surfaceSecondary = Color(0xFF231E1C);
  static const card = Color(0xFF231E1C);
  static const cardHover = Color(0xFF2C2522);
  static const gold = Color(0xFFFFD000);
  static const goldBright = Color(0xFFFFDE4D);
  static const textPrimary = Color(0xFFF4EFEB);
  static const textSecondary = Color(0xFFA8A19D);
  static const textMuted = Color(0xFF77706C);
  static const border = Color(0x2639312E);
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
    final compact = ResponsiveBreakpoints.isCompact(context);
    return DefaultTextStyle.merge(
      style: const TextStyle(decoration: TextDecoration.none),
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
                  horizontalPadding: horizontalPadding,
                  child: compact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _pageHeading(context),
                            if (actions.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              _pageActions(),
                            ],
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _pageHeading(context)),
                            if (actions.isNotEmpty) ...[
                              const SizedBox(width: 16),
                              Expanded(child: _pageActions()),
                            ],
                          ],
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
                    horizontalPadding: horizontalPadding,
                    child: child,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pageHeading(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: PremiumColors.textPrimary,
              fontSize: headingFontSize ??
                  (ResponsiveBreakpoints.isCompact(context) ? 28 : 36),
              fontWeight: FontWeight.w600,
              height: 1.2,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 5),
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

  Widget _pageActions() => Align(
        alignment: Alignment.topRight,
        child: Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: actions,
        ),
      );
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
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? PremiumColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PremiumColors.border),
        ),
        child: child,
      );
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
          padding: const EdgeInsets.all(32),
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
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: PremiumColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
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
        child: const Center(
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
