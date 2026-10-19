import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'agendar_screen.dart';
import '../../../core/services/api_service.dart';
import '../../../shared/widgets/premium_ui.dart';
import '../controllers/agendamento_controller.dart';

class AssistenteAgendamentoScreen extends StatefulWidget {
  final Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)? request;
  const AssistenteAgendamentoScreen({super.key, this.request});

  @override
  State<AssistenteAgendamentoScreen> createState() =>
      _AssistenteAgendamentoScreenState();
}

class _AssistenteAgendamentoScreenState
    extends State<AssistenteAgendamentoScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_ChatMessage> _messages = [
    const _ChatMessage(
      role: 'assistant',
      content:
          'Olá! Eu cuido do seu horário. Me diga o serviço, dia, hora e profissional que você prefere.',
    ),
  ];
  bool _sending = false;
  bool _confirming = false;
  bool _requestInFlight = false;
  String? _error;
  Map<String, dynamic>? _proposal;
  String? _proposalToken;
  List<Map<String, dynamic>> _alternatives = [];
  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) =>
      widget.request?.call(path, body) ?? ApiService.post(path, body,
        timeout: Duration(seconds: path.endsWith('conversar') ? 35 : 15));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<AgendamentoController>();
      if (controller.barbearias.isEmpty) controller.carregarBarbearias();
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send([String? suggestedText]) async {
    final text = (suggestedText ?? _input.text).trim();
    final controller = context.read<AgendamentoController>();
    final shop = controller.barbeariaSelecionada;
    if (text.isEmpty || _sending || _confirming || _requestInFlight || shop == null) return;
    _requestInFlight = true;
    final history = _messages
        .map((item) => {'role': item.role, 'content': item.content})
        .toList();
    setState(() {
      _messages.add(_ChatMessage(role: 'user', content: text));
      _input.clear();
      _sending = true;
      _error = null;
      _proposal = null;
      _proposalToken = null;
      _alternatives = [];
    });
    _scrollToEnd();
    try {
      final result = await _post(
          '/assistente/conversar',
          {
            'message': text,
            'barbearia_id': shop['id'],
            'history': history,
          });
      if (!mounted) return;
      setState(() {
        _sending = false;
        if (result.containsKey('erro')) {
          _error = result['erro'].toString();
          if ([
            'PROPOSAL_CHANGED',
            'APPOINTMENT_CONFLICT',
            'SCHEDULE_UNAVAILABLE',
            'INVALID_PROPOSAL'
          ].contains(result['code'])) {
            _proposal = null;
            _proposalToken = null;
          }
          return;
        }
        final reply = result['message']?.toString().trim();
        if (reply != null && reply.isNotEmpty) {
          _messages.add(_ChatMessage(role: 'assistant', content: reply));
        }
        if (result['proposal'] is Map && result['proposal_token'] is String) {
          _proposal = Map<String, dynamic>.from(result['proposal']);
          _proposalToken = result['proposal_token'] as String;
        }
        if (result['alternatives'] is List) {
          _alternatives = (result['alternatives'] as List)
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        }
      });
      _scrollToEnd();
    } finally {
      _requestInFlight = false;
    }
  }

  Future<void> _confirm() async {
    if (_proposalToken == null || _confirming) return;
    setState(() {
      _confirming = true;
      _error = null;
    });
    final result = await _post(
        '/assistente/confirmar', {'proposal_token': _proposalToken});
    if (!mounted) return;
    setState(() {
      _confirming = false;
      if (result['status'] == 'proposal' || result['status'] == 'alternatives') {
        _proposal = result['proposal'] is Map ? Map<String, dynamic>.from(result['proposal']) : null;
        _proposalToken = result['proposal_token'] as String?;
        _alternatives = (result['alternatives'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
        _messages.add(_ChatMessage(role: 'assistant', content: 'A disponibilidade ou os valores mudaram. ${result['message']}'));
        return;
      }
      if (result.containsKey('erro')) {
        _error = result['erro'].toString();
        if ([
          'PROPOSAL_CHANGED',
          'APPOINTMENT_CONFLICT',
          'SCHEDULE_UNAVAILABLE',
          'INVALID_PROPOSAL'
        ].contains(result['code'])) {
          _proposal = null;
          _proposalToken = null;
        }
        return;
      }
      _proposal = null;
      _proposalToken = null;
      _messages.add(const _ChatMessage(
        role: 'assistant',
        content:
            'Pronto — seu horário foi confirmado e já aparece na sua agenda.',
      ));
    });
    await context.read<AgendamentoController>().carregarMeusAgendamentos();
    _scrollToEnd();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AgendamentoController>();
    final shop = controller.barbeariaSelecionada;
    return PremiumPage(
      title: 'Assistente',
      subtitle: shop == null
          ? 'Selecione uma barbearia antes de conversar'
          : 'Agendando na ${shop['nome']} · em poucos segundos',
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: shop == null
          ? const PremiumEmptyState(
              icon: Icons.storefront_outlined,
              title: 'Escolha uma barbearia primeiro',
              subtitle:
                  'Volte ao início, selecione onde deseja ser atendido e depois converse comigo aqui.',
            )
          : ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                children: [
                  _SuggestionRow(onSelect: _send),
                  const SizedBox(height: 14),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: PremiumColors.surface,
                        border: Border.all(color: PremiumColors.border),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          _AssistantHeader(shopName: shop['nome'].toString()),
                          const Divider(height: 1),
                          Expanded(
                            child: ListView(
                              controller: _scroll,
                              padding:
                                  const EdgeInsets.fromLTRB(16, 20, 16, 12),
                              children: [
                                for (final message in _messages)
                                  _MessageBubble(message: message),
                                if (_sending) const _TypingBubble(),
                                if (_proposal != null)
                                  _ProposalCard(
                                    proposal: _proposal!,
                                    confirming: _confirming,
                                    onConfirm: _confirm,
                                    onEdit: () {
                                      setState(() {
                                        _proposal = null;
                                        _proposalToken = null;
                                      });
                                      _input.text = 'Quero alterar ';
                                    },
                                  ),
                                if (_alternatives.isNotEmpty)
                                  _AlternativeTimes(
                                    alternatives: _alternatives,
                                    onTap: (item) => _send(
                                      'Quero o horário ${item['time']} no dia ${item['date']}.',
                                    ),
                                  ),
                                if (_error != null) ...[
                                  _InlineError(message: _error!),
                                  TextButton(
                                      onPressed: _sending || _confirming
                                          ? null
                                          : () {
                                              if (_proposalToken != null) {
                                                _confirm();
                                                return;
                                              }
                                              final last = _messages
                                                  .where(
                                                      (m) => m.role == 'user')
                                                  .lastOrNull;
                                              if (last != null) {
                                                _send(last.content);
                                              }
                                            },
                                      child: const Text('Tentar novamente')),
                                  TextButton(
                                      onPressed: () => Navigator.of(context)
                                          .push(MaterialPageRoute(
                                              builder: (_) =>
                                                  const AgendarScreen())),
                                      child: const Text(
                                          'Usar agendamento tradicional')),
                                ],
                              ],
                            ),
                          ),
                          _Composer(
                            controller: _input,
                            enabled: !_sending && !_confirming,
                            onSend: _send,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ChatMessage {
  final String role;
  final String content;
  const _ChatMessage({required this.role, required this.content});
}

class _AssistantHeader extends StatelessWidget {
  final String shopName;
  const _AssistantHeader({required this.shopName});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: PremiumColors.gold.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: PremiumColors.gold, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Agenda inteligente',
                    style: GoogleFonts.inter(
                        color: PremiumColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                Text(shopName,
                    style: GoogleFonts.inter(
                        color: PremiumColors.textMuted, fontSize: 12)),
              ])),
          const Icon(Icons.lock_outline_rounded,
              size: 16, color: PremiumColors.textMuted),
        ]),
      );
}

class _SuggestionRow extends StatelessWidget {
  final ValueChanged<String> onSelect;
  const _SuggestionRow({required this.onSelect});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 38,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          _Suggestion(
              label: 'Corte amanhã às 15h',
              onTap: () => onSelect('Quero agendar um corte amanhã às 15h.')),
          _Suggestion(
              label: 'Corte + barba',
              onTap: () => onSelect('Quero agendar corte e barba.')),
          _Suggestion(
              label: 'Ver horários',
              onTap: () => onSelect('Quais horários vocês têm disponíveis?')),
        ]),
      );
}

