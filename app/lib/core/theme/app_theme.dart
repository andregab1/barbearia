// ==========================================
// THEME: Identidade visual do app
// Cores dinâmicas — adapta a claro/escuro
// ==========================================
import 'package:flutter/material.dart';

class AppTheme {
  // Modo atual — atualizado pelo BarbeariaThemeService
  static bool _modoClaro = false;
  static void setModo(bool claro) => _modoClaro = claro;

  // ==========================================
  // Cores dinâmicas (mudam com o tema)
  // ==========================================
  static Color get corFundo =>
      _modoClaro ? const Color(0xFFF5F5F5) : const Color(0xFF1A1A1A);
  static Color get corFundoSecundario =>
      _modoClaro ? const Color(0xFFEEEEEE) : const Color(0xFF2A2A2A);
  static Color get corCard =>
      _modoClaro ? Colors.white : const Color(0xFF2C2C2C);
  static Color get corTexto =>
      _modoClaro ? const Color(0xFF1A1A1A) : Colors.white;
  static Color get corTextoSecundario =>
      _modoClaro ? const Color(0xFF757575) : const Color(0xFF9E9E9E);

  // ==========================================
  // Cores fixas (não mudam com tema)
  // ==========================================
  static const Color corPrimaria = Color(0xFFC9A84C);
  static const Color corErro     = Color(0xFFCF6679);
  static const Color corSucesso  = Color(0xFF4CAF50);

  // ==========================================
  // Adapta cor primária para visibilidade
  // ==========================================
  static Color adaptarCor(Color cor, {required bool modoClaro}) {
    final lum = cor.computeLuminance();
    if (!modoClaro && lum < 0.06) {
      return HSLColor.fromColor(cor).withLightness(0.55).toColor();
    }
    if (modoClaro && lum > 0.88) {
      return HSLColor.fromColor(cor).withLightness(0.35).toColor();
    }
    return cor;
  }

  static Color corSobrePrimaria(Color cor) =>
      cor.computeLuminance() > 0.35 ? const Color(0xFF1A1A1A) : Colors.white;

  // ==========================================
  // Tema ESCURO
  // ==========================================
  static ThemeData temaEscuro(Color corPrimaria) {
    final cor    = adaptarCor(corPrimaria, modoClaro: false);
    final corBtn = corSobrePrimaria(cor);
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF1A1A1A),
      primaryColor: cor,
      colorScheme: ColorScheme.dark(
        primary: cor, secondary: cor,
        surface: const Color(0xFF2A2A2A),
        error: corErro, onPrimary: corBtn,
        onSurface: Colors.white,
        onSurfaceVariant: const Color(0xFF9E9E9E),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF1A1A1A), elevation: 0, centerTitle: true,
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 1.2),
        iconTheme: IconThemeData(color: cor),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
        backgroundColor: cor, foregroundColor: corBtn,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      )),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
        foregroundColor: cor, side: BorderSide(color: cor),
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      )),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: const Color(0xFF2A2A2A),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cor, width: 1.5)),
        labelStyle: const TextStyle(color: Color(0xFF9E9E9E)),
        hintStyle: const TextStyle(color: Color(0xFF9E9E9E)),
      ),
      cardTheme: const CardThemeData(
        color: Color(0xFF2C2C2C), elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: const Color(0xFF2A2A2A),
        selectedItemColor: cor, unselectedItemColor: const Color(0xFF9E9E9E),
        type: BottomNavigationBarType.fixed,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? cor : const Color(0xFF9E9E9E)),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? cor.withOpacity(0.4) : const Color(0xFF2C2C2C)),
      ),
      textTheme: const TextTheme(
        headlineLarge:  TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600),
        bodyLarge:      TextStyle(color: Colors.white, fontSize: 16),
        bodyMedium:     TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
      ),
    );
  }

  // ==========================================
  // Tema CLARO
  // ==========================================
  static ThemeData temaClaro(Color corPrimaria) {
    final cor    = adaptarCor(corPrimaria, modoClaro: true);
    final corBtn = corSobrePrimaria(cor);
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      primaryColor: cor,
      colorScheme: ColorScheme.light(
        primary: cor, secondary: cor,
        surface: const Color(0xFFEEEEEE),
        error: corErro, onPrimary: corBtn,
        onSurface: const Color(0xFF1A1A1A),
        onSurfaceVariant: const Color(0xFF757575),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFFF5F5F5), elevation: 0, centerTitle: true,
        titleTextStyle: const TextStyle(color: Color(0xFF1A1A1A), fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 1.2),
        iconTheme: IconThemeData(color: cor),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
        backgroundColor: cor, foregroundColor: corBtn,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      )),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
        foregroundColor: cor, side: BorderSide(color: cor),
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      )),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cor, width: 1.5)),
        labelStyle: const TextStyle(color: Color(0xFF757575)),
        hintStyle: const TextStyle(color: Color(0xFF757575)),
      ),
      cardTheme: const CardThemeData(
        color: Colors.white, elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: cor, unselectedItemColor: const Color(0xFF757575),
        type: BottomNavigationBarType.fixed,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? cor : const Color(0xFF757575)),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? cor.withOpacity(0.4) : const Color(0xFFEEEEEE)),
      ),
      textTheme: const TextTheme(
        headlineLarge:  TextStyle(color: Color(0xFF1A1A1A), fontSize: 28, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: Color(0xFF1A1A1A), fontSize: 22, fontWeight: FontWeight.w600),
        bodyLarge:      TextStyle(color: Color(0xFF1A1A1A), fontSize: 16),
        bodyMedium:     TextStyle(color: Color(0xFF757575), fontSize: 14),
      ),
    );
  }

  static ThemeData comCor(Color cor, {bool modoClaro = false}) =>
      modoClaro ? temaClaro(cor) : temaEscuro(cor);
  static ThemeData get dark => temaEscuro(corPrimaria);
}