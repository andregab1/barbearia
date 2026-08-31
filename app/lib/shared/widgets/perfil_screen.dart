import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';
import '../../core/services/barbearia_theme_service.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/controllers/auth_controller.dart';
import 'premium_ui.dart';
import 'app_toast.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final _nomeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _senhaAtualCtrl = TextEditingController();
  final _novaSenhaCtrl = TextEditingController();

  bool _salvando = false;
  bool _carregando = true;
  bool _alterarSenha = false;
  int? _usuarioId;
  String? _fotoUrl;
  File? _fotoFile;
  String _role = '';
  DateTime? _dataNascimento;
  DateTime? _membroDesde;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    _usuarioId = prefs.getInt(AppConstants.keyUsuarioId);
    if (_usuarioId != null) {
      final result = await ApiService.get('/usuarios/$_usuarioId');
      if (!mounted) return;
      if (!result.containsKey('erro')) {
        setState(() {
          _nomeCtrl.text = result['nome'] ?? '';
          _telefoneCtrl.text = result['telefone'] ?? '';
          _emailCtrl.text = result['email'] ?? '';
          _usernameCtrl.text = result['username'] ?? '';
          _bioCtrl.text = result['bio'] ?? '';
          _role = result['role'] ?? '';
          _dataNascimento =
              DateTime.tryParse(result['data_nascimento']?.toString() ?? '');
          _fotoUrl = result['foto_url'];
          _membroDesde =
              DateTime.tryParse(result['criado_em']?.toString() ?? '');
        });
      } else {
        _nomeCtrl.text = prefs.getString(AppConstants.keyUsuarioNome) ?? '';
      }
    }
    if (mounted) setState(() => _carregando = false);
  }

  Future<void> _selecionarFoto() async {
    final imagem = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 25,
      maxWidth: 200,
      maxHeight: 200,
    );
    if (imagem != null && mounted)
      setState(() => _fotoFile = File(imagem.path));
  }

  Future<void> _salvar() async {
    if (_nomeCtrl.text.trim().isEmpty) {
      _showMessage('Nome é obrigatório.', AppTheme.erro);
      return;
    }
    setState(() => _salvando = true);
    final body = <String, dynamic>{
      'nome': _nomeCtrl.text.trim(),
      'telefone': _telefoneCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'username': _usernameCtrl.text.trim().toLowerCase(),
      'bio': _bioCtrl.text.trim(),
      'data_nascimento': _dataNascimento == null
          ? null
          : '${_dataNascimento!.year}-${_dataNascimento!.month.toString().padLeft(2, '0')}-${_dataNascimento!.day.toString().padLeft(2, '0')}',
    };

    if (_fotoFile != null) {
      final bytes = await _fotoFile!.readAsBytes();
      final extension = _fotoFile!.path.split('.').last.toLowerCase();
      final mime = extension == 'png' ? 'image/png' : 'image/jpeg';
      body['foto_url'] = 'data:$mime;base64,${base64Encode(bytes)}';
    }
    if (_alterarSenha && _novaSenhaCtrl.text.isNotEmpty) {
      if (_senhaAtualCtrl.text.isEmpty) {
        if (mounted) setState(() => _salvando = false);
        _showMessage('Informe a senha atual.', AppTheme.erro);
        return;
      }
      body['senha_atual'] = _senhaAtualCtrl.text;
      body['nova_senha'] = _novaSenhaCtrl.text;
    }

    final result = await ApiService.put('/usuarios/$_usuarioId', body);
    if (!mounted) return;
    setState(() => _salvando = false);
    if (result.containsKey('erro')) {
      _showMessage(result['erro'], AppTheme.erro);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyUsuarioNome, _nomeCtrl.text.trim());
    if (!mounted) return;
    context.read<AuthController>().atualizarNome(_nomeCtrl.text.trim());
    setState(() {
      _alterarSenha = false;
      _senhaAtualCtrl.clear();
      _novaSenhaCtrl.clear();
    });
    _showMessage('Perfil atualizado!', AppTheme.sucesso);
  }

  void _showMessage(String message, Color color) {
    if (!mounted) return;
    AppToast.show(context, message,
        type:
            color == AppTheme.erro ? AppToastType.error : AppToastType.success);
  }

  Future<void> _selecionarNascimento() async {
    final agora = DateTime.now();
    final data = await showDatePicker(
      context: context,
      initialDate: _dataNascimento ?? DateTime(1995),
      firstDate: DateTime(1920),
      lastDate: DateTime(agora.year - 13, agora.month, agora.day),
    );
    if (data != null && mounted) setState(() => _dataNascimento = data);
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _emailCtrl.dispose();
    _usernameCtrl.dispose();
    _telefoneCtrl.dispose();
    _bioCtrl.dispose();
    _senhaAtualCtrl.dispose();
    _novaSenhaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<BarbeariaThemeService>();
    return PremiumPage(
      title: 'Meu perfil',
      subtitle: 'Gerencie seus dados pessoais e a segurança da conta.',
      child: _carregando
          ? const PremiumLoadingState(label: 'Carregando perfil')
          : SingleChildScrollView(
              child: LayoutBuilder(builder: (context, constraints) {
                final desktop = constraints.maxWidth >= 760;
                final identity = _ProfileIdentity(
                  name: _nomeCtrl.text,
                  photoFile: _fotoFile,
                  photoUrl: _fotoUrl,
                  role: _role,
                  bio: _bioCtrl.text,
                  memberSince: _membroDesde,
                  onPhotoPressed: _selecionarFoto,
                  onLogout: () => context.read<AuthController>().logout(),
                );
                final form = _ProfileForm(
                  nomeController: _nomeCtrl,
                  emailController: _emailCtrl,
                  usernameController: _usernameCtrl,
                  telefoneController: _telefoneCtrl,
                  bioController: _bioCtrl,
                  birthDate: _dataNascimento,
                  senhaAtualController: _senhaAtualCtrl,
                  novaSenhaController: _novaSenhaCtrl,
                  changePassword: _alterarSenha,
                  saving: _salvando,
                  onChangePassword: (value) =>
                      setState(() => _alterarSenha = value),
                  onBirthDatePressed: _selecionarNascimento,
                  onSave: _salvar,
                );
                if (!desktop) {
                  return Column(children: [
                    identity,
                    const SizedBox(height: 14),
                    form,
                  ]);
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 300, child: identity),
                    const SizedBox(width: 18),
                    Expanded(child: form),
                  ],
                );
              }),
            ),
    );
  }
}