class _Suggestion extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _Suggestion({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 38),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              foregroundColor: PremiumColors.textSecondary,
              side: const BorderSide(color: PremiumColors.border),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              textStyle:
                  GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            child: Text(label)),
      );
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;
  const _MessageBubble({required this.message});
  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 540),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isUser ? PremiumColors.gold : PremiumColors.surfaceSecondary,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isUser ? 14 : 3),
            bottomRight: Radius.circular(isUser ? 3 : 14),
          ),
        ),
        child: Text(message.content,
            style: GoogleFonts.inter(
              color:
                  isUser ? PremiumColors.background : PremiumColors.textPrimary,
              fontSize: 13,
              height: 1.45,
              fontWeight: isUser ? FontWeight.w500 : FontWeight.w400,
            )),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();
  @override
  Widget build(BuildContext context) => const Align(
        alignment: Alignment.centerLeft,
        child: Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: SizedBox(
                width: 42, child: LinearProgressIndicator(minHeight: 3))),
      );
}

class _ProposalCard extends StatelessWidget {
  final VoidCallback onEdit;
  final Map<String, dynamic> proposal;
  final bool confirming;
  final VoidCallback onConfirm;
  const _ProposalCard(
      {required this.proposal,
      required this.confirming,
      required this.onConfirm,
      required this.onEdit});
  @override
  Widget build(BuildContext context) {
    final services = (proposal['services'] as List? ?? [])
        .map((item) => item['nome'])
        .join(' + ');
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: PremiumColors.gold.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PremiumColors.gold.withValues(alpha: .32))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.event_available_rounded,
              color: PremiumColors.gold, size: 19),
          const SizedBox(width: 8),
          Text('Confira seu horário',
              style: GoogleFonts.inter(
                  color: PremiumColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14))
        ]),
        const SizedBox(height: 14),
        _Detail(icon: Icons.content_cut_rounded, text: services),
        _Detail(
            icon: Icons.person_outline_rounded,
            text: proposal['professional'].toString()),
        _Detail(
            icon: Icons.calendar_today_outlined,
            text:
                '${DateFormat('dd/MM/yyyy').format(DateTime.parse(proposal['date']))} às ${proposal['time']} · ${proposal['duration_min']} min'),
        _Detail(
            icon: Icons.payments_outlined,
            text: premiumCurrency(proposal['total'])),
        const SizedBox(height: 12),
        SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: confirming ? null : onConfirm,
              icon: confirming
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: PremiumColors.background))
                  : const Icon(Icons.check_rounded, size: 18),
              label:
                  Text(confirming ? 'Confirmando...' : 'Confirmar agendamento'),
            )),
        TextButton(
            onPressed: confirming ? null : onEdit,
            child: const Text('Editar pedido')),
      ]),
    );
  }
}

