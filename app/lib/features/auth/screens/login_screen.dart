import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/barbearia_theme_service.dart';
import '../../../shared/widgets/logo_widget.dart';
import '../controllers/auth_controller.dart';
import '../../../web/sphere_helper_stub.dart'
    if (dart.library.js_interop) '../../../web/sphere_helper_web.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _loginCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  bool _senhaVisivel = false;
  bool _lembrarDeMim = true;

  Future<void> _mostrarAjudaSenha() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ajuda com acesso'),
        content: const Text(
          'A recuperação automática de senha ainda não está disponível. '
          'Entre em contato com o administrador da sua barbearia para criar ou redefinir seu acesso.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Inicializa a esfera na tela de login (web only, após o primeiro frame)
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) initSphere(0);
      });
    }
  }

  @override
  void dispose() {
    if (kIsWeb) destroySphere();
    _loginCtrl.dispose();
    _senhaCtrl.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthController>();
    final ok = await auth.login(_loginCtrl.text.trim(), _senhaCtrl.text);

    if (!mounted) return;
    if (ok) {
      if (auth.role == AppConstants.roleAdmin) {
        context.go(AppConstants.routeHomeAdmin);
      } else if (auth.role == AppConstants.roleBarbeiro)
        context.go(AppConstants.routeHomeBarbeiro);
      else
        context.go(AppConstants.routeHomeCliente);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = context.watch<BarbeariaThemeService>();
    final cor = Theme.of(context).colorScheme.primary;
    final largura = MediaQuery.sizeOf(context).width;
    final isDesktop = largura >= 900;

    return Scaffold(
      backgroundColor: AppTheme.black,
      body: isDesktop ? _buildDesktop(tema, cor) : _buildMobile(tema, cor),
    );
  }

  // ==========================================
  // DESKTOP: Split layout
  // ==========================================
  Widget _buildDesktop(BarbeariaThemeService tema, Color cor) {
    return Row(children: [
      // Hero à esquerda
      Expanded(flex: 5, child: _buildHero(tema, cor)),
      // Form à direita
      Expanded(flex: 5, child: _buildFormArea(tema, cor)),
    ]);
  }

  // ==========================================
  // MOBILE: Form only
  // ==========================================
  Widget _buildMobile(BarbeariaThemeService tema, Color cor) {
    return Stack(children: [
      // Particle sphere (web only — camada mais atrás)
      if (kIsWeb)
        const Positioned.fill(
          child: HtmlElementView(viewType: 'sphere-container'),
        ),
      // Background com imagem sutil
      Positioned.fill(
        child: Opacity(
          opacity: 0.06,
          child: tema.logoUrl != null
              ? LogoWidget(
                  logoUrl: tema.logoUrl,
                  size: double.infinity,
                  fit: BoxFit.cover)
              : Icon(Icons.content_cut_rounded, size: 300, color: cor),
        ),
      ),
      // Gradiente de fundo
      Positioned.fill(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppTheme.black, AppTheme.black.withValues(alpha: 0.95)],
            ),
          ),
        ),
      ),
      // Form
      SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: _buildFormContent(tema, cor),
        ),
      ),
    ]);
  }

  // ==========================================
  // HERO (lado esquerdo desktop)
  // ==========================================
  Widget _buildHero(BarbeariaThemeService tema, Color cor) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.surface,
            AppTheme.black,
          ],
        ),
      ),
      child: Stack(children: [
        // Particle sphere (web only — camada mais atrás)
        if (kIsWeb)
          const Positioned.fill(
            child: HtmlElementView(viewType: 'sphere-container'),
          ),
        // Imagem de fundo sutil
        Positioned.fill(
          child: Opacity(
            opacity: 0.05,
            child: tema.logoUrl != null
                ? LogoWidget(
                    logoUrl: tema.logoUrl,
                    size: double.infinity,
                    fit: BoxFit.cover)
                : Icon(Icons.content_cut_rounded, size: 400, color: cor),
          ),
        ),
        // Gradiente de profundidade
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.black.withValues(alpha: 0.3),
                  AppTheme.black.withValues(alpha: 0.6),
                ],
              ),
            ),
          ),
        ),
        // Conteúdo
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.content_cut_rounded, size: 28, color: cor),
                    const SizedBox(width: 12),
                    Text('GetCutt',
                        style: GoogleFonts.inter(
                          color: cor,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        )),
                  ]),
                  const SizedBox(height: 40),
                  // Título
                  Text('Sua barbearia,\ndo seu jeito.',
                      style: GoogleFonts.playfairDisplay(
                          color: AppTheme.text,
                          fontSize: 38,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.8,
                          height: 1.12)),
                  const SizedBox(height: 16),
                  // Subtítulo
                  Text(
                      'Gerencie agendamentos, serviços, horários e equipe de forma simples e eficiente.',
                      style: GoogleFonts.inter(
                          color: AppTheme.textMuted,
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          height: 1.6)),
                  const SizedBox(height: 40),
                  // Features
                  _buildFeature(
                      cor,
                      Icons.calendar_today_outlined,
                      'Agendamentos inteligentes',
                      'Mais organização e menos falhas.'),
                  const SizedBox(height: 16),
                  _buildFeature(
                      cor,
                      Icons.content_cut_rounded,
                      'Serviços personalizados',
                      'Do jeito que sua barbearia trabalha.'),
                  const SizedBox(height: 16),
                  _buildFeature(
                      cor,
                      Icons.bar_chart_outlined,
                      'Gestão completa',
                      'Tudo que você precisa em um só lugar.'),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildFeature(Color cor, IconData icone, String titulo, String desc) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icone, size: 20, color: cor),
      ),
      const SizedBox(width: 16),
      Expanded(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo,
              style: GoogleFonts.inter(
                  color: AppTheme.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(desc,
              style: GoogleFonts.inter(
                  color: AppTheme.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w400)),
        ],
      )),
    ]);
  }

  // ==========================================
  // ÁREA DO FORMULÁRIO
  // ==========================================
  Widget _buildFormArea(BarbeariaThemeService tema, Color cor) {
    return Stack(children: [
      // Fundo
      Positioned.fill(child: Container(color: AppTheme.black)),
      // Gradiente sutil
      Positioned.fill(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.surface.withValues(alpha: 0.3),
                AppTheme.black,
              ],
            ),
          ),
        ),
      ),
      // Conteúdo
      Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
          child: _buildFormContent(tema, cor),
        ),
      ),
    ]);
  }

  // ==========================================
  // CONTEÚDO DO FORMULÁRIO (compartilhado)
  // ==========================================
  Widget _buildFormContent(BarbeariaThemeService tema, Color cor) {
    final auth = context.watch<AuthController>();

    return Form(
      key: _formKey,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card do form
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElev,
                borderRadius: BorderRadius.circular(18),
                border:
                    Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título
                  Text('Bem-vindo de volta',
                      style: GoogleFonts.playfairDisplay(
                          color: AppTheme.text,
                          fontSize: 25,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text('Faça login para acessar sua conta.',
                      style: GoogleFonts.inter(
                          color: AppTheme.textMuted, fontSize: 14)),
                  const SizedBox(height: 32),

                  // Campo E-mail
                  _buildInputLabel('E-mail'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _loginCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style:
                        GoogleFonts.inter(color: AppTheme.text, fontSize: 14),
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Informe seu e-mail ou telefone'
                        : null,
                    decoration: InputDecoration(
                      hintText: 'seu@email.com',
                      hintStyle: GoogleFonts.inter(
                          color: AppTheme.textMuted.withValues(alpha: 0.5),
                          fontSize: 14),
                      prefixIcon: const Icon(Icons.email_outlined,
                          color: AppTheme.textMuted, size: 20),
                      filled: true,
                      fillColor: AppTheme.surface,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: cor, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Campo Senha
                  _buildInputLabel('Senha'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _senhaCtrl,
                    obscureText: !_senhaVisivel,
                    style:
                        GoogleFonts.inter(color: AppTheme.text, fontSize: 14),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Informe sua senha' : null,
                    decoration: InputDecoration(
                      hintText: '••••••••',
                      hintStyle: GoogleFonts.inter(
                          color: AppTheme.textMuted.withValues(alpha: 0.5),
                          fontSize: 14),
                      prefixIcon: const Icon(Icons.lock_outline,
                          color: AppTheme.textMuted, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                            _senhaVisivel
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppTheme.textMuted,
                            size: 20),
                        onPressed: () =>
                            setState(() => _senhaVisivel = !_senhaVisivel),
                      ),
                      filled: true,
                      fillColor: AppTheme.surface,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: cor, width: 1.5),
                      ),
                    ),
                  ),

                  // Erro
                  if (auth.erro.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.erro.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppTheme.erro.withValues(alpha: 0.3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.error_outline,
                            color: AppTheme.erro, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(auth.erro,
                                style: GoogleFonts.inter(
                                    color: AppTheme.erro,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500))),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Esqueceu a senha + Lembrar de mim
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: Checkbox(
                              value: _lembrarDeMim,
                              onChanged: (v) =>
                                  setState(() => _lembrarDeMim = v ?? true),
                              activeColor: cor,
                              side: BorderSide(
                                  color: AppTheme.textMuted
                                      .withValues(alpha: 0.3)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('Lembrar de mim',
                              style: GoogleFonts.inter(
                                  color: AppTheme.textMuted, fontSize: 13)),
                        ]),
                        TextButton(
                          onPressed: _mostrarAjudaSenha,
                          child: Text('Esqueceu sua senha?',
                              style: GoogleFonts.inter(
                                  color: cor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ]),
                  const SizedBox(height: 20),

                  // Botão Entrar
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: auth.carregando ? null : _entrar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cor,
                        foregroundColor: AppTheme.blackPure,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: auth.carregando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: AppTheme.blackPure, strokeWidth: 2))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                  Text('Entrar',
                                      style: GoogleFonts.inter(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward, size: 18),
                                ]),
                    ),
                  ),

                  const SizedBox(height: 20),

                ],
              ),
            ),

            const SizedBox(height: 24),

            // Footer
            Center(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.center,
                children: [
                  Text('Não tem uma conta?',
                      style: GoogleFonts.inter(
                          color: AppTheme.textMuted, fontSize: 13)),
                  TextButton(
                    onPressed: _mostrarAjudaSenha,
                    child: Text('Fale com nosso suporte',
                        style: GoogleFonts.inter(
                            color: cor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text('© 2025 GetCutt. Todos os direitos reservados.',
                  style: GoogleFonts.inter(
                      color: AppTheme.textMuted.withValues(alpha: 0.5),
                      fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Text(label,
        style: GoogleFonts.inter(
            color: AppTheme.text, fontSize: 13, fontWeight: FontWeight.w500));
  }
}
