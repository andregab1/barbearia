// ==========================================
// THEME: Identidade visual do app
// Baseado no design system do Cal.com — monocromático,
// tipografia Inter, cards cinza-claro, CTA preta.
// Cores dinâmicas — adapta a claro/escuro
// ==========================================
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Modo atual — atualizado pelo BarbeariaThemeService
  static bool _modoClaro = false;
  static void setModo(bool claro) => _modoClaro = claro;

  // ==========================================
  // Tokens Cal.com — cores base do sistema
  // ==========================================
  static const Color _ink              = Color(0xFF111111); // colors.ink / primary
  static const Color _inkActive        = Color(0xFF242424); // colors.primary-active
  static const Color _body             = Color(0xFF374151); // colors.body
  static const Color _muted            = Color(0xFF6B7280); // colors.muted
  static const Color _canvas           = Color(0xFFFFFFFF); // colors.canvas
  static const Color _surfaceSoft      = Color(0xFFF8F9FA); // colors.surface-soft
  static const Color _surfaceCard      = Color(0xFFF5F5F5); // colors.surface-card
  static const Color _surfaceStrong    = Color(0xFFE5E7EB); // colors.surface-strong / hairline
  static const Color _surfaceDark      = Color(0xFF101010); // colors.surface-dark
  static const Color _surfaceDarkElev  = Color(0xFF1A1A1A); // colors.surface-dark-elevated
  static const Color _onDarkSoft       = Color(0xFFA1A1AA); // colors.on-dark-soft

  // ==========================================
  // Cores dinâmicas (mudam com o tema)
  // ==========================================
  static Color get corFundo =>
      _modoClaro ? _canvas : _surfaceDark;
  static Color get corFundoSecundario =>
      _modoClaro ? _surfaceSoft : _surfaceDarkElev;
  static Color get corCard =>
      _modoClaro ? _surfaceCard : _surfaceDarkElev;
  static Color get corTexto =>
      _modoClaro ? _ink : Colors.white;
  static Color get corTextoSecundario =>
      _modoClaro ? _muted : _onDarkSoft;

  // ==========================================
  // Cores fixas (não mudam com tema)
  // Antes era o dourado da marca — trocado pro
  // preto do Cal.com, já que várias telas usam
  // essa constante direto (não só via Theme).
  // ==========================================
  static const Color corPrimaria = Color(0xFF111111);
  static const Color corErro     = Color(0xFFEF4444); // colors.error
  static const Color corSucesso  = Color(0xFF10B981); // colors.success

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
  // Tipografia — Inter (Cal Sans não é web-safe;
  // Inter 600 com letter-spacing negativo é a
  // substituição recomendada pelo próprio Cal.com)
  // ==========================================
  static TextTheme _textTheme(Color corTexto, Color corMuted) {
    final base = GoogleFonts.interTextTheme();
    return base.copyWith(
      // display-lg — títulos de tela (Cal Sans substituído)
      headlineLarge: GoogleFonts.inter(
        color: corTexto, fontSize: 32, fontWeight: FontWeight.w600,
        letterSpacing: -1.0, height: 1.15,
      ),
      // display-sm — subtítulos, preços, cards em destaque
      headlineMedium: GoogleFonts.inter(
        color: corTexto, fontSize: 22, fontWeight: FontWeight.w600,
        letterSpacing: -0.4, height: 1.2,
      ),
      // title-md — títulos de card
      titleMedium: GoogleFonts.inter(
        color: corTexto, fontSize: 18, fontWeight: FontWeight.w600,
      ),
      // title-sm
      titleSmall: GoogleFonts.inter(
        color: corTexto, fontSize: 16, fontWeight: FontWeight.w600,
      ),
      // body-md — texto padrão
      bodyLarge: GoogleFonts.inter(color: corTexto, fontSize: 16, height: 1.5),
      // body-sm / muted
      bodyMedium: GoogleFonts.inter(color: corMuted, fontSize: 14, height: 1.5),
      // caption
      bodySmall: GoogleFonts.inter(color: corMuted, fontSize: 13, fontWeight: FontWeight.w500),
      // button
      labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
    );
  }

  // ==========================================
  // Tema ESCURO
  // ==========================================
  static ThemeData temaEscuro(Color corPrimaria) {
    final cor    = adaptarCor(corPrimaria, modoClaro: false);
    // No dark, a CTA inverte pra branco (preto some no fundo escuro)
    const ctaBg  = Colors.white;
    const ctaFg  = Color(0xFF111111);
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _surfaceDark,
      primaryColor: cor,
      colorScheme: ColorScheme.dark(
        primary: cor, secondary: cor,
        surface: _surfaceDarkElev,
        error: corErro, onPrimary: ctaFg,
        onSurface: Colors.white,
        onSurfaceVariant: _onDarkSoft,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _surfaceDark, elevation: 0, centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
        backgroundColor: ctaBg, foregroundColor: ctaFg,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      )),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white, side: const BorderSide(color: _surfaceStrong),
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      )),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: _surfaceDarkElev,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white, width: 1.5)),
        labelStyle: const TextStyle(color: _onDarkSoft),
        hintStyle: const TextStyle(color: _onDarkSoft),
      ),
      cardTheme: const CardThemeData(
        color: _surfaceDarkElev, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _surfaceDarkElev,
        selectedItemColor: Colors.white, unselectedItemColor: _onDarkSoft,
        type: BottomNavigationBarType.fixed,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? cor : _onDarkSoft),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? cor.withOpacity(0.4) : _surfaceDarkElev),
      ),
      textTheme: _textTheme(Colors.white, _onDarkSoft),
    );
  }

  // ==========================================
  // Tema CLARO (padrão Cal.com)
  // ==========================================
  static ThemeData temaClaro(Color corPrimaria) {
    final cor = adaptarCor(corPrimaria, modoClaro: true);
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: _canvas,
      primaryColor: _ink,
      colorScheme: ColorScheme.light(
        primary: _ink, secondary: cor,
        surface: _surfaceCard,
        error: corErro, onPrimary: Colors.white,
        onSurface: _ink,
        onSurfaceVariant: _muted,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _canvas, elevation: 0, centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          color: _ink, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: _ink),
      ),
      // button-primary: fundo preto, texto branco, radius 8, altura 48
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
        backgroundColor: _ink, foregroundColor: Colors.white,
        disabledBackgroundColor: _surfaceStrong,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      ).copyWith(
        overlayColor: WidgetStateProperty.all(_inkActive.withOpacity(0.1)),
      )),
      // button-secondary: fundo branco, borda hairline
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
        foregroundColor: _ink, side: const BorderSide(color: _surfaceStrong),
        backgroundColor: _canvas,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      )),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(
        foregroundColor: _ink,
        textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      )),
      // text-input: radius 8, hairline border
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: _canvas,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _surfaceStrong)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _surfaceStrong)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _ink, width: 1.5)),
        labelStyle: const TextStyle(color: _muted),
        hintStyle: const TextStyle(color: _muted),
      ),
      // feature-card / content card: fundo cinza-claro, radius 12, sem sombra pesada
      cardTheme: const CardThemeData(
        color: _surfaceCard, elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _canvas,
        selectedItemColor: _ink, unselectedItemColor: _muted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? cor : _muted),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? cor.withOpacity(0.4) : _surfaceStrong),
      ),
      dividerTheme: const DividerThemeData(color: _surfaceStrong, thickness: 1, space: 1),
      textTheme: _textTheme(_ink, _muted),
    );
  }

  static ThemeData comCor(Color cor, {bool modoClaro = false}) =>
      modoClaro ? temaClaro(cor) : temaEscuro(cor);
  static ThemeData get dark => temaEscuro(corPrimaria);
}