class _Detail extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Detail({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, color: PremiumColors.textMuted, size: 16),
        const SizedBox(width: 9),
        Expanded(
            child: Text(text,
                style: GoogleFonts.inter(
                    color: PremiumColors.textSecondary, fontSize: 12.5)))
      ]));
}

class _AlternativeTimes extends StatelessWidget {
  final List<Map<String, dynamic>> alternatives;
  final ValueChanged<Map<String, dynamic>> onTap;
  const _AlternativeTimes({required this.alternatives, required this.onTap});
  @override
  Widget build(BuildContext context) => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: alternatives.map((item) {
            final date = DateTime.parse(item['date'].toString());
            final formattedDate = DateFormat('dd/MM/yyyy').format(date);
            return OutlinedButton(
              onPressed: () => onTap(item),
              child: Text('$formattedDate · ${item['time']}'),
            );
          })
          .toList());
}

class _InlineError extends StatelessWidget {
  final String message;
  const _InlineError({required this.message});
  @override
  Widget build(BuildContext context) => Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: PremiumColors.error.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(10)),
      child: Text(message,
          style: GoogleFonts.inter(color: PremiumColors.error, fontSize: 12)));
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onSend;
  const _Composer(
      {required this.controller, required this.enabled, required this.onSend});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: PremiumColors.border))),
        child: Row(children: [
          Expanded(
              child: TextField(
                  controller: controller,
                  enabled: enabled,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.send,
                  onSubmitted: onSend,
                  decoration: const InputDecoration(
                      hintText: 'Ex.: corte + barba na terça às 15h com André',
                      border: InputBorder.none,
                      filled: false,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 10)))),
          const SizedBox(width: 8),
          IconButton(
              onPressed: enabled ? () => onSend(controller.text) : null,
              icon: const Icon(Icons.arrow_upward_rounded),
              style: IconButton.styleFrom(
                  backgroundColor: PremiumColors.gold,
                  foregroundColor: PremiumColors.background)),
        ]),
      );
}
