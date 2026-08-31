import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/barbearia_theme_service.dart';
import '../../../shared/widgets/logo_widget.dart';
import '../controllers/auth_controller.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );
    _animController.forward();
    _inicializar();
  }

  Future<void> _inicializar() async {
    await context.read<BarbeariaThemeService>().carregar();
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;

    final auth = context.read<AuthController>();
    if (auth.estaLogado) {
      if (auth.role == AppConstants.roleAdmin) {
        context.go(AppConstants.routeHomeAdmin);
      } else if (auth.role == AppConstants.roleBarbeiro)
        context.go(AppConstants.routeHomeBarbeiro);
      else
        context.go(AppConstants.routeHomeCliente);
    } else {
      context.go('/');
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = context.watch<BarbeariaThemeService>();

    return Scaffold(
      backgroundColor: AppTheme.black,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Stack(
          children: [
            _BrilhoDourado(tema.corPrimaria),
            if (tema.logoUrl != null)
              Center(
                child: Opacity(
                  opacity: 0.05,
                  child: LogoWidget(
                    logoUrl: tema.logoUrl,
                    size: double.infinity,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ScaleTransition(
                    scale: _scaleAnim,
                    child: Container(
                      width: 132,
                      height: 132,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceElev,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: tema.corPrimaria.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: tema.corPrimaria.withValues(alpha: 0.15),
                            blurRadius: 40,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(26),
                        child: LogoWidget(
                          logoUrl: tema.logoUrl,
                          size: 132,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'GetCutt',
                    style: GoogleFonts.playfairDisplay().copyWith(
                      color: tema.corPrimaria,
                      fontSize: 44,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Gestão profissional para sua barbearia',
                    style: GoogleFonts.inter(
                      color: AppTheme.textMuted,
                      fontSize: 13,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 52),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      color: tema.corPrimaria,
                      strokeWidth: 2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrilhoDourado extends StatelessWidget {
  final Color cor;
  const _BrilhoDourado(this.cor);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.3),
          radius: 0.8,
          colors: [
            cor.withValues(alpha: 0.08),
            AppTheme.black.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.6],
        ),
      ),
    );
  }
}
