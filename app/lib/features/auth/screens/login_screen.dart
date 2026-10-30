import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/barbearia_theme_service.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_layout.dart';

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

  @override
  void dispose() {
    _loginCtrl.dispose();
    _senhaCtrl.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthController>();
    final ok = await auth.login(_loginCtrl.text.trim(), _senhaCtrl.text);
    if (!mounted || !ok) return;
    final route = auth.role == AppConstants.roleAdmin
        ? AppConstants.routeHomeAdmin
        : auth.role == AppConstants.roleBarbeiro
            ? AppConstants.routeHomeBarbeiro
            : AppConstants.routeHomeCliente;
    context.go(route);
  }

  Future<void> _mostrarAjuda() async {
    await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: const Text('Precisa de ajuda?'),
              content: const Text(
                  'Fale com o administrador da sua barbearia para redefinir ou criar seu acesso.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Fechar'))
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final themeService = context.watch<BarbeariaThemeService>();
    return AuthLayout(
      eyebrow: 'Acesso seguro',
      title: 'Bem-vindo\nde volta.',
      subtitle:
          'Entre para acompanhar seus agendamentos, serviços e tudo o que acontece na sua barbearia.',
      activeRoute: AppConstants.routeLogin,
      themeService: themeService,
      benefits: const [
        AuthBenefit(
            icon: Icons.calendar_month_outlined,
            title: 'Agendamentos em um só lugar',
            subtitle:
                'Consulte horários e acompanhe seus próximos atendimentos.'),
        AuthBenefit(
            icon: Icons.shield_outlined,
            title: 'Conta protegida',
            subtitle:
                'Seus dados ficam vinculados ao seu perfil e à sua função.'),
      ],
      form: Form(
          key: _formKey,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Entrar na conta',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('Use seu usuário, e-mail ou telefone.',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 28),
            TextFormField(
                controller: _loginCtrl,
                decoration: authInputDecoration(
                    context, 'Usuário ou e-mail', Icons.person_outline,
                    hint: 'Digite seu acesso'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Informe seu acesso'
                    : null),
            const SizedBox(height: 16),
            TextFormField(
                controller: _senhaCtrl,
                obscureText: !_senhaVisivel,
                decoration: authInputDecoration(
                    context, 'Senha', Icons.lock_outline,
                    hint: 'Digite sua senha',
                    suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _senhaVisivel = !_senhaVisivel),
                        icon: Icon(_senhaVisivel
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined))),
                validator: (value) => value == null || value.isEmpty
                    ? 'Informe sua senha'
                    : null),
            const SizedBox(height: 12),
            Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                    onPressed: _mostrarAjuda,
                    child: const Text('Precisa de ajuda com o acesso?'))),
            if (auth.erro.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(auth.erro,
                  style: TextStyle(color: Theme.of(context).colorScheme.error))
            ],
            const SizedBox(height: 20),
            SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                    onPressed: auth.carregando ? null : _entrar,
                    icon: auth.carregando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.login_rounded),
                    label: Text(auth.carregando ? 'Entrando...' : 'Entrar'))),
            const SizedBox(height: 22),
            Center(
                child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                  Text('Não tem uma conta? ',
                      style: Theme.of(context).textTheme.bodyMedium),
                  TextButton(
                    onPressed: () => context.go(AppConstants.routeCadastro),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Cadastre-se aqui'),
                  ),
                ])),
          ])),
    );
  }
}
