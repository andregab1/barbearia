// ==========================================
// TELA: Cadastro de Cliente
// RF01 - Cadastro com telefone obrigatório e cores dinâmicas
// ==========================================
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
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
  final _formKey      = GlobalKey<FormState>();
  final _nomeCtrl     = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  final _senhaCtrl    = TextEditingController();
  bool  _senhaVisivel = false;

  @override
  void dispose() {
    _nomeCtrl.dispose();
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
    final ok   = await auth.cadastrar(
      _nomeCtrl.text.trim(),
      _telefoneCtrl.text.trim(),
      _senhaCtrl.text,
    );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cadastro realizado! Faça login.'),
          backgroundColor: AppTheme.corSucesso,
        ),
      );
      context.go(AppConstants.routeLogin);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final tema = context.watch<BarbeariaThemeService>();
    final cor  = tema.corPrimaria;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(children: [
        // Logo como background
        if (tema.logoUrl != null)
          Center(
            child: Opacity(
              opacity: 0.06,
              child: LogoWidget(logoUrl: tema.logoUrl, size: double.infinity, fit: BoxFit.contain),
            ),
          ),

        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(height: 40),

                // Logo
                Center(
                  child: Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.corCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: cor, width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: LogoWidget(
                        logoUrl: tema.logoUrl, size: 80, fit: BoxFit.cover,
                        placeholder: Icon(Icons.content_cut, color: cor, size: 40),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 28),

                Text('Criar conta', style: TextStyle(
                    color: AppTheme.corTexto, fontSize: 26, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('Preencha seus dados para começar',
                    style: TextStyle(color: AppTheme.corTextoSecundario, fontSize: 14)),
                SizedBox(height: 28),

                // Nome
                TextFormField(
                  controller: _nomeCtrl,
                  style: TextStyle(color: AppTheme.corTexto),
                  decoration: InputDecoration(
                    labelText: 'Nome completo',
                    prefixIcon: Icon(Icons.person_outline, color: cor),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Informe seu nome' : null,
                ),
                SizedBox(height: 16),

                // Telefone (obrigatório e validado)
                TextFormField(
                  controller: _telefoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: AppTheme.corTexto),
                  decoration: InputDecoration(
                    labelText: 'Telefone com DDD (obrigatório)',
                    prefixIcon: Icon(Icons.phone_outlined, color: cor),
                    hintText: '(00) 90000-0000',
                    hintStyle: TextStyle(color: AppTheme.corTextoSecundario),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Telefone é obrigatório';
                    if (!_telefoneValido(v)) return 'Informe um telefone válido com DDD';
                    return null;
                  },
                ),
                SizedBox(height: 16),

                // Senha
                TextFormField(
                  controller: _senhaCtrl,
                  obscureText: !_senhaVisivel,
                  style: TextStyle(color: AppTheme.corTexto),
                  decoration: InputDecoration(
                    labelText: 'Senha (mínimo 6 caracteres)',
                    prefixIcon: Icon(Icons.lock_outline, color: cor),
                    suffixIcon: IconButton(
                      icon: Icon(_senhaVisivel ? Icons.visibility_off : Icons.visibility,
                          color: AppTheme.corTextoSecundario),
                      onPressed: () => setState(() => _senhaVisivel = !_senhaVisivel),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Informe uma senha';
                    if (v.length < 6) return 'Senha deve ter pelo menos 6 caracteres';
                    return null;
                  },
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
                      Expanded(child: Text(auth.erro,
                          style: TextStyle(color: AppTheme.corErro, fontSize: 13))),
                    ]),
                  ),

                SizedBox(height: 24),

                ElevatedButton(
                  onPressed: auth.carregando ? null : _cadastrar,
                  style: ElevatedButton.styleFrom(backgroundColor: cor),
                  child: auth.carregando
                      ? SizedBox(height: 20, width: 20,
                          child: CircularProgressIndicator(color: AppTheme.corFundo, strokeWidth: 2))
                      : Text('Criar conta'),
                ),
                SizedBox(height: 16),

                Center(
                  child: TextButton(
                    onPressed: () => context.go(AppConstants.routeLogin),
                    child: Text.rich(TextSpan(children: [
                      TextSpan(text: 'Já tem conta? ',
                          style: TextStyle(color: AppTheme.corTextoSecundario)),
                      TextSpan(text: 'Entrar',
                          style: TextStyle(color: cor, fontWeight: FontWeight.bold)),
                    ])),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}