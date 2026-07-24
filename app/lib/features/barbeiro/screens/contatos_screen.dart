// ==========================================
// TELA: Contatos — clientes com agendamento ativo no topo
// ==========================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/barbearia_theme_service.dart';

class ContatosScreen extends StatefulWidget {
  const ContatosScreen({super.key});
  @override
  State<ContatosScreen> createState() => _ContatosScreenState();
}

class _ContatosScreenState extends State<ContatosScreen> {
  List<Contact> _todos        = [];
  List<Contact> _ativos       = [];
  List<Contact> _outros       = [];
  Set<String>   _numAtivos    = {};
  bool          _carregando   = true;
  bool          _permissao    = false;
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
    await _buscarClientesAtivos();
    await _pedirPermissao();
  }

  // Remove tudo que não é dígito e prefixo +55
  String _limpar(String tel) {
    String d = tel.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('55') && d.length >= 12) d = d.substring(2);
    if (d.startsWith('0') && d.length > 10)   d = d.substring(1);
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
    final lista  = (result['data'] ?? result);
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
        setState(() { _todos = lista; _permissao = true; });
      }
    }
    if (mounted) setState(() => _carregando = false);
  }

  void _separar(List<Contact> lista) {
    final a = lista.where(_temAgendamento).toList();
    final o = lista.where((c) => !_temAgendamento(c)).toList();
    a.sort((x, y) => (x.displayName ?? '').compareTo(y.displayName ?? ''));
    o.sort((x, y) => (x.displayName ?? '').compareTo(y.displayName ?? ''));
    _ativos = a;
    _outros = o;
  }

  void _filtrar(String q) {
    final ql = q.toLowerCase();
    final filtrados = _todos.where(
        (c) => (c.displayName ?? '').toLowerCase().contains(ql)).toList();
    setState(() { _separar(filtrados); });
  }

  Future<void> _abrirWhatsApp(Contact c) async {
    if (c.phones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Contato sem telefone.')));
      return;
    }
    final d   = _limpar(c.phones.first.number);
    final msg = Uri.encodeComponent(
        'Olá! Você tem um agendamento conosco. Qualquer dúvida, estamos à disposição!');
    final url = Uri.parse('https://wa.me/55$d?text=$msg');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      await Clipboard.setData(ClipboardData(text: c.phones.first.number));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Número copiado!')));
    }
  }

  Widget _separador(String label, Color cor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(label,
          style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _itemContato(Contact c, Color cor, {required bool ativo}) {
    final nome = c.displayName ?? '';
    return ListTile(
      leading: Stack(clipBehavior: Clip.none, children: [
        CircleAvatar(
          backgroundColor: ativo ? cor.withOpacity(0.2) : AppTheme.corCard,
          child: Text(
            nome.isNotEmpty ? nome[0].toUpperCase() : '?',
            style: TextStyle(
              color: ativo ? cor : AppTheme.corTextoSecundario,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (ativo)
          Positioned(
            right: -2, bottom: -2,
            child: Container(
              width: 12, height: 12,
              decoration: BoxDecoration(
                color: AppTheme.corSucesso,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.corFundo, width: 2),
              ),
            ),
          ),
      ]),
      title: Text(nome,
          style: TextStyle(
            color: AppTheme.corTexto,
            fontWeight: ativo ? FontWeight.bold : FontWeight.normal,
          )),
      subtitle: c.phones.isNotEmpty
          ? Text(c.phones.first.number,
              style: TextStyle(
                  color: AppTheme.corTextoSecundario, fontSize: 12))
          : null,
      trailing: IconButton(
        icon: Icon(Icons.chat, color: Color(0xFF25D366)),
        onPressed: () => _abrirWhatsApp(c),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<BarbeariaThemeService>();
    final cor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text('Contatos')),
      body: _carregando
          ? Center(child: CircularProgressIndicator(color: cor))
          : !_permissao
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.contacts_outlined,
                          color: AppTheme.corTextoSecundario, size: 64),
                      SizedBox(height: 16),
                      Text('Permissão necessária',
                          style: TextStyle(
                              color: AppTheme.corTexto,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),
                      ElevatedButton(
                          onPressed: _iniciar,
                          child: Text('Permitir acesso')),
                    ],
                  ),
                )
              : Column(children: [
                  // Barra de busca
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _buscaCtrl,
                      onChanged: _filtrar,
                      style: TextStyle(color: AppTheme.corTexto),
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

                  // Lista com seções
                  Expanded(
                    child: (_ativos.isEmpty && _outros.isEmpty)
                        ? Center(
                            child: Text('Nenhum contato.',
                                style: TextStyle(
                                    color: AppTheme.corTextoSecundario)))
                        : ListView(children: [
                            if (_ativos.isNotEmpty) ...[
                              _separador(
                                  '● Agendamento ativo (${_ativos.length})',
                                  AppTheme.corSucesso),
                              ..._ativos.map((c) =>
                                  _itemContato(c, cor, ativo: true)),
                            ],
                            if (_outros.isNotEmpty) ...[
                              _separador('Outros contatos',
                                  AppTheme.corTextoSecundario),
                              ..._outros.map((c) =>
                                  _itemContato(c, cor, ativo: false)),
                            ],
                          ]),
                  ),
                ]),
    );
  }
}