// ==========================================
// TELA: Splash Screen
// RF04 - Logo PNG como background centralizado
// ==========================================
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
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

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _fadeAnim       = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.forward();
    _inicializar();
  }

  Future<void> _inicializar() async {
    // RF04: Carrega tema da barbearia antes de redirecionar
    await context.read<BarbeariaThemeService>().carregar();
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final auth = context.read<AuthController>();
    if (auth.estaLogado) {
      if (auth.role == AppConstants.roleAdmin)         context.go(AppConstants.routeHomeAdmin);
      else if (auth.role == AppConstants.roleBarbeiro) context.go(AppConstants.routeHomeBarbeiro);
      else                                             context.go(AppConstants.routeHomeCliente);
    } else {
      context.go(AppConstants.routeLogin);
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Stack(
          children: [
            // RF04: Logo PNG como background centralizado
            if (tema.logoUrl != null)
              Center(
                child: Opacity(
                  opacity: 0.08,
                  child: LogoWidget(
                    logoUrl: tema.logoUrl,
                    size: double.infinity,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

            // Conteúdo principal
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(
                      color: AppTheme.corCard,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: tema.corPrimaria, width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: LogoWidget(
                        logoUrl: tema.logoUrl,
                        size: 120,
                        fit: BoxFit.cover,
                        placeholder: Icon(Icons.content_cut, color: tema.corPrimaria, size: 60),
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  Text('GetCutt', style: TextStyle(
                    color: tema.corPrimaria, fontSize: 40,
                    fontWeight: FontWeight.bold, letterSpacing: 6,
                  )),
                  SizedBox(height: 8),
                  Text('Gestão inteligente para barbearias',
                      style: TextStyle(color: AppTheme.corTextoSecundario, fontSize: 13, letterSpacing: 1)),
                  const SizedBox(height: 48),
                  CircularProgressIndicator(color: tema.corPrimaria, strokeWidth: 2),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}