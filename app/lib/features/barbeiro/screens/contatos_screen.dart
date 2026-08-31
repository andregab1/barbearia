import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/premium_ui.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/barbearia_theme_service.dart';
import '../../../shared/widgets/app_toast.dart';

class ContatosScreen extends StatefulWidget {
  const ContatosScreen({super.key});
  @override
  State<ContatosScreen> createState() => _ContatosScreenState();
}

class _ContatosScreenState extends State<ContatosScreen> {
  List<Contact> _todos = [];
  List<Contact> _ativos = [];
  List<Contact> _outros = [];
  Set<String> _numAtivos = {};
  List<Map<String, dynamic>> _clientesWeb = [];
  List<Map<String, dynamic>> _clientesWebFiltrados = [];
  bool _carregando = true;
  bool _permissao = false;
  final TextEditingController _buscaCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  Future<void> _iniciar() async {
    try {
      await _buscarClientesAtivos();
      if (kIsWeb) {
        await _buscarClientesWeb();
        return;
      }
      await _pedirPermissao();
    } catch (_) {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _buscarClientesWeb() async {
    final result = await ApiService.get('/agendamentos/clientes');
    final raw = result['data'] ?? result;
    if (!mounted) return;
    setState(() {
      _clientesWeb = raw is List
          ? raw.map((item) => Map<String, dynamic>.from(item)).toList()
          : [];
      _clientesWebFiltrados = List.of(_clientesWeb);
      _carregando = false;
    });
  }

  String _limpar(String tel) {
    String d = tel.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('55') && d.length >= 12) d = d.substring(2);
    if (d.startsWith('0') && d.length > 10) d = d.substring(1);
    return d;
  }

  bool _telefonesIguais(String a, String b) {
    if (a == b) return true;
    if (a.length >= 8 && b.length >= 8) {
      return a.substring(a.length - 8) == b.substring(b.length - 8);
    }
    return false;
  }

  bool _temAgendamento(Contact c) {
    for (final p in c.phones) {
      final n = _limpar(p.number);
      if (n.isEmpty) continue;
      for (final ativo in _numAtivos) {
        if (_telefonesIguais(n, ativo)) return true;
      }
    }
    return false;
  }

  Future<void> _buscarClientesAtivos() async {
    final result = await ApiService.get('/agendamentos/clientes-ativos');
    final lista = (result['data'] ?? result);
    if (lista is List) {
      final nums = <String>{};
      for (final item in lista) {
        final t = _limpar(item['telefone']?.toString() ?? '');
        if (t.isNotEmpty) nums.add(t);
      }
      if (mounted) setState(() => _numAtivos = nums);
    }
  }

  Future<void> _pedirPermissao() async {
    final ok = await FlutterContacts.requestPermission(readonly: true);
    if (ok) {
      final lista = await FlutterContacts.getContacts(
          withProperties: true, withPhoto: false);
      if (mounted) {
        _separar(lista);
        setState(() {
          _todos = lista;
          _permissao = true;
        });
      }
    }
    if (mounted) setState(() => _carregando = false);
  }

  void _separar(List<Contact> lista) {
    final a = lista.where(_temAgendamento).toList();
    final o = lista.where((c) => !_temAgendamento(c)).toList();
    a.sort((x, y) => x.displayName.compareTo(y.displayName));
    o.sort((x, y) => x.displayName.compareTo(y.displayName));
    _ativos = a;
    _outros = o;
  }

  void _filtrar(String q) {
    final ql = q.toLowerCase();
    if (kIsWeb) {
      setState(() {
        _clientesWebFiltrados = _clientesWeb.where((cliente) {
          final texto =
              '${cliente['nome']} ${cliente['telefone']} ${cliente['email']}'
                  .toLowerCase();
          return texto.contains(ql);
        }).toList();
      });
      return;
    }
    final filtrados =
        _todos.where((c) => c.displayName.toLowerCase().contains(ql)).toList();
    setState(() {
      _separar(filtrados);
    });
  }

  Future<void> _abrirWhatsAppNumero(String telefone) async {
    final numero = _limpar(telefone);
    if (numero.isEmpty) {
      AppToast.show(context, 'Cliente sem telefone cadastrado.',
          type: AppToastType.warning);
      return;
    }
    final msg = Uri.encodeComponent(
        'Olá! Tudo bem? Estou entrando em contato pela sua barbearia.');
    final url = Uri.parse('https://wa.me/55$numero?text=$msg');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      await Clipboard.setData(ClipboardData(text: telefone));
      if (mounted) AppToast.show(context, 'Número copiado!');
    }
  }

