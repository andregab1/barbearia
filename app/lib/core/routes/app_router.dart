// ==========================================
// ROUTER: Navegação e redirecionamento por role
// RNF01 - Redireciona para login se não autenticado
// ==========================================
import 'package:go_router/go_router.dart';
import '../../features/auth/controllers/auth_controller.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/cadastro_screen.dart';
import '../../features/landing/landing_screen.dart';
import '../../features/agendamento/screens/cliente_home_screen.dart';
import '../../features/barbeiro/screens/profissional_home_screen.dart';
import '../../features/admin/screens/admin_home_screen.dart';
import '../../core/constants/app_constants.dart';

class AppRouter {
  static GoRouter criar(AuthController authController) {
    return GoRouter(
      initialLocation: AppConstants.routeSplash,
      refreshListenable: authController,
      redirect: (context, state) async {
        final logado = authController.estaLogado;
        final role = authController.role;
        final naSplash = state.matchedLocation == AppConstants.routeSplash;
        final naLanding = state.matchedLocation == '/';
        final naAuth = state.matchedLocation == AppConstants.routeLogin ||
            state.matchedLocation == AppConstants.routeCadastro;

        if (naSplash) return null;
        if (!logado && !naAuth && !naLanding) return '/';
        if (logado && naAuth) {
          if (role == AppConstants.roleAdmin) {
            return AppConstants.routeHomeAdmin;
          }
          if (role == AppConstants.roleBarbeiro) {
            return AppConstants.routeHomeBarbeiro;
          }
          return AppConstants.routeHomeCliente;
        }
        return null;
      },
      routes: [
        GoRoute(path: '/', builder: (_, __) => const LandingScreen()),
        GoRoute(
            path: AppConstants.routeSplash,
            builder: (_, __) => const SplashScreen()),
        GoRoute(
            path: AppConstants.routeLogin,
            builder: (_, __) => const LoginScreen()),
        GoRoute(
            path: AppConstants.routeCadastro,
            builder: (_, __) => const CadastroScreen()),
        GoRoute(
            path: AppConstants.routeHomeCliente,
            builder: (_, __) => const ClienteHomeScreen()),
        GoRoute(
            path: AppConstants.routeHomeBarbeiro,
            builder: (_, __) => const ProfissionalHomeScreen()),
        GoRoute(
            path: AppConstants.routeHomeAdmin,
            builder: (_, __) => const AdminHomeScreen()),
      ],
    );
  }
}
