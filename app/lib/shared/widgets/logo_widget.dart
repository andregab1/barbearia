// ==========================================
// WIDGET: Logo da barbearia
// Suporta: /path/local, data:base64, https://url
// ==========================================
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

class LogoWidget extends StatelessWidget {
  final String? logoUrl;
  final double  size;
  final BoxFit  fit;
  final Widget? placeholder;

  const LogoWidget({
    super.key,
    required this.logoUrl,
    this.size        = 60,
    this.fit         = BoxFit.cover,
    this.placeholder,
  });

  Widget _placeholder() =>
      placeholder ?? Icon(Icons.content_cut, size: size * 0.5, color: Colors.grey);

  @override
  Widget build(BuildContext context) {
    if (logoUrl == null || logoUrl!.isEmpty) return _placeholder();

    // Arquivo local (path absoluto)
    if (logoUrl!.startsWith('/') || logoUrl!.startsWith('file://')) {
      final path = logoUrl!.startsWith('file://') ? logoUrl!.substring(7) : logoUrl!;
      return Image.file(
        File(path), width: size, height: size, fit: fit,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }

    // Base64 (data:image/...)
    if (logoUrl!.startsWith('data:image')) {
      try {
        final bytes = base64Decode(logoUrl!.split(',').last);
        return Image.memory(
          bytes, width: size, height: size, fit: fit,
          errorBuilder: (_, __, ___) => _placeholder(),
        );
      } catch (_) {
        return _placeholder();
      }
    }

    // URL normal (https://...)
    return Image.network(
      logoUrl!, width: size, height: size, fit: fit,
      errorBuilder: (_, __, ___) => _placeholder(),
    );
  }
}