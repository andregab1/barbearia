import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../shared/widgets/premium_ui.dart';

class FiscalScreen extends StatefulWidget {
  const FiscalScreen({super.key});
  @override
  State<FiscalScreen> createState() => _FiscalScreenState();
}

class _FiscalScreenState extends State<FiscalScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _settings;
  List<Map<String, dynamic>> _documents = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final results = await Future.wait([ApiService.get('/fiscal/settings'), ApiService.get('/fiscal/documents')]);
    if (!mounted) return;
    setState(() {
      _error = results.firstWhere((item) => item.containsKey('erro'), orElse: () => {})['erro'];
      _settings = results[0]['data'] is Map ? Map<String, dynamic>.from(results[0]['data']) : null;
      _documents = results[1]['data'] is List
          ? (results[1]['data'] as List).map((item) => Map<String, dynamic>.from(item)).toList() : [];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) => PremiumPage(
    title: 'Fiscal', subtitle: 'Documentos fiscais vinculados aos atendimentos e pagamentos.',
    actions: [IconButton(onPressed: _loading ? null : _load, tooltip: 'Atualizar', icon: const Icon(Icons.refresh_rounded))],
    child: _loading
      ? const PremiumLoadingState(label: 'Carregando módulo fiscal')
      : _error != null
        ? PremiumEmptyState(icon: Icons.cloud_off_outlined, title: 'Falha ao carregar', subtitle: _error!)
        : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            PremiumSurface(child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.verified_user_outlined),
              title: Text(_settings?['ativo'] == 1 ? 'Emissão configurada' : 'Emissão não configurada'),
              subtitle: Text(_settings?['provedor'] == null
                  ? 'Configure provedor e dados municipais antes de emitir NFS-e.'
                  : 'Provedor: ${_settings!['provedor']} · Ambiente: ${_settings!['ambiente']}'),
            )),
            const SizedBox(height: 16),
            Expanded(child: PremiumSurface(child: _documents.isEmpty
              ? const PremiumEmptyState(icon: Icons.receipt_long_outlined, title: 'Nenhum documento fiscal', subtitle: 'Documentos solicitados aparecerão aqui.')
              : ListView.separated(itemCount: _documents.length, separatorBuilder: (_, __) => const Divider(), itemBuilder: (_, index) {
                  final item = _documents[index];
                  return ListTile(title: Text('Atendimento #${item['appointment_id']}'), subtitle: Text('${item['client']} · ${item['status']}'), trailing: Text('R\$ ${item['total_amount']}'));
                }))),
          ]),
  );
}
