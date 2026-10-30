import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/api_service.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/agendamento_controller.dart';

class BarbeariaPublicaScreen extends StatefulWidget {
  final String slug;
  final String? servicoId;
  final String? profissionalId;

  const BarbeariaPublicaScreen({
    super.key,
    required this.slug,
    this.servicoId,
    this.profissionalId,
  });

  @override
  State<BarbeariaPublicaScreen> createState() => _BarbeariaPublicaScreenState();
}

class _BarbeariaPublicaScreenState extends State<BarbeariaPublicaScreen> {
  Map<String, dynamic>? _barbearia;
  List<Map<String, dynamic>> _servicos = [];
  List<Map<String, dynamic>> _profissionais = [];
  String? _servicoId;
  String? _profissionalId;
  String? _erro;
  bool _carregando = true;
  bool _abrindo = false;
  int _requisicao = 0;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void didUpdateWidget(covariant BarbeariaPublicaScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slug != widget.slug ||
        oldWidget.servicoId != widget.servicoId ||
        oldWidget.profissionalId != widget.profissionalId) {
      _carregar();
    }
  }

  List<Map<String, dynamic>> _lista(Map<String, dynamic> result) =>
      (result['data'] as List? ?? [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

  Future<void> _carregar() async {
    final requisicao = ++_requisicao;
    setState(() {
      _carregando = true;
      _erro = null;
    });
    final shop = await ApiService.get(
      '/barbearias/slug/${Uri.encodeComponent(widget.slug)}',
      auth: false,
    );
    if (!mounted || requisicao != _requisicao) return;
    if (shop.containsKey('erro')) {
      setState(() {
        _carregando = false;
        _erro = shop['erro'].toString();
      });
      return;
    }
    final catalogos = await Future.wait([
      ApiService.get('/servicos/${shop['id']}', auth: false),
      ApiService.get('/colaboradores/${shop['id']}', auth: false),
    ]);
    if (!mounted || requisicao != _requisicao) return;
    setState(() {
      _carregando = false;
      _barbearia = shop;
      _erro = (catalogos[0]['erro'] ?? catalogos[1]['erro'])?.toString();
      _servicos = _lista(catalogos[0]);
      _profissionais = _lista(catalogos[1]);
      _servicoId = _servicos.any(
        (item) => item['id'].toString() == widget.servicoId,
      )
          ? widget.servicoId
          : null;
      _profissionalId = _profissionais.any(
        (item) => item['id'].toString() == widget.profissionalId,
      )
          ? widget.profissionalId
          : null;
    });
  }

  Future<void> _agendar() async {
    if (_abrindo || _barbearia == null) return;
    final controller = context.read<AgendamentoController>();
    final auth = context.read<AuthController>();
    setState(() => _abrindo = true);
    try {
      await controller.selecionarBarbearia(_barbearia!);
      await controller.prepararIntencaoAgendamento(
        servico: _servicoId == null
            ? null
            : _servicos.firstWhere(
                (item) => item['id'].toString() == _servicoId,
              ),
        colaborador: _profissionalId == null
            ? null
            : _profissionais.firstWhere(
                (item) => item['id'].toString() == _profissionalId,
              ),
      );
      if (!mounted) return;
      final destino = !auth.estaLogado
          ? AppConstants.routeLogin
          : auth.role == AppConstants.roleAdmin
              ? AppConstants.routeHomeAdmin
              : auth.role == AppConstants.roleBarbeiro
                  ? AppConstants.routeHomeBarbeiro
                  : AppConstants.routeHomeCliente;
      context.go(destino);
    } finally {
      if (mounted) setState(() => _abrindo = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text('${_barbearia?['nome'] ?? 'Barbearia'}'),
          leading: IconButton(
            tooltip: 'Encontrar barbearias',
            onPressed: () => context.go('/barbearias'),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: _carregando
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
                : Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          for (final campo in [
                            'descricao',
                            'endereco',
                            'telefone',
                            'email',
                          ])
                            if (_barbearia?[campo] != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text('${_barbearia![campo]}'),
                              ),
                          Text('Serviços',
                              style: Theme.of(context).textTheme.titleLarge),
                          if (_servicos.isEmpty)
                            const Text('Nenhum serviço disponível.'),
                          for (final servico in _servicos)
                            ListTile(
                              title: Text('${servico['nome']}'),
                              subtitle: Text(
                                '${servico['duracao_min']} min · R\$ ${servico['preco']}',
                              ),
                              selected: _servicoId == servico['id'].toString(),
                              trailing: _servicoId == servico['id'].toString()
                                  ? const Icon(Icons.check_circle)
                                  : null,
                              onTap: () => setState(
                                () => _servicoId = servico['id'].toString(),
                              ),
                            ),
                          Text('Profissionais',
                              style: Theme.of(context).textTheme.titleLarge),
                          if (_profissionais.isEmpty)
                            const Text('Nenhum profissional disponível.'),
                          for (final profissional in _profissionais)
                            ListTile(
                              title: Text('${profissional['nome']}'),
                              selected: _profissionalId ==
                                  profissional['id'].toString(),
                              trailing: _profissionalId ==
                                      profissional['id'].toString()
                                  ? const Icon(Icons.check_circle)
                                  : null,
                              onTap: () => setState(() => _profissionalId =
                                  profissional['id'].toString()),
                            ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _abrindo ||
                                    _servicos.isEmpty ||
                                    _profissionais.isEmpty
                                ? null
                                : _agendar,
                            child: Text(_abrindo ? 'Aguarde...' : 'Agendar'),
                          ),
                        ],
                      ),
                    ),
                  ),
      );
}
