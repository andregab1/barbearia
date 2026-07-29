// ==========================================
// TELA: Login
// RF02 - Login | RF04 - Logo como background
// Em telas largas (web), vira uma landing page:
// hero (headline + destaques) à esquerda,
// formulário de login funcional à direita —
// no estilo Cal.com (produto real embutido no
// hero, não uma ilustração).
// ==========================================
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/barbearia_theme_service.dart';
import '../../../shared/widgets/logo_widget.dart';
import '../controllers/auth_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _loginCtrl    = TextEditingController();
  final _senhaCtrl    = TextEditingController();
  bool  _senhaVisivel = false;

  @override
  void dispose() {
    _loginCtrl.dispose();
    _senhaCtrl.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthController>();
    final ok   = await auth.login(_loginCtrl.text.trim(), _senhaCtrl.text);

    if (!mounted) return;
    if (ok) {
      if (auth.role == AppConstants.roleAdmin)         context.go(AppConstants.routeHomeAdmin);
      else if (auth.role == AppConstants.roleBarbeiro) context.go(AppConstants.routeHomeBarbeiro);
      else                                             context.go(AppConstants.routeHomeCliente);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = context.watch<BarbeariaThemeService>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWeb = constraints.maxWidth >= 900;

            if (!isWeb) {
              // Mobile: só o formulário, como já era antes
              return _buildFundoLogo(
                tema,
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
                  child: _buildFormulario(context, tema, centralizarLogo: true),
                ),
              );
            }

            // Web: layout de landing page — hero à esquerda, form à direita
            return Row(
              children: [
                Expanded(
                  flex: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 64),
                    child: Center(child: _buildHero(context, tema)),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: _buildFundoLogo(
                    tema,
                    Container(
                      color: AppTheme.corCard,
                      padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 40),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 380),
                          child: SingleChildScrollView(
                            child: _buildFormulario(context, tema, centralizarLogo: false),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ==========================================
  // Coluna esquerda (só aparece no formato site):
  // headline + destaques do produto, estilo hero
  // de landing page.
  // ==========================================
  Widget _buildHero(BuildContext context, BarbeariaThemeService tema) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.corCard,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.content_cut, size: 16, color: tema.corPrimaria),
            const SizedBox(width: 8),
            Text('GetCutt', style: TextStyle(color: AppTheme.corTexto, fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        ),
        const SizedBox(height: 24),
        Text(
          'Agendamento sem\nfricção pra sua barbearia',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontSize: 44),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: 440,
          child: Text(
            'Clientes marcam horário em segundos, barbeiros administram a agenda em tempo real — tudo em um só lugar.',
            style: TextStyle(color: AppTheme.corTextoSecundario, fontSize: 16, height: 1.5),
          ),
        ),
        const SizedBox(height: 40),
        Row(
          children: [
            _buildDestaque(Icons.calendar_today_outlined, 'Agenda em tempo real'),
            const SizedBox(width: 32),
            _buildDestaque(Icons.notifications_none, 'Lembretes automáticos'),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildDestaque(Icons.groups_outlined, 'Gestão de equipe'),
            const SizedBox(width: 32),
            _buildDestaque(Icons.bar_chart_outlined, 'Relatórios e métricas'),
          ],
        ),
      ],
    );
  }

  Widget _buildDestaque(IconData icone, String texto) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icone, size: 18, color: AppTheme.corTextoSecundario),
      const SizedBox(width: 8),
      Text(texto, style: TextStyle(color: AppTheme.corTexto, fontSize: 14, fontWeight: FontWeight.w500)),
    ]);
  }

  // ==========================================
  // RF04: Logo PNG como background, com opacidade
  // ==========================================
  Widget _buildFundoLogo(BarbeariaThemeService tema, Widget child) {
    return Stack(
      children: [
        if (tema.logoUrl != null)
          Center(
            child: Opacity(
              opacity: 0.06,
              child: LogoWidget(logoUrl: tema.logoUrl, size: double.infinity, fit: BoxFit.contain),
            ),
          ),
        child,
      ],
    );
  }

  // ==========================================
  // Formulário de login — igual em mobile e web,
  // só muda o container ao redor.
  // ==========================================
  Widget _buildFormulario(BuildContext context, BarbeariaThemeService tema, {required bool centralizarLogo}) {
    final auth = context.watch<AuthController>();

    final logo = Container(
      width: 90, height: 90,
      decoration: BoxDecoration(
        color: AppTheme.corCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: tema.corPrimaria, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: LogoWidget(
          logoUrl: tema.logoUrl,
          size: 90,
          fit: BoxFit.cover,
          placeholder: Icon(Icons.content_cut, color: tema.corPrimaria, size: 44),
        ),
      ),
    );

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (centralizarLogo) Center(child: logo) else logo,
          const SizedBox(height: 32),

          Text('Bem-vindo',
              style: TextStyle(color: AppTheme.corTexto, fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Entre na sua conta',
              style: TextStyle(color: AppTheme.corTextoSecundario, fontSize: 14)),
          const SizedBox(height: 32),

          TextFormField(
            controller: _loginCtrl,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: AppTheme.corTexto),
            decoration: InputDecoration(
              labelText: 'E-mail ou Telefone',
              prefixIcon: Icon(Icons.person_outline, color: tema.corPrimaria),
            ),
            validator: (v) => v == null || v.isEmpty ? 'Informe seu e-mail ou telefone' : null,
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _senhaCtrl,
            obscureText: !_senhaVisivel,
            style: TextStyle(color: AppTheme.corTexto),
            decoration: InputDecoration(
              labelText: 'Senha',
              prefixIcon: Icon(Icons.lock_outline, color: tema.corPrimaria),
              suffixIcon: IconButton(
                icon: Icon(_senhaVisivel ? Icons.visibility_off : Icons.visibility,
                    color: AppTheme.corTextoSecundario),
                onPressed: () => setState(() => _senhaVisivel = !_senhaVisivel),
              ),
            ),
            validator: (v) => v == null || v.isEmpty ? 'Informe sua senha' : null,
          ),
          const SizedBox(height: 12),

          if (auth.erro.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.corErro.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                Icon(Icons.error_outline, color: AppTheme.corErro, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(auth.erro, style: TextStyle(color: AppTheme.corErro, fontSize: 13))),
              ]),
            ),

          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: auth.carregando ? null : _entrar,
            style: ElevatedButton.styleFrom(backgroundColor: tema.corPrimaria),
            child: auth.carregando
                ? SizedBox(height: 20, width: 20,
                    child: CircularProgressIndicator(color: AppTheme.corFundo, strokeWidth: 2))
                : const Text('Entrar'),
          ),
          const SizedBox(height: 16),

          Center(
            child: TextButton(
              onPressed: () => context.go(AppConstants.routeCadastro),
              child: Text.rich(TextSpan(children: [
                TextSpan(text: 'Não tem conta? ',
                    style: TextStyle(color: AppTheme.corTextoSecundario)),
                TextSpan(text: 'Cadastre-se',
                    style: TextStyle(color: tema.corPrimaria, fontWeight: FontWeight.bold)),
              ])),
            ),
          ),
        ],
      ),
    );
  }
}