  Future<void> _abrirWhatsApp(Contact c) async {
    if (c.phones.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Contato sem telefone.')));
      return;
    }
    final d = _limpar(c.phones.first.number);
    final msg = Uri.encodeComponent(
        'Olá! Você tem um agendamento conosco. Qualquer dúvida, estamos à disposição!');
    final url = Uri.parse('https://wa.me/55$d?text=$msg');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      await Clipboard.setData(ClipboardData(text: c.phones.first.number));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Número copiado!')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<BarbeariaThemeService>();
    final cor = Theme.of(context).colorScheme.primary;

    return PremiumPage(
      title: 'Contatos',
      subtitle: 'Encontre clientes e inicie conversas rapidamente.',
      child: _carregando
          ? Center(child: CircularProgressIndicator(color: cor))
          : kIsWeb
              ? _buildWebContacts(cor)
              : !_permissao
                  ? Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.contacts_outlined,
                                color: AppTheme.corTextoSecundario, size: 64),
                            const SizedBox(height: 16),
                            Text(
                              kIsWeb
                                  ? 'Contatos disponíveis no aplicativo'
                                  : 'Permissão necessária',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.playfairDisplay(
                                color: AppTheme.corTexto,
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (kIsWeb) ...[
                              const SizedBox(height: 8),
                              Text(
                                'O acesso aos contatos do aparelho não está disponível na versão Web.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  color: AppTheme.corTextoSecundario,
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            if (!kIsWeb)
                              Center(
                                child: ElevatedButton(
                                  onPressed: _iniciar,
                                  child: const Text('Permitir acesso'),
                                ),
                              ),
                          ]),
                    )
                  : Column(children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextField(
                          controller: _buscaCtrl,
                          onChanged: _filtrar,
                          style: GoogleFonts.inter(color: AppTheme.corTexto),
                          decoration: InputDecoration(
                            hintText: 'Buscar contato...',
                            prefixIcon: Icon(Icons.search, color: cor),
                            suffixIcon: _buscaCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.clear,
                                        color: AppTheme.corTextoSecundario),
                                    onPressed: () {
                                      _buscaCtrl.clear();
                                      _filtrar('');
                                    })
                                : null,
                          ),
                        ),
                      ),
                      Expanded(
                        child: (_ativos.isEmpty && _outros.isEmpty)
                            ? Center(
                                child: Text('Nenhum contato.',
                                    style: GoogleFonts.inter(
                                        color: AppTheme.corTextoSecundario)))
                            : ListView(children: [
                                if (_ativos.isNotEmpty) ...[
                                  _sectionHeader(
                                      '● Agendamento ativo (${_ativos.length})',
                                      AppTheme.sucesso),
                                  ..._ativos.map(
                                      (c) => _contactTile(c, cor, ativo: true)),
                                ],
                                if (_outros.isNotEmpty) ...[
                                  _sectionHeader('Outros contatos',
                                      AppTheme.corTextoSecundario),
                                  ..._outros.map((c) =>
                                      _contactTile(c, cor, ativo: false)),
                                ],
                              ]),
                      ),
                    ]),
    );
  }

  Widget _buildWebContacts(Color cor) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 18),
          child: TextField(
            controller: _buscaCtrl,
            onChanged: _filtrar,
            decoration: const InputDecoration(
              hintText: 'Buscar cliente por nome, telefone ou e-mail',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
        ),
        Expanded(
          child: _clientesWebFiltrados.isEmpty
              ? const PremiumSurface(
                  child: PremiumEmptyState(
                    icon: Icons.people_outline_rounded,
                    title: 'Nenhum cliente encontrado',
                    subtitle:
                        'Clientes atendidos ou agendados aparecerão aqui.',
                  ),
                )
              : ListView.separated(
                  itemCount: _clientesWebFiltrados.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, index) =>
                      _webContactCard(_clientesWebFiltrados[index], cor),
                ),
        ),
      ]);

  Widget _webContactCard(Map<String, dynamic> cliente, Color cor) {
    final nome = (cliente['nome'] ?? 'Cliente').toString();
    final telefone = (cliente['telefone'] ?? '').toString();
    final proximo =
        DateTime.tryParse(cliente['proximo_agendamento']?.toString() ?? '');
    final ultima =
        DateTime.tryParse(cliente['ultima_visita']?.toString() ?? '');
    String formatar(DateTime data) =>
        '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
    return PremiumSurface(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      color: PremiumColors.card,
      child: LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final details =
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(nome,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                  color: PremiumColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(telefone.isEmpty ? 'Telefone não cadastrado' : telefone,
              style: GoogleFonts.inter(
                  color: PremiumColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 5),
          Text(
              proximo != null
                  ? 'Próximo agendamento: ${formatar(proximo)}'
                  : ultima != null
                      ? 'Última visita: ${formatar(ultima)}'
                      : '${cliente['total_atendimentos'] ?? 0} agendamentos',
              style: GoogleFonts.inter(
                  color: proximo != null
                      ? PremiumColors.success
                      : PremiumColors.textMuted,
                  fontSize: 11)),
        ]);
        final action = OutlinedButton.icon(
          onPressed:
              telefone.isEmpty ? null : () => _abrirWhatsAppNumero(telefone),
          icon: const Icon(Icons.chat_outlined, size: 17),
          label: const Text('WhatsApp'),
          style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF55C77A),
              minimumSize: const Size(126, 44)),
        );
        return compact
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  _contactAvatar(nome, cor, proximo != null),
                  const SizedBox(width: 12),
                  Expanded(child: details),
                ]),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: action),
              ])
            : Row(children: [
                _contactAvatar(nome, cor, proximo != null),
                const SizedBox(width: 14),
                Expanded(child: details),
                const SizedBox(width: 16),
                action,
              ]);
      }),
    );
  }

  Widget _contactAvatar(String nome, Color cor, bool ativo) => Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            backgroundColor: cor.withValues(alpha: .16),
            child: Text(nome.isEmpty ? '?' : nome[0].toUpperCase(),
                style:
                    GoogleFonts.inter(color: cor, fontWeight: FontWeight.w700)),
          ),
          if (ativo)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                    color: PremiumColors.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: PremiumColors.card, width: 2)),
              ),
            ),
        ],
      );

  Widget _sectionHeader(String label, Color cor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(label,
          style: GoogleFonts.inter(
              color: AppTheme.corTextoSecundario,
              fontSize: 12,
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _contactTile(Contact c, Color cor, {required bool ativo}) {
    final nome = c.displayName;
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Stack(clipBehavior: Clip.none, children: [
          CircleAvatar(
            backgroundColor:
                ativo ? cor.withValues(alpha: 0.2) : AppTheme.surfaceElev,
            child: Text(
              nome.isNotEmpty ? nome[0].toUpperCase() : '?',
              style: GoogleFonts.playfairDisplay(
                color: ativo ? cor : AppTheme.corTextoSecundario,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (ativo)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppTheme.sucesso,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.black, width: 2),
                ),
              ),
            ),
        ]),
        title: Text(nome,
            style: GoogleFonts.inter(
              color: AppTheme.corTexto,
              fontWeight: ativo ? FontWeight.w600 : FontWeight.w400,
            )),
        subtitle: c.phones.isNotEmpty
            ? Text(c.phones.first.number,
                style: GoogleFonts.inter(
                    color: AppTheme.corTextoSecundario, fontSize: 12))
            : null,
        trailing: IconButton(
          icon: const Icon(Icons.chat, color: Color(0xFF25D366)),
          onPressed: () => _abrirWhatsApp(c),
        ),
      ),
    );
  }
}
