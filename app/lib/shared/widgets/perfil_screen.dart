// ==========================================
// TELA: Perfil do Usuário
// Editar nome, telefone e senha
// ==========================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/barbearia_theme_service.dart';
import '../../../features/auth/controllers/auth_controller.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final _nomeCtrl       = TextEditingController();
  final _telefoneCtrl   = TextEditingController();
  final _senhaAtualCtrl = TextEditingController();
  final _novaSenhaCtrl  = TextEditingController();

  bool   _salvando     = false;
  bool   _carregando   = true;
  bool   _alterarSenha = false;
  int?   _usuarioId;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  // Busca dados atualizados do servidor
  Future<void> _carregarDados() async {
    final prefs = await SharedPreferences.getInstance();
    _usuarioId  = prefs.getInt(AppConstants.keyUsuarioId);

    if (_usuarioId != null) {
      final result = await ApiService.get('/usuarios/$_usuarioId');
      if (!result.containsKey('erro') && mounted) {
        setState(() {
          _nomeCtrl.text     = result['nome']     ?? '';
          _telefoneCtrl.text = result['telefone'] ?? '';
        });
      } else {
        // Fallback para cache local
        _nomeCtrl.text = prefs.getString(AppConstants.keyUsuarioNome) ?? '';
      }
    }
    if (mounted) setState(() => _carregando = false);
  }

  Future<void> _salvar() async {
    if (_nomeCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Nome é obrigatório.'), backgroundColor: AppTheme.corErro));
      return;
    }

    setState(() => _salvando = true);
    final messenger = ScaffoldMessenger.of(context);

    final body = <String, dynamic>{
      'nome':     _nomeCtrl.text.trim(),
      'telefone': _telefoneCtrl.text.trim(),
    };

    if (_alterarSenha && _novaSenhaCtrl.text.isNotEmpty) {
      if (_senhaAtualCtrl.text.isEmpty) {
        setState(() => _salvando = false);
        messenger.showSnackBar(SnackBar(
          content: Text('Informe a senha atual.'), backgroundColor: AppTheme.corErro));
        return;
      }
      body['senha_atual'] = _senhaAtualCtrl.text;
      body['nova_senha']  = _novaSenhaCtrl.text;
    }

    final result = await ApiService.put('/usuarios/$_usuarioId', body);
    setState(() => _salvando = false);

    if (result.containsKey('erro')) {
      messenger.showSnackBar(SnackBar(
          content: Text(result['erro']), backgroundColor: AppTheme.corErro));
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.keyUsuarioNome, _nomeCtrl.text.trim());
      if (mounted) {
        context.read<AuthController>().atualizarNome(_nomeCtrl.text.trim());
        setState(() { _alterarSenha = false; _senhaAtualCtrl.clear(); _novaSenhaCtrl.clear(); });
      }
      messenger.showSnackBar(SnackBar(
          content: Text('Perfil atualizado!'), backgroundColor: AppTheme.corSucesso));
    }
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _telefoneCtrl.dispose();
    _senhaAtualCtrl.dispose();
    _novaSenhaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cor  = Theme.of(context).colorScheme.primary;
    context.watch<BarbeariaThemeService>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text('Meu Perfil')),
      body: _carregando
          ? Center(child: CircularProgressIndicator(color: cor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // Avatar
                Center(
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: cor.withOpacity(0.2),
                    child: Text(
                      _nomeCtrl.text.isNotEmpty ? _nomeCtrl.text[0].toUpperCase() : '?',
                      style: TextStyle(color: cor, fontSize: 34, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                SizedBox(height: 28),

                Text('Dados Pessoais',
                    style: TextStyle(color: AppTheme.corTextoSecundario, fontSize: 13)),
                SizedBox(height: 12),

                TextFormField(
                  controller: _nomeCtrl,
                  style: TextStyle(color: AppTheme.corTexto),
                  decoration: InputDecoration(
                    labelText: 'Nome completo',
                    prefixIcon: Icon(Icons.person_outline, color: cor),
                  ),
                ),
                SizedBox(height: 12),

                TextFormField(
                  controller: _telefoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: AppTheme.corTexto),
                  decoration: InputDecoration(
                    labelText: 'Telefone',
                    prefixIcon: Icon(Icons.phone_outlined, color: cor),
                  ),
                ),
                SizedBox(height: 24),

                // Alterar senha
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Alterar senha',
                      style: TextStyle(color: AppTheme.corTextoSecundario, fontSize: 13)),
                  Switch(
                    value: _alterarSenha,
                    activeColor: cor,
                    onChanged: (v) => setState(() => _alterarSenha = v),
                  ),
                ]),

                if (_alterarSenha) ...[
                  SizedBox(height: 12),
                  TextFormField(
                    controller: _senhaAtualCtrl,
                    obscureText: true,
                    style: TextStyle(color: AppTheme.corTexto),
                    decoration: InputDecoration(
                      labelText: 'Senha atual',
                      prefixIcon: Icon(Icons.lock_outline, color: cor),
                    ),
                  ),
                  SizedBox(height: 12),
                  TextFormField(
                    controller: _novaSenhaCtrl,
                    obscureText: true,
                    style: TextStyle(color: AppTheme.corTexto),
                    decoration: InputDecoration(
                      labelText: 'Nova senha (mínimo 6 caracteres)',
                      prefixIcon: Icon(Icons.lock_reset_outlined, color: cor),
                    ),
                  ),
                ],
                SizedBox(height: 32),

                ElevatedButton(
                  onPressed: _salvando ? null : _salvar,
                  child: _salvando
                      ? SizedBox(height: 20, width: 20,
                          child: CircularProgressIndicator(
                              color: AppTheme.corFundo, strokeWidth: 2))
                      : Text('Salvar Alterações'),
                ),
                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.read<AuthController>().logout(),
                    icon: Icon(Icons.logout, color: AppTheme.corErro),
                    label: Text('Sair da conta',
                        style: TextStyle(color: AppTheme.corErro)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.corErro),
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ]),
            ),
    );
  }
}