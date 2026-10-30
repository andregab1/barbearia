// ==========================================
// WIDGET: Logo oficial da GetCutt
// O endereço recebido continua na API do widget por compatibilidade, mas a
// marca exibida no sistema é sempre o asset oficial versionado.
// ==========================================
import 'dart:convert';

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class LogoWidget extends StatelessWidget {
  final String? logoUrl;
  final double size;
  final BoxFit fit;
  final Widget? placeholder;

  const LogoWidget({
    super.key,
    required this.logoUrl,
    this.size = 60,
    this.fit = BoxFit.cover,
    this.placeholder,
  });

  Widget _placeholder() => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppTheme.gold.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(size * 0.22),
        ),
        child: Icon(
          Icons.content_cut_rounded,
          size: size * 0.45,
          color: AppTheme.gold,
        ),
      );

  Widget _officialLogo(BuildContext context) => Image.asset(
        'assets/logo_getcutt_mark.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => _placeholder(),
      );

  @override
  Widget build(BuildContext context) {
    final raw = logoUrl?.trim();
    if (raw != null && raw.startsWith('data:image')) {
      try {
        return ClipRRect(
          borderRadius: BorderRadius.circular(size * .22),
          child: Image.memory(
            base64Decode(raw.split(',').last),
            width: size,
            height: size,
            fit: fit,
            errorBuilder: (_, __, ___) => _officialLogo(context),
          ),
        );
      } catch (_) {}
    }
    if (raw != null &&
        (raw.startsWith('http://') || raw.startsWith('https://'))) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * .22),
        child: Image.network(
          raw,
          width: size,
          height: size,
          fit: fit,
          errorBuilder: (_, __, ___) => _officialLogo(context),
        ),
      );
    }
    return _officialLogo(context);
  }
}

class OfficialLogo extends StatelessWidget {
  final double width;
  final double height;
  final bool showMark;

  const OfficialLogo({super.key, this.width = 132, this.height = 54, this.showMark = true});

  @override
  Widget build(BuildContext context) {
    final wordmark = Theme.of(context).brightness == Brightness.dark
        ? 'assets/logo_getcutt_wordmark_light.png'
        : 'assets/logo_getcutt_wordmark.png';
    if (!showMark) {
      return SizedBox(
        width: width,
        height: height,
        child: Image.asset(
          wordmark,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      );
    }

    final markSize = (height * 0.82).clamp(24.0, width * 0.34);
    final gap = (width * 0.055).clamp(6.0, 12.0);
    return SizedBox(
      width: width,
      height: height,
      child: Row(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: markSize,
            height: markSize,
            child: Image.asset(
              'assets/logo_getcutt_mark.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
          SizedBox(width: gap),
          Expanded(
            child: Image.asset(
              wordmark,
              height: height * 0.62,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ],
      ),
    );
  }
}
