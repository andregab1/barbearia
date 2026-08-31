import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/barbearia_theme_service.dart';
import '../../../shared/widgets/logo_widget.dart';
import '../controllers/auth_controller.dart';

class CadastroScreen extends StatefulWidget {
  const CadastroScreen({super.key});
  @override
  State<CadastroScreen> createState() => _CadastroScreenState();
}

class _CadastroScreenState extends State<CadastroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _barbeariaCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  bool _senhaVisivel = false;
  bool _souProprietario = false;

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _emailCtrl.dispose();
    _usernameCtrl.dispose();
    _barbeariaCtrl.dispose();
    _telefoneCtrl.dispose();
    _senhaCtrl.dispose();
    super.dispose();
  }

  bool _telefoneValido(String tel) {
    final digits = tel.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 10 && digits.length <= 11;
  }

  Future<void> _cadastrar() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthController>();
    final ok = _souProprietario
        ? await auth.cadastrarProprietario(
            nomeProprietario: _nomeCtrl.text.trim(),
            nomeBarbearia: _barbeariaCtrl.text.trim(),
            telefone: _telefoneCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            senha: _senhaCtrl.text,
          )
        : await auth.cadastrar(
            _nomeCtrl.text.trim(),
            _telefoneCtrl.text.trim(),
            _senhaCtrl.text,
            email: _emailCtrl.text.trim(),
            username: _usernameCtrl.text.trim(),
          );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Cadastro realizado! Faça login.'),
          backgroundColor: AppTheme.sucesso,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      context.go(AppConstants.routeLogin);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final tema = context.watch<BarbeariaThemeService>();
    final cor = tema.corPrimaria;

    return Scaffold(
      backgroundColor: AppTheme.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;

            if (!isDesktop) {
              return _buildFundoLogo(tema, _buildFormMobile(tema, cor, auth));
            }

            return Row(children: [
              Expanded(flex: 6, child: _buildHero(tema)),
              Expanded(
                  flex: 5,
                  child: _buildFundoLogo(
                      tema, _buildFormDesktop(tema, cor, auth))),
            ]);
          },
        ),
      ),
    );
  }

  Widget _buildHero(BarbeariaThemeService tema) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.surface, AppTheme.black],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.content_cut_rounded,
                      size: 22, color: tema.corPrimaria),
                  const SizedBox(width: 10),
                  Text('GetCutt',
                      style: _playfair(tema.corPrimaria, 22, FontWeight.w700)),
                ]),
                const SizedBox(height: 40),
                Text('Junte-se à\ncommunidade GetCutt',
                    style: _playfair(AppTheme.text, 38, FontWeight.w700,
                        letterSpacing: -1.0)),
                const SizedBox(height: 20),
                Text(
                  'Crie sua conta em segundos e comece a agendar horários com seus barbeiros favoritos.',
                  style: _inter(AppTheme.textMuted, 15, FontWeight.w400,
                      height: 1.7),
                ),
                const SizedBox(height: 36),
                _buildBeneficio(tema.corPrimaria,
                    Icons.check_circle_outline_rounded, 'Cadastro gratuito'),
                const SizedBox(height: 14),
                _buildBeneficio(tema.corPrimaria, Icons.schedule_rounded,
                    'Agende em segundos'),
                const SizedBox(height: 14),
                _buildBeneficio(tema.corPrimaria, Icons.history_rounded,
                    'Histórico completo'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBeneficio(Color cor, IconData icone, String texto) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
            color: cor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icone, size: 18, color: cor),
      ),
      const SizedBox(width: 14),
      Text(texto, style: _inter(AppTheme.text, 14, FontWeight.w500)),
    ]);
  }

  Widget _buildFundoLogo(BarbeariaThemeService tema, Widget child) {
    return Stack(children: [
      if (tema.logoUrl != null)
        Center(
            child: Opacity(
                opacity: 0.04,
                child: LogoWidget(
                    logoUrl: tema.logoUrl,
                    size: double.infinity,
                    fit: BoxFit.contain))),
      child,
    ]);
  }

  Widget _buildFormMobile(
      BarbeariaThemeService tema, Color cor, AuthController auth) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
      child: Center(child: _buildForm(tema, cor, auth, larguraMaxima: 380)),
    );
  }

  Widget _buildFormDesktop(
      BarbeariaThemeService tema, Color cor, AuthController auth) {
    return Container(
      color: AppTheme.black,
      padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: SingleChildScrollView(
              child: _buildForm(tema, cor, auth, larguraMaxima: 380)),
        ),
      ),
    );
  }

  Widget _buildForm(BarbeariaThemeService tema, Color cor, AuthController auth,
      {required double larguraMaxima}) {
    final logo = Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: AppTheme.surfaceElev,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor.withValues(alpha: 0.4), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: LogoWidget(logoUrl: tema.logoUrl, size: 76, fit: BoxFit.cover),
      ),
    );

    return Form(
      key: _formKey,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: larguraMaxima),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: logo),
            const SizedBox(height: 24),
            Text('Criar conta',
                style: _playfair(AppTheme.text, 26, FontWeight.w700,
                    letterSpacing: -0.6)),
            const SizedBox(height: 6),
            Text('Preencha seus dados para começar',
                style: _inter(AppTheme.textMuted, 14, FontWeight.w400)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElev,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(children: [
                Expanded(
                  child: _accountTypeButton(
                    label: 'Sou cliente',
                    icon: Icons.person_outline_rounded,
                    selected: !_souProprietario,
                    color: cor,
                    onTap: () => setState(() => _souProprietario = false),
                  ),
                ),
                Expanded(
                  child: _accountTypeButton(
                    label: 'Tenho barbearia',
                    icon: Icons.storefront_outlined,
                    selected: _souProprietario,
                    color: cor,
                    onTap: () => setState(() => _souProprietario = true),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            if (_souProprietario) ...[
              TextFormField(
                controller: _barbeariaCtrl,
                style: _inter(AppTheme.text, 15, FontWeight.w400),
                decoration: InputDecoration(
                  labelText: 'Nome da barbearia',
                  prefixIcon: Icon(Icons.storefront_outlined, color: cor),
                ),
                validator: (v) =>
                    _souProprietario && (v == null || v.trim().length < 2)
                        ? 'Informe o nome da barbearia'
                        : null,
              ),
              const SizedBox(height: 16),
            ],
            SizedBox(
              width: double.infinity,
              child: TextFormField(
                controller: _nomeCtrl,
                style: _inter(AppTheme.text, 15, FontWeight.w400),
                decoration: InputDecoration(
                    labelText: 'Nome completo',
                    prefixIcon: Icon(Icons.person_outline, color: cor)),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe seu nome' : null,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: _inter(AppTheme.text, 15, FontWeight.w400),
              decoration: InputDecoration(
                labelText: 'E-mail',
                prefixIcon: Icon(Icons.mail_outline_rounded, color: cor),
              ),
              validator: (v) {
                final value = v?.trim() ?? '';
                if (value.isEmpty) return 'Informe seu e-mail';
                if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
                  return 'Informe um e-mail válido';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            if (!_souProprietario)
              TextFormField(
                controller: _usernameCtrl,
                textCapitalization: TextCapitalization.none,
                style: _inter(AppTheme.text, 15, FontWeight.w400),
                decoration: InputDecoration(
                  labelText: 'Nome de usuário',
                  prefixText: '@',
                  prefixIcon: Icon(Icons.alternate_email_rounded, color: cor),
                ),
                validator: (v) {
                  final value = v?.trim().toLowerCase() ?? '';
                  if (value.isEmpty) return 'Escolha um nome de usuário';
                  if (!RegExp(r'^[a-z0-9._]{3,30}$').hasMatch(value)) {
                    return 'Use 3 a 30 letras, números, ponto ou _';
                  }
                  return null;
                },
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextFormField(
                controller: _telefoneCtrl,
                keyboardType: TextInputType.phone,
                style: _inter(AppTheme.text, 15, FontWeight.w400),
                decoration: InputDecoration(
                  labelText: 'Telefone com DDD',
                  prefixIcon: Icon(Icons.phone_outlined, color: cor),
                  hintText: '(00) 90000-0000',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty)
                    return 'Telefone é obrigatório';
                  if (!_telefoneValido(v))
                    return 'Informe um telefone válido com DDD';
                  return null;
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextFormField(
                controller: _senhaCtrl,
                obscureText: !_senhaVisivel,
                style: _inter(AppTheme.text, 15, FontWeight.w400),
                decoration: InputDecoration(
                  labelText: 'Senha (mínimo 8 caracteres)',
                  prefixIcon: Icon(Icons.lock_outline, color: cor),
                  suffixIcon: IconButton(
                    icon: Icon(
                        _senhaVisivel
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppTheme.textMuted),
                    onPressed: () =>
                        setState(() => _senhaVisivel = !_senhaVisivel),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Informe uma senha';
                  if (v.length < 8)
                    return 'Senha deve ter pelo menos 8 caracteres';
                  return null;
                },
              ),
            ),
            const SizedBox(height: 16),
            if (auth.erro.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.erro.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: AppTheme.erro.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppTheme.erro, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(auth.erro,
                          style: _inter(AppTheme.erro, 13, FontWeight.w500))),
                ]),
              ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed: auth.carregando ? null : _cadastrar,
                child: auth.carregando
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            color: AppTheme.blackPure, strokeWidth: 2))
                    : const Text('Criar conta'),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: TextButton(
                onPressed: () => context.go(AppConstants.routeLogin),
                child: Text.rich(TextSpan(children: [
                  TextSpan(
                      text: 'Já tem conta? ',
                      style: _inter(AppTheme.textMuted, 14, FontWeight.w400)),
                  TextSpan(
                      text: 'Entrar', style: _inter(cor, 14, FontWeight.w600)),
                ])),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accountTypeButton({
    required String label,
    required IconData icon,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color:
                selected ? color.withValues(alpha: 0.16) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 17, color: selected ? color : AppTheme.textMuted),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: _inter(selected ? color : AppTheme.textMuted, 12,
                    selected ? FontWeight.w700 : FontWeight.w500),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  TextStyle _playfair(Color cor, double tamanho, FontWeight peso,
          {double letterSpacing = -0.4}) =>
      GoogleFonts.playfairDisplay().copyWith(
          color: cor,
          fontSize: tamanho,
          fontWeight: peso,
          letterSpacing: letterSpacing,
          height: 1.15);

  TextStyle _inter(Color cor, double tamanho, FontWeight peso,
          {double height = 1.5}) =>
      GoogleFonts.inter().copyWith(
          color: cor, fontSize: tamanho, fontWeight: peso, height: height);
}
