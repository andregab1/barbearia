// ==========================================
// WIDGET: Modal padronizado estilo SaaS premium
// Inspirado em Linear, Stripe, GitHub, Vercel, Notion
// ==========================================
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppModalSize { small, medium, large, confirm }

class AppModal extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget child;
  final AppModalSize size;
  final List<Widget>? actions;
  final bool showCloseButton;

  const AppModal({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    required this.child,
    this.size = AppModalSize.medium,
    this.actions,
    this.showCloseButton = true,
  });

  double get _maxWidth {
    switch (size) {
      case AppModalSize.confirm:
        return 420;
      case AppModalSize.small:
        return 600;
      case AppModalSize.medium:
        return 700;
      case AppModalSize.large:
        return 900;
    }
  }

  /// Abre o modal com animação fade + scale
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    String? subtitle,
    IconData? icon,
    required Widget child,
    AppModalSize size = AppModalSize.medium,
    List<Widget>? actions,
    bool showCloseButton = true,
    bool barrierDismissible = true,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'Modal',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, secondaryAnim, _) {
        final curvedAnim =
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.95, end: 1.0).animate(curvedAnim),
          child: FadeTransition(
            opacity: curvedAnim,
            child: AppModal(
              title: title,
              subtitle: subtitle,
              icon: icon,
              size: size,
              actions: actions,
              showCloseButton: showCloseButton,
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final surf = Theme.of(context).colorScheme.surface;
    final cor = Theme.of(context).colorScheme.primary;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final onSurfVar = Theme.of(context).colorScheme.onSurfaceVariant;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxWidth: _maxWidth,
            maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: surf,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
                BoxShadow(
                  color: cor.withValues(alpha: 0.05),
                  blurRadius: 60,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(children: [
                      if (icon != null) ...[
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: cor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(icon, color: cor, size: 20),
                        ),
                        const SizedBox(width: 14),
                      ],
                      Expanded(
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: GoogleFonts.inter(
                                color: onSurf,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              )),
                          if (subtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(subtitle!,
                                style: GoogleFonts.inter(
                                  color: onSurfVar,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                )),
                          ],
                        ],
                      )),
                      if (showCloseButton)
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.close, color: onSurfVar, size: 20),
                          style: IconButton.styleFrom(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 24),
                    // Divider
                    Container(
                        height: 1,
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.1)),
                    const SizedBox(height: 24),
                    // Content
                    child,
                    // Actions
                    if (actions != null && actions!.isNotEmpty) ...[
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: actions!,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// BOTÕES PADRONIZADOS para modais
// ==========================================
class AppModalCancelButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  const AppModalCancelButton(
      {super.key, this.onPressed, this.label = 'Cancelar'});

  @override
  Widget build(BuildContext context) {
    final onSurfVar = Theme.of(context).colorScheme.onSurfaceVariant;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onPressed ?? () => Navigator.pop(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.2)),
          ),
          child: Text(label,
              style: GoogleFonts.inter(
                color: onSurfVar,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              )),
        ),
      ),
    );
  }
}

class AppModalPrimaryButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final bool isLoading;
  const AppModalPrimaryButton({
    super.key,
    this.onPressed,
    required this.label,
    this.icon,
    this.isLoading = false,
  });

  @override
  State<AppModalPrimaryButton> createState() => _AppModalPrimaryButtonState();
}

class _AppModalPrimaryButtonState extends State<AppModalPrimaryButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.primary;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          transform:
              _hover ? (Matrix4.identity()..scale(1.02)) : Matrix4.identity(),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.onPressed != null ? cor : cor.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
            boxShadow: _hover && widget.onPressed != null
                ? [
                    BoxShadow(
                        color: cor.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4)),
                  ]
                : null,
          ),
          child: widget.isLoading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.onPrimary))
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon,
                        size: 16,
                        color: Theme.of(context).colorScheme.onPrimary),
                    const SizedBox(width: 8),
                  ],
                  Text(widget.label,
                      style: GoogleFonts.inter(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      )),
                ]),
        ),
      ),
    );
  }
}

// ==========================================
// INPUT PADRONIZADO para modais
// ==========================================
class AppModalInput extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int maxLines;
  final String? Function(String?)? validator;
  final String? initialValue;

  const AppModalInput({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.obscureText = false,
    this.maxLines = 1,
    this.validator,
    this.initialValue,
  });

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.primary;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final onSurfVar = Theme.of(context).colorScheme.onSurfaceVariant;

    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: maxLines,
      validator: validator,
      style: GoogleFonts.inter(color: onSurf, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.inter(color: onSurfVar, fontSize: 14),
        hintStyle: GoogleFonts.inter(
            color: onSurfVar.withValues(alpha: 0.5), fontSize: 14),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: onSurfVar, size: 18)
            : null,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.3),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: Theme.of(context)
                  .colorScheme
                  .outline
                  .withValues(alpha: 0.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: Theme.of(context)
                  .colorScheme
                  .outline
                  .withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD45C5C)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD45C5C), width: 1.5),
        ),
      ),
    );
  }
}
