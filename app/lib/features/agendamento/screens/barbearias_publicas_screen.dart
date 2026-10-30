import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/api_service.dart';
import 'agendar_screen.dart' show publicBarbeariaSlug;

class BarbeariasPublicasScreen extends StatefulWidget {
  const BarbeariasPublicasScreen({super.key});

  @override
  State<BarbeariasPublicasScreen> createState() =>
      _BarbeariasPublicasScreenState();
}

class _BarbeariasPublicasScreenState extends State<BarbeariasPublicasScreen> {
  final _busca = TextEditingController();
  List<Map<String, dynamic>> _barbearias = [];
  bool _carregando = true;
  String? _erro;
  int _requisicao = 0;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    final requisicao = ++_requisicao;
    final busca = _busca.text.trim();
    setState(() {
      _carregando = true;
      _erro = null;
    });
    final query =
        busca.isEmpty ? '' : '?busca=${Uri.encodeQueryComponent(busca)}';
    final resultado = await ApiService.get('/barbearias$query', auth: false);
    if (!mounted || requisicao != _requisicao) return;
    setState(() {
      _carregando = false;
      _erro = resultado['erro']?.toString();
      _barbearias = (resultado['data'] as List? ?? [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Encontrar barbearias')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _busca,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _carregar(),
                    decoration: InputDecoration(
                      labelText: 'Buscar por nome',
                      suffixIcon: IconButton(
                        tooltip: 'Buscar',
                        onPressed: _carregar,
                        icon: const Icon(Icons.search),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _carregando
                      ? const Center(child: CircularProgressIndicator())
                      : _erro != null
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(_erro!),
                                  TextButton(
                                    onPressed: _carregar,
                                    child: const Text('Tentar novamente'),
                                  ),
                                ],
                              ),
                            )
                          : _barbearias.isEmpty
                              ? const Center(
                                  child: Text('Nenhuma barbearia encontrada.'),
                                )
                              : ListView.builder(
                                  itemCount: _barbearias.length,
                                  itemBuilder: (context, index) {
                                    final item = _barbearias[index];
                                    final slug = publicBarbeariaSlug(item);
                                    return ListTile(
                                      leading: const Icon(Icons.content_cut),
                                      title: Text('${item['nome'] ?? ''}'),
                                      subtitle: Text(
                                        '${item['total_servicos'] ?? 0} serviços · '
                                        '${item['total_profissionais'] ?? 0} profissionais',
                                      ),
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: slug == null
                                          ? null
                                          : () => context.go(
                                                '/barbearia/${Uri.encodeComponent(slug)}',
                                              ),
                                    );
                                  },
                                ),
                ),
              ],
            ),
          ),
        ),
      );
}
