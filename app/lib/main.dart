// ==========================================
// MAIN: Entrada principal do app
// RF04 - Tema dinâmico sem recriar o router
// ==========================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_router.dart';
import 'core/services/barbearia_theme_service.dart';
import 'features/auth/controllers/auth_controller.dart';
import 'features/agendamento/controllers/agendamento_controller.dart';
import 'features/barbeiro/controllers/barbeiro_controller.dart';
import 'features/admin/controllers/admin_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BarbeariaApp());
}

class BarbeariaApp extends StatefulWidget {
  const BarbeariaApp({super.key});

  @override
  State<BarbeariaApp> createState() => _BarbeariaAppState();
}

class _BarbeariaAppState extends State<BarbeariaApp> {
  late final AuthController      _authController;
  late final AgendamentoController _agendamentoController;
  late final BarbeiroController  _barbeiroController;
  late final AdminController     _adminController;
  late final BarbeariaThemeService _themeService;

  @override
  void initState() {
    super.initState();
    _authController       = AuthController();
    _agendamentoController = AgendamentoController();
    _barbeiroController   = BarbeiroController();
    _adminController      = AdminController();
    _themeService         = BarbeariaThemeService();
  }

  @override
  Widget build(BuildContext context) {
    // Router criado uma única vez — não recria quando o tema muda
    final router = AppRouter.criar(_authController);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authController),
        ChangeNotifierProvider.value(value: _agendamentoController),
        ChangeNotifierProvider.value(value: _barbeiroController),
        ChangeNotifierProvider.value(value: _adminController),
        ChangeNotifierProvider.value(value: _themeService),
      ],
      child: Consumer<BarbeariaThemeService>(
        builder: (context, tema, _) {
          return MaterialApp.router(
            title: 'GetCutt',
            debugShowCheckedModeBanner: false,
            theme:     AppTheme.temaClaro(tema.corPrimaria),
            darkTheme: AppTheme.temaEscuro(tema.corPrimaria),
            themeMode: tema.modoClaro ? ThemeMode.light : ThemeMode.dark,
            routerConfig: router,
            // ==========================================
            // RESPONSIVIDADE WEB
            // Em telas largas (desktop/navegador), o conteúdo
            // ocupa uma largura de "site" (não fica esticado
            // a tela toda, mas também não vira uma moldura de
            // celular) — no estilo Cal.com (~1100px de largura
            // máxima, fundo branco/canvas ao redor).
            // Em telas estreitas (celular), não muda nada.
            // ==========================================
            builder: (context, child) {
              if (child == null) return const SizedBox.shrink();

              return LayoutBuilder(
                builder: (context, constraints) {
                  const double breakpoint = 700;
                  const double larguraMaxima = 1500;

                  if (constraints.maxWidth <= breakpoint) {
                    return child;
                  }

                  final corFundoLateral =
                      tema.modoClaro ? const Color(0xFFFFFFFF) : const Color(0xFF101010);

                  return Container(
                    color: corFundoLateral,
                    width: double.infinity,
                    height: double.infinity,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: larguraMaxima),
                        child: ClipRect(child: child),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}