class _ProfileIdentity extends StatelessWidget {
  final String name;
  final File? photoFile;
  final String? photoUrl;
  final String role;
  final String bio;
  final DateTime? memberSince;
  final VoidCallback onPhotoPressed;
  final VoidCallback onLogout;

  const _ProfileIdentity({
    required this.name,
    required this.photoFile,
    required this.photoUrl,
    required this.role,
    required this.bio,
    required this.memberSince,
    required this.onPhotoPressed,
    required this.onLogout,
  });

  ImageProvider? get _imageProvider {
    if (photoFile != null) return FileImage(photoFile!);
    if (photoUrl != null && photoUrl!.startsWith('data:image')) {
      return MemoryImage(base64Decode(photoUrl!.split(',').last));
    }
    if (photoUrl != null && photoUrl!.startsWith('http')) {
      return NetworkImage(photoUrl!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => PremiumSurface(
        child: Column(
          children: [
            Semantics(
              button: true,
              label: 'Alterar foto de perfil',
              child: InkWell(
                onTap: onPhotoPressed,
                borderRadius: BorderRadius.circular(50),
                child: Stack(children: [
                  CircleAvatar(
                    radius: 46,
                    backgroundColor: PremiumColors.gold.withValues(alpha: .15),
                    backgroundImage: _imageProvider,
                    child: _imageProvider == null
                        ? Text(
                            name.isEmpty ? '?' : name[0].toUpperCase(),
                            style: GoogleFonts.playfairDisplay(
                              color: PremiumColors.gold,
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : null,
                  ),
                  const Positioned(
                    right: 0,
                    bottom: 0,
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: PremiumColors.gold,
                      child: Icon(
                        Icons.camera_alt_outlined,
                        color: PremiumColors.background,
                        size: 14,
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              name,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: PremiumColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            PremiumStatusBadge(
              label: role == 'admin'
                  ? 'Administrador'
                  : role == 'barbeiro'
                      ? 'Barbeiro'
                      : 'Cliente',
              color: PremiumColors.gold,
            ),
            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Sobre você',
                  style: GoogleFonts.inter(
                      color: PremiumColors.textSecondary, fontSize: 11)),
            ),
            const SizedBox(height: 7),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                bio.isEmpty
                    ? 'Complete seu perfil para personalizar sua experiência no GetCutt.'
                    : bio,
                style: GoogleFonts.inter(
                    color: PremiumColors.textSecondary,
                    fontSize: 12,
                    height: 1.5),
              ),
            ),
            if (memberSince != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Row(children: [
                const Icon(Icons.calendar_today_outlined,
                    color: PremiumColors.gold, size: 17),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Membro desde ${memberSince!.month.toString().padLeft(2, '0')}/${memberSince!.year}',
                    style: GoogleFonts.inter(
                        color: PremiumColors.textSecondary, fontSize: 12),
                  ),
                ),
              ]),
            ],
            const SizedBox(height: 12),
            _AccountInfoRow(
              icon: Icons.circle,
              label: 'Status',
              value: 'Online',
              color: PremiumColors.success,
            ),
            const SizedBox(height: 8),
            _AccountInfoRow(
              icon: Icons.verified_outlined,
              label: 'Conta',
              value: 'Ativa',
              color: PremiumColors.gold,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: onLogout,
                icon: const Icon(Icons.logout_rounded, size: 17),
                label: const Text('Sair da conta'),
                style: TextButton.styleFrom(
                  foregroundColor: PremiumColors.error,
                  minimumSize: const Size.fromHeight(44),
                ),
              ),
            ),
          ],
        ),
      );
}

class _AccountInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _AccountInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: PremiumColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: PremiumColors.border),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.inter(
                        color: PremiumColors.textMuted, fontSize: 9)),
                Text(value,
                    style: GoogleFonts.inter(
                        color: PremiumColors.textPrimary, fontSize: 11)),
              ],
            ),
          ),
        ]),
      );
}

