import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PremiumColors {
  static const background = Color(0xFF0D0F10);
  static const surface = Color(0xFF151718);
  static const surfaceSecondary = Color(0xFF1A1D1F);
  static const card = Color(0xFF1A1D1F);
  static const cardHover = Color(0xFF202325);
  static const gold = Color(0xFFD59B32);
  static const goldBright = Color(0xFFE2AD4D);
  static const textPrimary = Color(0xFFF2F2F0);
  static const textSecondary = Color(0xFFA7A7A3);
  static const textMuted = Color(0xFF737572);
  static const border = Color(0x14FFFFFF);
  static const success = Color(0xFF70B77E);
  static const error = Color(0xFFD76565);
}

class PremiumPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final List<Widget> actions;
  final EdgeInsetsGeometry? padding;

  const PremiumPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.actions = const [],
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return ColoredBox(
      color: PremiumColors.background,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 16 : 32,
                compact ? 20 : 28,
                compact ? 16 : 32,
                20,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1440),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.playfairDisplay(
                              color: PremiumColors.textPrimary,
                              fontSize: compact ? 28 : 36,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            subtitle,
                            style: GoogleFonts.inter(
                              color: PremiumColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...actions,
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: padding ??
                    EdgeInsets.fromLTRB(
                      compact ? 16 : 32,
                      0,
                      compact ? 16 : 32,
                      compact ? 20 : 32,
                    ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1440),
                    child: child,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
