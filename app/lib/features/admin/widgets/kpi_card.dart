import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class KpiCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const KpiCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final surf = Theme.of(context).colorScheme.surface;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color:
                Theme.of(context).colorScheme.outline.withValues(alpha: 0.08)),
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value,
                style: GoogleFonts.inter(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                )),
            const SizedBox(height: 2),
            Text(label,
                style: GoogleFonts.inter(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                )),
          ],
        )),
      ]),
    );
  }
}
