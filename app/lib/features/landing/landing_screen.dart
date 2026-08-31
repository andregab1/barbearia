import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/barbearia_theme_service.dart';
import '../../../web/sphere_helper_stub.dart'
    if (dart.library.js_interop) '../../../web/sphere_helper_web.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final _scrollController = ScrollController();
  final _servicesKey = GlobalKey();
  final _aboutKey = GlobalKey();
  final _contactKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) initSphere(0);
      });
    }
  }

  @override
  void dispose() {
    if (kIsWeb) destroySphere();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _scrollTo(GlobalKey key) async {
    final target = key.currentContext;
    if (target == null) return;
    await Scrollable.ensureVisible(target,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
        alignment: .05);
  }

  @override
  Widget build(BuildContext context) {
    final tema = context.watch<BarbeariaThemeService>();
    final cor = Theme.of(context).colorScheme.primary;
    final largura = MediaQuery.sizeOf(context).width;
    final isDesktop = largura >= 900;

    return Scaffold(
      backgroundColor: AppTheme.black,
      body: Stack(
        children: [
          if (kIsWeb)
            const Positioned.fill(
              child: HtmlElementView(viewType: 'sphere-container'),
            )
          else
            Positioned.fill(
              child: Opacity(
                opacity: 0.08,
                child: Icon(Icons.content_cut_rounded, size: 420, color: cor),
              ),
            ),
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                color: AppTheme.black.withValues(alpha: 0.56),
              ),
            ),
          ),
          SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              children: [
                _buildNavbar(context, tema, cor, isDesktop),
                _buildHero(context, cor),
                _buildFeatures(context, cor),
                _buildAbout(context, cor),
                _buildContact(context, cor),
                _buildFooter(context, cor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // NAVBAR
  // ==========================================
  Widget _buildNavbar(BuildContext context, BarbeariaThemeService tema,
      Color cor, bool isDesktop) {
    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: isDesktop ? 48 : 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.content_cut_rounded, size: 22, color: cor),
                const SizedBox(width: 10),
                Text('GetCutt',
                    style: GoogleFonts.inter(
                      color: cor,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    )),
              ]),
            ),
          ),

          if (isDesktop) ...[
            // Links
            Row(mainAxisSize: MainAxisSize.min, children: [
              _navLink(
                  'Início',
                  () => _scrollController.animateTo(0,
                      duration: const Duration(milliseconds: 650),
                      curve: Curves.easeOutCubic)),
              const SizedBox(width: 32),
              _navLink('Serviços', () => _scrollTo(_servicesKey)),
              const SizedBox(width: 32),
              _navLink('Sobre', () => _scrollTo(_aboutKey)),
              const SizedBox(width: 32),
              _navLink('Contato', () => _scrollTo(_contactKey)),
            ]),
            // Botão Login
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => context.go(AppConstants.routeLogin),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Entrar',
                      style: GoogleFonts.inter(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ] else ...[
            // Mobile: botão login
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: Icon(Icons.login_rounded, color: cor),
                  onPressed: () => context.go(AppConstants.routeLogin),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _navLink(String text, VoidCallback onTap) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Text(text,
              style: GoogleFonts.inter(
                color: AppTheme.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              )),
        ),
      ),
    );
  }

  // ==========================================
  // HERO
  // ==========================================
  Widget _buildHero(BuildContext context, Color cor) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 600),
      color: Colors.transparent,
      child: Stack(
        children: [
          // Tesoura 3D interativa no fundo da página inicial.
          // Conteúdo
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    isDesktop ? 96 : 24, 80, isDesktop ? 48 : 24, 80),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ícone
                    Text('GESTÃO INTELIGENTE PARA BARBEARIAS',
                        style: GoogleFonts.inter(
                            color: cor,
                            fontSize: isDesktop ? 15 : 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5)),
                    const SizedBox(height: 26),
                    // Título
                    // Subtítulo
                    Text('Sua barbearia,\ndo seu jeito.',
                        textAlign: TextAlign.left,
                        style: GoogleFonts.inter(
                            color: AppTheme.text,
                            fontSize: isDesktop ? 58 : 40,
                            height: 1.04,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -2.0)),
                    const SizedBox(height: 24),
                    // Descrição
                    Text(
                        'Gerencie agendamentos, serviços, horários e equipe de forma simples e eficiente.',
                        textAlign: TextAlign.left,
                        style: GoogleFonts.inter(
                            color: AppTheme.textMuted,
                            fontSize: isDesktop ? 18 : 16,
                            fontWeight: FontWeight.w400,
                            height: 1.6)),
                    const SizedBox(height: 40),
                    // Botão CTA
                    ElevatedButton(
                      onPressed: () => context.go(AppConstants.routeCadastro),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 36, vertical: 18),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.add, size: 20),
                        const SizedBox(width: 10),
                        Text('AGENDAR AGORA',
                            style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0)),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    // Link login
                    TextButton(
                      onPressed: () => context.go(AppConstants.routeLogin),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        alignment: Alignment.centerLeft,
                      ),
                      child: Text.rich(TextSpan(children: [
                        TextSpan(
                            text: 'Já tem conta? ',
                            style: GoogleFonts.inter(
                                color: AppTheme.textMuted, fontSize: 14)),
                        TextSpan(
                            text: 'Entrar',
                            style: GoogleFonts.inter(
                                color: cor,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                      ])),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // FEATURES
  // ==========================================
  Widget _buildFeatures(BuildContext context, Color cor) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    return Container(
      key: _servicesKey,
      width: double.infinity,
      padding:
          EdgeInsets.symmetric(horizontal: isDesktop ? 96 : 24, vertical: 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Por que escolher o GetCutt?',
              style: GoogleFonts.inter(
                  color: AppTheme.text,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5)),
          const SizedBox(height: 12),
          Text('Tudo que você precisa em um só lugar.',
              style: GoogleFonts.inter(
                  color: AppTheme.textMuted,
                  fontSize: 15,
                  fontWeight: FontWeight.w400)),
          const SizedBox(height: 48),
          // Cards
          Wrap(
            spacing: 20,
            runSpacing: 20,
            alignment: WrapAlignment.center,
            children: [
              _featureCard(
                  cor,
                  Icons.calendar_today_outlined,
                  'Agendamentos inteligentes',
                  'Clientes marcam horário em segundos. Sem ligações, sem complicações.'),
              _featureCard(
                  cor,
                  Icons.content_cut_rounded,
                  'Serviços personalizados',
                  'Cadastre seus serviços, preços e durações do seu jeito.'),
              _featureCard(cor, Icons.bar_chart_outlined, 'Gestão completa',
                  'Relatórios, equipe, horários — tudo em um painel moderno.'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAbout(BuildContext context, Color cor) {
    final desktop = MediaQuery.sizeOf(context).width >= 900;
    final copy =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('SOBRE O GETCUTT',
          style: GoogleFonts.inter(
              color: cor,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5)),
      const SizedBox(height: 16),
      Text('A operação da barbearia em um único lugar.',
          style: GoogleFonts.inter(
              color: AppTheme.text,
              fontSize: desktop ? 36 : 28,
              height: 1.15,
              fontWeight: FontWeight.w800,
              letterSpacing: -1)),
      const SizedBox(height: 18),
      Text(
          'O GetCutt conecta proprietários, profissionais e clientes. Agenda, equipe, serviços e resultados compartilham os mesmos dados, reduzindo tarefas manuais e conflitos de horário.',
          style: GoogleFonts.inter(
              color: AppTheme.textMuted, fontSize: 15, height: 1.7)),
    ]);
    final metrics = Wrap(spacing: 12, runSpacing: 12, children: [
      _aboutMetric(cor, '24h', 'agenda disponível'),
      _aboutMetric(cor, '1 painel', 'gestão integrada'),
      _aboutMetric(cor, '3 perfis', 'admin, equipe e cliente'),
      _aboutMetric(cor, 'Tempo real', 'horários sincronizados'),
    ]);

    return Container(
      key: _aboutKey,
      width: double.infinity,
      padding: EdgeInsets.symmetric(
          horizontal: desktop ? 96 : 24, vertical: desktop ? 96 : 64),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: .78),
        border: Border.symmetric(
            horizontal:
                BorderSide(color: AppTheme.border.withValues(alpha: .45))),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: desktop
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 5, child: copy),
                  const SizedBox(width: 72),
                  Expanded(flex: 4, child: metrics),
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  copy,
                  const SizedBox(height: 32),
                  metrics,
                ]),
        ),
      ),
    );
  }

  Widget _aboutMetric(Color cor, String value, String label) => Container(
        width: 190,
        height: 112,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.surfaceElev,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              style: GoogleFonts.inter(
                  color: cor, fontSize: 20, fontWeight: FontWeight.w800)),
          const Spacer(),
          Text(label,
              style: GoogleFonts.inter(
                  color: AppTheme.textMuted, fontSize: 12, height: 1.3)),
        ]),
      );

  Widget _buildContact(BuildContext context, Color cor) {
    final desktop = MediaQuery.sizeOf(context).width >= 900;
    return Container(
      key: _contactKey,
      width: double.infinity,
      padding: EdgeInsets.symmetric(
          horizontal: desktop ? 96 : 24, vertical: desktop ? 88 : 64),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(desktop ? 42 : 24),
            decoration: BoxDecoration(
              color: cor.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: cor.withValues(alpha: .28)),
            ),
            child: Wrap(
              spacing: 30,
              runSpacing: 24,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: desktop ? 570 : double.infinity,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pronto para organizar sua barbearia?',
                            style: GoogleFonts.inter(
                                color: AppTheme.text,
                                fontSize: desktop ? 28 : 23,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        Text(
                            'Crie sua conta de teste ou fale com nossa equipe pelo e-mail contato@getcutt.com.br.',
                            style: GoogleFonts.inter(
                                color: AppTheme.textMuted,
                                fontSize: 14,
                                height: 1.5)),
                      ]),
                ),
                ElevatedButton.icon(
                  onPressed: () => context.go(AppConstants.routeCadastro),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('COMEÇAR AGORA'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: cor,
                      foregroundColor: AppTheme.black,
                      minimumSize: const Size(190, 50)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _featureCard(Color cor, IconData icone, String titulo, String desc) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElev,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icone, size: 24, color: cor),
          ),
          const SizedBox(height: 20),
          Text(titulo,
              style: GoogleFonts.inter(
                  color: AppTheme.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(desc,
              style: GoogleFonts.inter(
                  color: AppTheme.textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  height: 1.5)),
        ],
      ),
    );
  }

  // ==========================================
  // FOOTER
  // ==========================================
  Widget _buildFooter(BuildContext context, Color cor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(color: AppTheme.border.withValues(alpha: 0.3))),
      ),
      child: Center(
        child: Text('© 2025 GetCutt. Todos os direitos reservados.',
            style: GoogleFonts.inter(
                color: AppTheme.textMuted.withValues(alpha: 0.5),
                fontSize: 12)),
      ),
    );
  }
}
