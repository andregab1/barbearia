import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/barbearia_theme_service.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_layout.dart';

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
    for (final controller in [
      _nomeCtrl,
      _emailCtrl,
      _usernameCtrl,
      _barbeariaCtrl,
      _telefoneCtrl,
      _senhaCtrl
    ]) {
      controller.dispose();
    }
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
            senha: _senhaCtrl.text)
        : await auth.cadastrar(
            _nomeCtrl.text.trim(), _telefoneCtrl.text.trim(), _senhaCtrl.text,
            email: _emailCtrl.text.trim(), username: _usernameCtrl.text.trim());
    if (!mounted || !ok) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Cadastro realizado! Faça login.'),
        backgroundColor: AppTheme.sucesso,
        behavior: SnackBarBehavior.floating));
    context.go(AppConstants.routeLogin);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final themeService = context.watch<BarbeariaThemeService>();
    return AuthLayout(
      eyebrow: 'Comece agora',
      title: 'Sua rotina,\nmais simples.',
      subtitle:
          'Crie seu perfil para agendar serviços e acompanhar sua experiência no GetCutt.',
      activeRoute: AppConstants.routeCadastro,
      themeService: themeService,
      benefits: const [
        AuthBenefit(
            icon: Icons.event_available_outlined,
            title: 'Agende sem complicação',
            subtitle:
                'Encontre horários disponíveis e escolha o serviço ideal.'),
        AuthBenefit(
            icon: Icons.favorite_border_rounded,
            title: 'Tenha tudo no seu perfil',
            subtitle: 'Histórico e preferências sempre acessíveis.'),
      ],
      form: Form(
          key: _formKey,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Criar conta',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('Preencha seus dados para começar.',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
            SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                      value: false,
                      label: Text('Cliente'),
                      icon: Icon(Icons.person_outline)),
                  ButtonSegment(
                      value: true,
                      label: Text('Proprietário'),
                      icon: Icon(Icons.storefront_outlined))
                ],
                selected: {
                  _souProprietario
                },
                onSelectionChanged: (value) =>
                    setState(() => _souProprietario = value.first)),
            const SizedBox(height: 20),
            TextFormField(
                controller: _nomeCtrl,
                decoration: authInputDecoration(
                    context,
                    _souProprietario ? 'Seu nome' : 'Nome completo',
                    Icons.person_outline),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Informe seu nome'
                    : null),
            if (_souProprietario) ...[
              const SizedBox(height: 14),
              TextFormField(
                  controller: _barbeariaCtrl,
                  decoration: authInputDecoration(
                      context, 'Nome da barbearia', Icons.storefront_outlined),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Informe o nome da barbearia'
                      : null),
            ] else ...[
              const SizedBox(height: 14),
              TextFormField(
                  controller: _usernameCtrl,
                  decoration: authInputDecoration(
                      context, 'Nome de usuário', Icons.alternate_email),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Informe um nome de usuário'
                      : null),
            ],
            const SizedBox(height: 14),
            TextFormField(
                controller: _telefoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: authInputDecoration(
                    context, 'Telefone', Icons.phone_outlined),
                validator: (value) => value == null || !_telefoneValido(value)
                    ? 'Informe um telefone válido'
                    : null),
            const SizedBox(height: 14),
            TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: authInputDecoration(
                    context, 'E-mail', Icons.mail_outline,
                    hint: 'Opcional para clientes'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty)
                    return _souProprietario ? 'Informe seu e-mail' : null;
                  return value.contains('@')
                      ? null
                      : 'Informe um e-mail válido';
                }),
            const SizedBox(height: 14),
            TextFormField(
                controller: _senhaCtrl,
                obscureText: !_senhaVisivel,
                decoration: authInputDecoration(
                    context, 'Senha', Icons.lock_outline,
                    hint: 'Mínimo de 6 caracteres',
                    suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _senhaVisivel = !_senhaVisivel),
                        icon: Icon(_senhaVisivel
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined))),
                validator: (value) => value == null || value.length < 6
                    ? 'Use ao menos 6 caracteres'
                    : null),
            if (auth.erro.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(auth.erro,
                  style: TextStyle(color: Theme.of(context).colorScheme.error))
            ],
            const SizedBox(height: 22),
            SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                    onPressed: auth.carregando ? null : _cadastrar,
                    icon: auth.carregando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.person_add_alt_1_rounded),
                    label:
                        Text(auth.carregando ? 'Criando...' : 'Criar conta'))),
            const SizedBox(height: 18),
            Center(
                child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                  Text('Já tem uma conta? ',
                      style: Theme.of(context).textTheme.bodyMedium),
                  TextButton(
                    onPressed: () => context.go(AppConstants.routeLogin),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Entrar'),
                  ),
                ])),
          ])),
    );
  }
}