class _ProfileForm extends StatelessWidget {
  final TextEditingController nomeController;
  final TextEditingController emailController;
  final TextEditingController usernameController;
  final TextEditingController telefoneController;
  final TextEditingController bioController;
  final DateTime? birthDate;
  final TextEditingController senhaAtualController;
  final TextEditingController novaSenhaController;
  final bool changePassword;
  final bool saving;
  final ValueChanged<bool> onChangePassword;
  final VoidCallback onBirthDatePressed;
  final VoidCallback onSave;

  const _ProfileForm({
    required this.nomeController,
    required this.emailController,
    required this.usernameController,
    required this.telefoneController,
    required this.bioController,
    required this.birthDate,
    required this.senhaAtualController,
    required this.novaSenhaController,
    required this.changePassword,
    required this.saving,
    required this.onChangePassword,
    required this.onBirthDatePressed,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) => PremiumSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dados pessoais',
              style: GoogleFonts.inter(
                color: PremiumColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: nomeController,
              decoration: const InputDecoration(
                labelText: 'Nome completo',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: telefoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Telefone',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'E-mail',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: usernameController,
              decoration: const InputDecoration(
                labelText: 'Nome de usuário',
                prefixText: '@',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: onBirthDatePressed,
              borderRadius: BorderRadius.circular(10),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Data de nascimento',
                  prefixIcon: Icon(Icons.cake_outlined),
                ),
                child: Text(
                  birthDate == null
                      ? 'Selecionar data'
                      : '${birthDate!.day.toString().padLeft(2, '0')}/${birthDate!.month.toString().padLeft(2, '0')}/${birthDate!.year}',
                  style: GoogleFonts.inter(
                    color: birthDate == null
                        ? PremiumColors.textMuted
                        : PremiumColors.textPrimary,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: bioController,
              maxLength: 280,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Sobre você',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: PremiumColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: PremiumColors.border),
              ),
              child: Row(children: [
                const Icon(Icons.lock_outline_rounded,
                    color: PremiumColors.gold),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Seguranca',
                          style: GoogleFonts.inter(
                              color: PremiumColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      Text('Atualize sua senha usando a senha atual.',
                          style: GoogleFonts.inter(
                              color: PremiumColors.textMuted, fontSize: 12)),
                    ])),
                OutlinedButton(
                  onPressed: () => onChangePassword(!changePassword),
                  child: Text(changePassword ? 'Fechar' : 'Alterar senha'),
                ),
              ]),
            ),
            if (changePassword) ...[
              const SizedBox(height: 14),
              TextFormField(
                controller: senhaAtualController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Senha atual',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: novaSenhaController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Nova senha (mínimo 8 caracteres)',
                  prefixIcon: Icon(Icons.lock_reset_rounded),
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: saving ? null : onSave,
                child: saving
                    ? const SizedBox.square(
                        dimension: 19,
                        child: CircularProgressIndicator(
                          color: AppTheme.blackPure,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Salvar alterações'),
              ),
            ),
          ],
        ),
      );
}
