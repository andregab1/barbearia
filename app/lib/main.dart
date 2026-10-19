// ==========================================
// MAIN: Entrada principal do app
// RF04 - Tema dinÃ¢mico sem recriar o router
// ==========================================
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_router.dart';
import 'core/services/barbearia_theme_service.dart';
import 'features/auth/controllers/auth_controller.dart';
import 'features/agendamento/controllers/agendamento_controller.dart';
import 'features/barbeiro/controllers/barbeiro_controller.dart';
import 'features/admin/controllers/admin_controller.dart';
import 'features/admin/controllers/financial_controller.dart';
import 'web/sphere_helper_stub.dart'
    if (dart.library.js_interop) 'web/sphere_helper_web.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  _disableDebugPaintOverlays();
  await initializeDateFormatting('pt_BR');
  if (kIsWeb) registerSphereView();
  runApp(const BarbeariaApp());
}

void _disableDebugPaintOverlays() {
  debugPaintBaselinesEnabled = false;
  debugPaintSizeEnabled = false;
  debugPaintTextLayoutBoxes = false;
  debugPaintLayerBordersEnabled = false;
  debugPaintPointersEnabled = false;
  debugRepaintRainbowEnabled = false;
  debugRepaintTextRainbowEnabled = false;
}

class BarbeariaApp extends StatefulWidget {
  const BarbeariaApp({super.key});

  @override
  State<BarbeariaApp> createState() => _BarbeariaAppState();
}

class _BarbeariaAppState extends State<BarbeariaApp> {
  late final AuthController _authController;
  late final AgendamentoController _agendamentoController;
  late final BarbeiroController _barbeiroController;
  late final AdminController _adminController;
  late final FinancialController _financialController;
  late final BarbeariaThemeService _themeService;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _disableDebugPaintOverlays();
    });
    WidgetsBinding.instance.addPersistentFrameCallback((_) {
      _disableDebugPaintOverlays();
    });
    _authController = AuthController();
    _agendamentoController = AgendamentoController();
    _barbeiroController = BarbeiroController();
    _adminController = AdminController();
    _financialController = FinancialController();
    _themeService = BarbeariaThemeService();
    _router = AppRouter.criar(_authController);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authController),
        ChangeNotifierProvider.value(value: _agendamentoController),
        ChangeNotifierProvider.value(value: _barbeiroController),
        ChangeNotifierProvider.value(value: _adminController),
        ChangeNotifierProvider.value(value: _financialController),
        ChangeNotifierProvider.value(value: _themeService),
      ],
      child: Consumer<BarbeariaThemeService>(
        builder: (context, tema, _) {
          return MaterialApp.router(
            title: 'GetCutt',
            locale: const Locale('pt', 'BR'),
            supportedLocales: const [Locale('pt', 'BR')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            debugShowCheckedModeBanner: false,
            theme: AppTheme.temaClaro(tema.corPrimaria),
            darkTheme: AppTheme.temaEscuro(tema.corPrimaria),
            themeMode: tema.modoClaro ? ThemeMode.light : ThemeMode.dark,
            routerConfig: _router,
          );
        },
      ),
    );
  }
}
