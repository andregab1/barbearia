import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ChartCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const ChartCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final surf = Theme.of(context).colorScheme.surface;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color:
                Theme.of(context).colorScheme.outline.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(title,
                style: GoogleFonts.inter(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                )),
            if (subtitle != null)
              Text(subtitle!,
                  style: GoogleFonts.inter(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  )),
          ]),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}
