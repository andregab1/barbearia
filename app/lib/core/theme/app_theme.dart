import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static bool _modoClaro = false;
  static void setModo(bool claro) => _modoClaro = claro;

  // ==========================================
  // TOKENS — Dark + Gold Premium
  // ==========================================
  static const Color gold = Color(0xFFD39400);
  static const Color goldLight = Color(0xFFE0A000);

  static const Color black = Color(0xFF120C0C);
  static const Color blackPure = Color(0xFF0E0808);
  static const Color surface = Color(0xFF1A1413);
  static const Color surfaceElev = Color(0xFF211C1A);
  static const Color border = Color(0xFF342C29);

  static const Color text = Color(0xFFF4EFEB);
  static const Color textMuted = Color(0xFFAAA29E);

  static const Color canvasLight = Color(0xFFFAFAF9);
  static const Color textLight = Color(0xFF1C1917);
  static const Color mutedLight = Color(0xFF78716C);
  static const Color surfaceLight = Color(0xFFF5F5F4);

  // ==========================================
  // Cores funcionais
  // ==========================================
  static const Color erro = Color(0xFFD45C5C);
  static const Color sucesso = Color(0xFF6FA66F);
  // Aliases de compatibilidade (legado)
  static const Color corErro = erro;
  static const Color corSucesso = sucesso;

  // ==========================================
  // Cores dinâmicas (alternam entre modos)
  // ==========================================
  static Color get corFundoSecundario => _modoClaro ? surfaceLight : surface;
  static Color get corCard => _modoClaro ? Colors.white : surfaceElev;
  static Color get corTexto => _modoClaro ? textLight : text;
  static Color get corTextoSecundario => _modoClaro ? mutedLight : textMuted;
  static Color get corBorda => _modoClaro ? const Color(0xFFE7E5E4) : border;

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

  // ==========================================
  // TIPOGRAFIA — Playfair Display + Inter
  // ==========================================
  static TextTheme _textTheme(Color corTexto, Color corMuted) {
    final playfair = GoogleFonts.playfairDisplay();
    final inter = GoogleFonts.inter();
    return TextTheme(
      // Display — títulos monumentais (hero, splash)
      displayLarge: playfair.copyWith(
        color: corTexto,
        fontSize: 48,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.5,
        height: 1.1,
      ),
      displayMedium: playfair.copyWith(
        color: corTexto,
        fontSize: 40,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.0,
        height: 1.15,
      ),
      displaySmall: playfair.copyWith(
        color: corTexto,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        height: 1.2,
      ),
      // Headline — títulos de tela
      headlineLarge: playfair.copyWith(
        color: corTexto,
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.6,
        height: 1.25,
      ),
      headlineMedium: playfair.copyWith(
        color: corTexto,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        height: 1.3,
      ),
      headlineSmall: playfair.copyWith(
        color: corTexto,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.35,
      ),
      // Title — cards, seções
      titleLarge: inter.copyWith(
        color: corTexto,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.4,
      ),
      titleMedium: inter.copyWith(
        color: corTexto,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      titleSmall: inter.copyWith(
        color: corTexto,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      // Body
      bodyLarge: inter.copyWith(
        color: corTexto,
        fontSize: 16,
        height: 1.6,
      ),
      bodyMedium: inter.copyWith(
        color: corMuted,
        fontSize: 14,
        height: 1.6,
      ),
      bodySmall: inter.copyWith(
        color: corMuted,
        fontSize: 13,
        height: 1.5,
      ),
      // Label — botões, chips, tags
      labelLarge: inter.copyWith(
        color: corTexto,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
      labelMedium: inter.copyWith(
        color: corMuted,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
      ),
      labelSmall: inter.copyWith(
        color: corMuted,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
      ),
    );
  }

  // ==========================================
  // TEMA ESCURO (padrão)
  // ==========================================
  static ThemeData temaEscuro(Color corPrimaria) {
    final cor = adaptarCor(corPrimaria, modoClaro: false);
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: black,
      primaryColor: cor,
      colorScheme: ColorScheme.dark(
        primary: cor,
        secondary: cor,
        surface: surface,
        error: erro,
        onPrimary: blackPure,
        onSurface: text,
        onSurfaceVariant: textMuted,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: black,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.playfairDisplay().copyWith(
          color: text,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: text),
      ),
      // ==========================================
      // Botão primário — gold, estilo Woovina Pro
      // ==========================================
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cor,
          foregroundColor: blackPure,
          disabledBackgroundColor: cor.withValues(alpha: 0.4),
          disabledForegroundColor: blackPure.withValues(alpha: 0.4),
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
          elevation: 0,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ).copyWith(
          overlayColor:
              WidgetStateProperty.all(goldLight.withValues(alpha: 0.2)),
        ),
      ),
      // ==========================================
      // Botão outline — borda gold, estilo Woovina Pro
      // ==========================================
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cor,
          side: BorderSide(color: cor.withValues(alpha: 0.6), width: 1.5),
          backgroundColor: Colors.transparent,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ).copyWith(
          overlayColor: WidgetStateProperty.all(cor.withValues(alpha: 0.1)),
        ),
      ),
      // ==========================================
      // Text button
      // ==========================================
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cor,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      // ==========================================
      // Input fields — dark surface, gold focus
      // ==========================================
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: erro),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: erro, width: 1.5),
        ),
        labelStyle: GoogleFonts.inter(color: textMuted, fontSize: 14),
        hintStyle: GoogleFonts.inter(color: textMuted, fontSize: 14),
        prefixIconColor: textMuted,
      ),
      // ==========================================
      // Cards
      // ==========================================
      cardTheme: CardThemeData(
        color: surfaceElev,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: border.withValues(alpha: 0.5)),
        ),
      ),
      // ==========================================
      // Bottom nav (fallback mobile)
      // ==========================================
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: black,
        selectedItemColor: cor,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 12),
      ),
      // ==========================================
      // Switch
      // ==========================================
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? cor : textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? cor.withValues(alpha: 0.3)
              : surfaceElev,
        ),
      ),
      // ==========================================
      // Divider
      // ==========================================
      dividerTheme: DividerThemeData(
        color: border.withValues(alpha: 0.5),
        thickness: 1,
        space: 1,
      ),
      // ==========================================
      // Dialog
      // ==========================================
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceElev,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      // ==========================================
      // Progress indicator
      // ==========================================
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: cor,
        linearTrackColor: cor.withValues(alpha: 0.2),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? cor : surface,
        ),
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: textMuted,
          minimumSize: const Size.square(44),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: surfaceElev,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        textStyle: GoogleFonts.inter(color: text, fontSize: 12),
      ),
      textTheme: _textTheme(text, textMuted),
    );
  }

  // ==========================================
  // TEMA CLARO
  // ==========================================
  static ThemeData temaClaro(Color corPrimaria) {
    final cor = adaptarCor(corPrimaria, modoClaro: true);
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: canvasLight,
      primaryColor: cor,
      colorScheme: ColorScheme.light(
        primary: cor,
        secondary: cor,
        surface: Colors.white,
        error: erro,
        onPrimary: Colors.white,
        onSurface: textLight,
        onSurfaceVariant: mutedLight,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: canvasLight,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.playfairDisplay().copyWith(
          color: textLight,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: textLight),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFD6D3D1),
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
          elevation: 0,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ).copyWith(
          overlayColor:
              WidgetStateProperty.all(Colors.black.withValues(alpha: 0.15)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cor,
          side: BorderSide(color: cor.withValues(alpha: 0.4), width: 1.5),
          backgroundColor: Colors.transparent,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cor,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE7E5E4)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE7E5E4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: erro),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: erro, width: 1.5),
        ),
        labelStyle: GoogleFonts.inter(color: mutedLight, fontSize: 14),
        hintStyle: GoogleFonts.inter(color: mutedLight, fontSize: 14),
        prefixIconColor: mutedLight,
      ),
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: cor,
        unselectedItemColor: mutedLight,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 12),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? cor : mutedLight,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? cor.withValues(alpha: 0.3)
              : const Color(0xFFD6D3D1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE7E5E4),
        thickness: 1,
        space: 1,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: cor,
        linearTrackColor: cor.withValues(alpha: 0.2),
      ),
      textTheme: _textTheme(textLight, mutedLight),
    );
  }

  static ThemeData comCor(Color cor, {bool modoClaro = false}) =>
      modoClaro ? temaClaro(cor) : temaEscuro(cor);
}
