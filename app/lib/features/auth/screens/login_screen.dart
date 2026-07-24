// ==========================================
// TELA: Login
// RF02 - Login | RF04 - Logo como background
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
    final auth = context.watch<AuthController>();
    final tema = context.watch<BarbeariaThemeService>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // RF04: Logo PNG como background centralizado com opacidade
          if (tema.logoUrl != null)
            Center(
              child: Opacity(
                opacity: 0.06,
                child: LogoWidget(
                  logoUrl: tema.logoUrl,
                  size: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
            ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 60),

                    // Logo
                    Center(
                      child: Container(
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
                      ),
                    ),
                    SizedBox(height: 32),

                    Text('Bem-vindo',
                        style: TextStyle(color: AppTheme.corTexto, fontSize: 28, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('Entre na sua conta',
                        style: TextStyle(color: AppTheme.corTextoSecundario, fontSize: 14)),
                    SizedBox(height: 32),

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
                    SizedBox(height: 16),

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
                          : Text('Entrar'),
                    ),
                    SizedBox(height: 16),

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
              ),
            ),
          ),
        ],
      ),
    );
  }
}