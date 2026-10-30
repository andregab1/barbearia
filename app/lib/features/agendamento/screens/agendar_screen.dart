import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/services/barbearia_theme_service.dart';
import '../../../shared/widgets/premium_ui.dart';
import '../../../shared/widgets/logo_widget.dart';
import '../controllers/agendamento_controller.dart';

class _BookingColors {
  static Color get background => AppTheme.black;
  static Color get surface => AppTheme.surface;
  static Color get surfaceSecondary => AppTheme.surfaceElev;
  static Color get card => AppTheme.corCard;
  static Color get cardHover =>
      AppTheme.modoClaro ? AppTheme.surfaceLight : const Color(0xFF29211E);
  static Color get gold => AppTheme.gold;
  static Color get textPrimary => AppTheme.corTexto;
  static Color get textSecondary => AppTheme.corTextoSecundario;
  static Color get textMuted => AppTheme.modoClaro
      ? AppTheme.mutedLight
      : const Color(0xFF77716D);
  static Color get border => AppTheme.corBorda;
  static Color get borderGold => AppTheme.gold.withValues(alpha: .45);
}

String? publicBarbeariaSlug(Map<String, dynamic> barbearia) {
  final slug = barbearia['slug']?.toString().trim();
  if (slug != null && slug.isNotEmpty) return slug;

  final id = int.tryParse(barbearia['id']?.toString() ?? '');
  return id != null && id > 0 ? 'barbearia-$id' : null;
}

class AgendarScreen extends StatefulWidget {
  final Map<String, dynamic>? servico;
  final Map<String, dynamic>? colaborador;

  const AgendarScreen({super.key, this.servico, this.colaborador});

  @override
  State<AgendarScreen> createState() => _AgendarScreenState();
}

class _AgendarScreenState extends State<AgendarScreen> {
  List<Map<String, dynamic>> _servicosSel = [];
  Map<String, dynamic>? _colaboradorSel;
  DateTime? _dataSel;
  String? _horaSel;
  int _etapaAtual = 1;
  int _semanaOffset = 0;

  int get _duracaoTotal => _servicosSel.fold(
        0,
        (total, servico) => total + (servico['duracao_min'] as int),
      );

  double get _valorTotal => _servicosSel.fold(
        0,
        (total, servico) =>
            total + (double.tryParse(servico['preco'].toString()) ?? 0),
      );

  bool get _podeConfirmar =>
      _servicosSel.isNotEmpty &&
      _colaboradorSel != null &&
      _dataSel != null &&
      _horaSel != null;

  @override
  void initState() {
    super.initState();
    _aplicarIntencao(
      servico: widget.servico,
      colaborador: widget.colaborador,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ctrl = context.read<AgendamentoController>();
      await ctrl.carregarBarbearias();
      if (!mounted || widget.servico != null || widget.colaborador != null) {
        return;
      }
      final pendente = await ctrl.consumirIntencaoAgendamento();
      if (pendente == null) return;
      final servico = pendente['servico'];
      final colaborador = pendente['colaborador'];
      setState(() {
        _aplicarIntencao(
          servico: servico is Map ? Map<String, dynamic>.from(servico) : null,
          colaborador: colaborador is Map
              ? Map<String, dynamic>.from(colaborador)
              : null,
        );
      });
    });
  }

  void _aplicarIntencao({
    Map<String, dynamic>? servico,
    Map<String, dynamic>? colaborador,
  }) {
    if (servico != null) {
      _servicosSel = [servico];
      _etapaAtual = 1;
    }
    if (colaborador != null) {
      _colaboradorSel = colaborador;
      _etapaAtual = _servicosSel.isEmpty ? 1 : 3;
    }
  }

  String _formatarPreco(dynamic preco) {
    final valor = double.tryParse(preco.toString()) ?? 0;
    return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(valor);
  }

  String _iniciais(String nome) {
    final partes = nome
        .trim()
        .split(RegExp(r'\s+'))
        .where((parte) => parte.isNotEmpty)
        .toList();
    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes.first[0].toUpperCase();
    return '${partes.first[0]}${partes.last[0]}'.toUpperCase();
  }

  void _irParaEtapa(int etapa) {
    if (etapa == 2 && _servicosSel.isEmpty) return;
    if (etapa == 3 && (_servicosSel.isEmpty || _colaboradorSel == null)) return;
    setState(() => _etapaAtual = etapa);
  }

  void _toggleServico(Map<String, dynamic> servico) {
    setState(() {
      final index = _servicosSel.indexWhere((s) => s['id'] == servico['id']);
      if (index >= 0) {
        _servicosSel.removeAt(index);
      } else {
        _servicosSel.add(servico);
      }
      _dataSel = null;
      _horaSel = null;
      if (_servicosSel.isEmpty) _etapaAtual = 1;
    });
  }

  void _selecionarColaborador(Map<String, dynamic> colaborador) {
    setState(() {
      _colaboradorSel = colaborador;
      _dataSel = null;
      _horaSel = null;
      _etapaAtual = 3;
    });
  }

  Future<void> _selecionarData(DateTime data) async {
    if (_colaboradorSel == null || _servicosSel.isEmpty) return;
    setState(() {
      _dataSel = DateTime(data.year, data.month, data.day);
      _horaSel = null;
    });
    await context.read<AgendamentoController>().carregarHorarios(
          _colaboradorSel!['id'],
          DateFormat('yyyy-MM-dd').format(data),
          duracaoTotal: _duracaoTotal,
        );
  }

  Future<void> _confirmar() async {
    if (!_podeConfirmar) return;

    final nomesServicos = _servicosSel.length > 1
        ? _servicosSel.map((s) => s['nome']).join(' + ')
        : null;
    final dataHora =
        '${DateFormat('yyyy-MM-dd').format(_dataSel!)} $_horaSel:00';
    final ok = await context.read<AgendamentoController>().agendar(
          colaboradorId: _colaboradorSel!['id'],
          servicoId: _servicosSel.first['id'],
          servicosIds: _servicosSel.map<int>((s) => s['id'] as int).toList(),
          dataHora: dataHora,
          observacao: nomesServicos,
        );

    if (!mounted) return;
    if (ok) {
      if (Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Agendamento confirmado!'),
        backgroundColor: AppTheme.sucesso,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<BarbeariaThemeService>();
    final ctrl = context.watch<AgendamentoController>();

    if (ctrl.barbeariaSelecionada == null) {
      return ColoredBox(
        color: _BookingColors.background,
        child: BarbeariasPicker(
          controller: ctrl,
          onSelected: ctrl.selecionarBarbearia,
        ),
      );
    }

    return ColoredBox(
      color: _BookingColors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 768;
          final summaryWidth = constraints.maxWidth >= 1200 ? 360.0 : 320.0;

          Future<void> changeBarbershop() async {
            await ctrl.trocarBarbearia();
            if (!mounted) return;
            setState(() {
              _servicosSel = [];
              _colaboradorSel = null;
              _dataSel = null;
              _horaSel = null;
              _etapaAtual = 1;
            });
          }

          final form = _BookingForm(
            currentStep: _etapaAtual,
            controller: ctrl,
            selectedServices: _servicosSel,
            selectedProfessional: _colaboradorSel,
            selectedDate: _dataSel,
            selectedTime: _horaSel,
            weekOffset: _semanaOffset,
            formatPrice: _formatarPreco,
            initials: _iniciais,
            onStepPressed: _irParaEtapa,
            onServicePressed: _toggleServico,
            onProfessionalPressed: _selecionarColaborador,
            onDatePressed: _selecionarData,
            onPreviousWeek: _semanaOffset == 0
                ? null
                : () => setState(() => _semanaOffset -= 7),
            onNextWeek: () => setState(() => _semanaOffset += 7),
            onTimePressed: (time) => setState(() => _horaSel = time),
          );

          final summary = _BookingSummary(
            services: _servicosSel,
            professional: _colaboradorSel,
            date: _dataSel,
            time: _horaSel,
            totalDuration: _duracaoTotal,
            totalPrice: _formatarPreco(_valorTotal),
            saving: ctrl.salvando,
            enabled: _podeConfirmar,
            formatPrice: _formatarPreco,
            initials: _iniciais,
            onConfirm: _confirmar,
            onAddService: () => _irParaEtapa(1),
            onRemoveService: _toggleServico,
          );

          final panels = desktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: form),
                    const SizedBox(width: 24),
                    SizedBox(width: summaryWidth, child: summary),
                  ],
                )
              : Column(
                  children: [
                    form,
                    const SizedBox(height: 16),
                    summary,
                  ],
                );

          return SingleChildScrollView(
            child: PremiumPageFrame(
              topPadding: 20,
              bottomPadding: 32,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SelectedBarbershop(
                    barbershop: ctrl.barbeariaSelecionada!,
                    onChange: changeBarbershop,
                  ),
                  const SizedBox(height: 14),
                  panels,
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class BarbeariasPicker extends StatefulWidget {
  final AgendamentoController controller;
  final ValueChanged<Map<String, dynamic>> onSelected;
  const BarbeariasPicker({required this.controller, required this.onSelected});

  @override
  State<BarbeariasPicker> createState() => _BarbershopPickerState();
}

class _BarbershopPickerState extends State<BarbeariasPicker> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _abrirPerfil(Map<String, dynamic> barbershop) async {
    final slug = publicBarbeariaSlug(barbershop);
    if (slug != null && slug.isNotEmpty) {
      await context.push('/barbearia/${Uri.encodeComponent(slug)}');
      return;
    }

    final name = (barbershop['nome'] ?? 'Barbearia').toString();
    final phone = barbershop['telefone']?.toString();
    final email = barbershop['email']?.toString();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
          decoration: BoxDecoration(
            color: _BookingColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _BookingColors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LogoWidget(
                    logoUrl: barbershop['logo_url']?.toString(),
                    size: 72,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: GoogleFonts.inter(
                                color: _BookingColors.textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text('Perfil da barbearia',
                            style: GoogleFonts.inter(
                                color: _BookingColors.gold,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                '${barbershop['total_servicos'] ?? 0} servicos  -  ${barbershop['total_profissionais'] ?? 0} profissionais',
                style: GoogleFonts.inter(
                    color: _BookingColors.textSecondary, fontSize: 13),
              ),
              if (phone != null && phone.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(phone,
                    style: GoogleFonts.inter(
                        color: _BookingColors.textMuted, fontSize: 12)),
              ],
              if (email != null && email.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(email,
                    style: GoogleFonts.inter(
                        color: _BookingColors.textMuted, fontSize: 12)),
              ],
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    widget.onSelected(barbershop);
                  },
                  icon: const Icon(Icons.calendar_month_rounded),
                  label: const Text('Agendar nesta barbearia'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _BookingColors.gold,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) => SingleChildScrollView(
          child: PremiumPageFrame(
            topPadding: 28,
            bottomPadding: 48,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const PremiumPageHeader(
                title: 'Escolha onde deseja agendar',
                subtitle:
                    'Selecione uma barbearia para ver serviços, profissionais e horários disponíveis.',
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (value) =>
                    widget.controller.carregarBarbearias(busca: value),
                decoration: InputDecoration(
                  hintText: 'Buscar pelo nome da barbearia',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    tooltip: 'Buscar',
                    onPressed: () => widget.controller
                        .carregarBarbearias(busca: _searchController.text),
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 26),
              if (widget.controller.carregandoBarbearias)
                const SizedBox(
                    height: 220,
                    child: Center(child: CircularProgressIndicator()))
              else if (widget.controller.barbearias.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                      color: _BookingColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _BookingColors.border)),
                  child: Column(children: [
                    Icon(Icons.storefront_outlined,
                        color: _BookingColors.textMuted, size: 34),
                    SizedBox(height: 10),
                    Text('Nenhuma barbearia encontrada.',
                        style: TextStyle(color: _BookingColors.textSecondary)),
                  ]),
                )
              else
                LayoutBuilder(builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 820
                      ? 3
                      : constraints.maxWidth >= 520
                          ? 2
                          : 1;
                  const gap = 14.0;
                  final cardWidth =
                      (constraints.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: widget.controller.barbearias
                        .map((barbershop) => SizedBox(
                              width: cardWidth,
                              child: _BarbershopCard(
                                  barbershop: barbershop,
                                  onTap: () => _abrirPerfil(barbershop)),
                            ))
                        .toList(),
                  );
                }),
            ]),
          ),
        ),
      );
}

class _BarbershopCard extends StatelessWidget {
  final Map<String, dynamic> barbershop;
  final VoidCallback onTap;
  const _BarbershopCard({required this.barbershop, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = (barbershop['nome'] ?? 'Barbearia').toString();
    return Material(
      color: _BookingColors.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 180),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _BookingColors.border)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            LogoWidget(
              logoUrl: barbershop['logo_url']?.toString(),
              size: 46,
            ),
            const SizedBox(height: 17),
            Text(name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    color: _BookingColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(
                '${barbershop['total_profissionais'] ?? 0} profissionais · ${barbershop['total_servicos'] ?? 0} serviços',
                style: GoogleFonts.inter(
                    color: _BookingColors.textMuted, fontSize: 11)),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Ver perfil',
                  style: GoogleFonts.inter(
                      color: _BookingColors.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              Icon(Icons.arrow_forward_rounded,
                  color: _BookingColors.gold, size: 18),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _SelectedBarbershop extends StatelessWidget {
  final Map<String, dynamic> barbershop;
  final VoidCallback onChange;
  const _SelectedBarbershop({required this.barbershop, required this.onChange});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        color: _BookingColors.surface,
        child: Row(children: [
          LogoWidget(logoUrl: barbershop['logo_url']?.toString(), size: 28),
          const SizedBox(width: 9),
          Expanded(
              child: Text(barbershop['nome'] ?? 'Barbearia selecionada',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      color: _BookingColors.textSecondary, fontSize: 12))),
          TextButton(onPressed: onChange, child: const Text('Trocar')),
        ]),
      );
}

class _BookingForm extends StatelessWidget {
  final int currentStep;
  final AgendamentoController controller;
  final List<Map<String, dynamic>> selectedServices;
  final Map<String, dynamic>? selectedProfessional;
  final DateTime? selectedDate;
  final String? selectedTime;
  final int weekOffset;
  final String Function(dynamic) formatPrice;
  final String Function(String) initials;
  final ValueChanged<int> onStepPressed;
  final ValueChanged<Map<String, dynamic>> onServicePressed;
  final ValueChanged<Map<String, dynamic>> onProfessionalPressed;
  final ValueChanged<DateTime> onDatePressed;
  final VoidCallback? onPreviousWeek;
  final VoidCallback onNextWeek;
  final ValueChanged<String> onTimePressed;

  const _BookingForm({
    required this.currentStep,
    required this.controller,
    required this.selectedServices,
    required this.selectedProfessional,
    required this.selectedDate,
    required this.selectedTime,
    required this.weekOffset,
    required this.formatPrice,
    required this.initials,
    required this.onStepPressed,
    required this.onServicePressed,
    required this.onProfessionalPressed,
    required this.onDatePressed,
    required this.onPreviousWeek,
    required this.onNextWeek,
    required this.onTimePressed,
  });

  @override
  Widget build(BuildContext context) {
    final stepContent = AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(.025, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: switch (currentStep) {
        1 => _ServiceStep(
            key: const ValueKey('service'),
            controller: controller,
            selectedServices: selectedServices,
            formatPrice: formatPrice,
            onPressed: onServicePressed,
            onContinue: () => onStepPressed(2),
          ),
        2 => _ProfessionalStep(
            key: const ValueKey('professional'),
            controller: controller,
            selectedProfessional: selectedProfessional,
            initials: initials,
            onPressed: onProfessionalPressed,
          ),
        _ => _DateTimeStep(
            key: const ValueKey('datetime'),
            controller: controller,
            selectedDate: selectedDate,
            selectedTime: selectedTime,
            weekOffset: weekOffset,
            onDatePressed: onDatePressed,
            onPreviousWeek: onPreviousWeek,
            onNextWeek: onNextWeek,
            onTimePressed: onTimePressed,
          ),
      },
    );

    return Container(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 480 ? 16 : 24),
      decoration: BoxDecoration(
        color: _BookingColors.surface,
        border: Border.all(color: _BookingColors.border),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2E000000),
            blurRadius: 40,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CompactSteps(
            currentStep: currentStep,
            onStepPressed: onStepPressed,
          ),
          const SizedBox(height: 24),
          stepContent,
          if (currentStep > 1) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => onStepPressed(currentStep - 1),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Voltar'),
              style: TextButton.styleFrom(
                foregroundColor: _BookingColors.textSecondary,
                minimumSize: const Size(92, 44),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompactSteps extends StatelessWidget {
  final int currentStep;
  final ValueChanged<int> onStepPressed;
  const _CompactSteps({required this.currentStep, required this.onStepPressed});

  static const labels = ['Serviço', 'Profissional', 'Data e horário'];

  @override
  Widget build(BuildContext context) => Row(
        children: List.generate(labels.length, (index) {
          final step = index + 1;
          final active = step == currentStep;
          final complete = step < currentStep;
          return Expanded(
            child: InkWell(
              onTap: () => onStepPressed(step),
              borderRadius: BorderRadius.circular(10),
              child: Semantics(
                selected: active,
                label: 'Etapa $step de 3: ${labels[index]}',
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: active || complete
                              ? _BookingColors.gold
                              : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: active || complete
                                ? _BookingColors.gold
                                : _BookingColors.border,
                          ),
                        ),
                        child: complete
                            ? Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: _BookingColors.background,
                              )
                            : Text(
                                '$step',
                                style: GoogleFonts.inter(
                                  color: active
                                      ? _BookingColors.background
                                      : _BookingColors.textMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          labels[index],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: active
                                ? _BookingColors.textPrimary
                                : _BookingColors.textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      );
}

class _StepHeading extends StatelessWidget {
  final String number;
  final String title;
  final String subtitle;
  const _StepHeading({
    required this.number,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                number,
                style: GoogleFonts.inter(
                  color: _BookingColors.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: GoogleFonts.inter(
                  color: _BookingColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              color: _BookingColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      );
}

class _ServiceStep extends StatelessWidget {
  final AgendamentoController controller;
  final List<Map<String, dynamic>> selectedServices;
  final String Function(dynamic) formatPrice;
  final ValueChanged<Map<String, dynamic>> onPressed;
  final VoidCallback onContinue;

  const _ServiceStep({
    super.key,
    required this.controller,
    required this.selectedServices,
    required this.formatPrice,
    required this.onPressed,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeading(
            number: '01',
            title: 'Serviço',
            subtitle: 'Escolha o procedimento que deseja realizar.',
          ),
          const SizedBox(height: 20),
          if (controller.carregandoServicos)
            const _LoadingState(label: 'Carregando serviços...')
          else if (controller.servicos.isEmpty)
            const _MessageState(label: 'Nenhum serviço disponível.')
          else
            LayoutBuilder(builder: (context, constraints) {
              final columns = constraints.maxWidth >= 680
                  ? 3
                  : constraints.maxWidth >= 420
                      ? 2
                      : 1;
              const gap = 12.0;
              final width =
                  (constraints.maxWidth - (gap * (columns - 1))) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: controller.servicos.map((service) {
                  final selected = selectedServices
                      .any((selected) => selected['id'] == service['id']);
                  return SizedBox(
                    width: width,
                    child: _ServiceTile(
                      service: service,
                      selected: selected,
                      price: formatPrice(service['preco']),
                      onPressed: () => onPressed(service),
                    ),
                  );
                }).toList(),
              );
            }),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: selectedServices.isEmpty ? null : onContinue,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: Text(
                  selectedServices.length == 1
                      ? 'Continuar com 1 serviço'
                      : 'Continuar com ${selectedServices.length} serviços',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _BookingColors.gold,
                  foregroundColor: _BookingColors.background,
                  disabledBackgroundColor:
                      _BookingColors.gold.withValues(alpha: .22),
                  disabledForegroundColor: _BookingColors.textMuted,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
}

class _ServiceTile extends StatelessWidget {
  final Map<String, dynamic> service;
  final bool selected;
  final String price;
  final VoidCallback onPressed;
  const _ServiceTile({
    required this.service,
    required this.selected,
    required this.price,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final name = service['nome'].toString();
    final description = (service['descricao'] ?? '').toString().trim();
    return _SelectionCard(
      selected: selected,
      onPressed: onPressed,
      semanticLabel: 'Serviço $name, ${service['duracao_min']} minutos, $price',
      child: SizedBox(
        height: 164,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    Icons.content_cut_rounded,
                    color: _BookingColors.gold,
                    size: 19,
                  ),
                  if (selected)
                    Icon(
                      Icons.check_circle_rounded,
                      color: _BookingColors.gold,
                      size: 19,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 38,
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: _BookingColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(
                height: 30,
                child: description.isEmpty
                    ? null
                    : Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: _BookingColors.textMuted,
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${service['duracao_min']} min',
                      style: GoogleFonts.inter(
                        color: _BookingColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    price,
                    style: GoogleFonts.inter(
                      color: _BookingColors.gold,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfessionalStep extends StatelessWidget {
  final AgendamentoController controller;
  final Map<String, dynamic>? selectedProfessional;
  final String Function(String) initials;
  final ValueChanged<Map<String, dynamic>> onPressed;

  const _ProfessionalStep({
    super.key,
    required this.controller,
    required this.selectedProfessional,
    required this.initials,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeading(
            number: '02',
            title: 'Profissional',
            subtitle: 'Selecione quem cuidará do seu atendimento.',
          ),
          const SizedBox(height: 20),
          if (controller.carregandoColaboradores)
            const _LoadingState(label: 'Carregando profissionais...')
          else if (controller.colaboradores.isEmpty)
            const _MessageState(label: 'Nenhum profissional disponível.')
          else
            LayoutBuilder(builder: (context, constraints) {
              final columns = constraints.maxWidth >= 520 ? 2 : 1;
              const gap = 12.0;
              final width =
                  (constraints.maxWidth - (gap * (columns - 1))) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: controller.colaboradores.map((professional) {
                  final selected =
                      selectedProfessional?['id'] == professional['id'];
                  return SizedBox(
                    width: width,
                    child: _ProfessionalTile(
                      professional: professional,
                      selected: selected,
                      initials: initials(professional['nome'].toString()),
                      onPressed: () => onPressed(professional),
                    ),
                  );
                }).toList(),
              );
            }),
        ],
      );
}

class _ProfessionalTile extends StatelessWidget {
  final Map<String, dynamic> professional;
  final bool selected;
  final String initials;
  final VoidCallback onPressed;
  const _ProfessionalTile({
    required this.professional,
    required this.selected,
    required this.initials,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final name = professional['nome'].toString();
    return _SelectionCard(
      selected: selected,
      onPressed: onPressed,
      semanticLabel: 'Profissional $name',
      child: SizedBox(
        height: 84,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _InitialAvatar(initials: initials, size: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: _BookingColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Barbeiro',
                      style: GoogleFonts.inter(
                        color: _BookingColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle_rounded,
                  color: _BookingColors.gold,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateTimeStep extends StatelessWidget {
  final AgendamentoController controller;
  final DateTime? selectedDate;
  final String? selectedTime;
  final int weekOffset;
  final ValueChanged<DateTime> onDatePressed;
  final VoidCallback? onPreviousWeek;
  final VoidCallback onNextWeek;
  final ValueChanged<String> onTimePressed;

  const _DateTimeStep({
    super.key,
    required this.controller,
    required this.selectedDate,
    required this.selectedTime,
    required this.weekOffset,
    required this.onDatePressed,
    required this.onPreviousWeek,
    required this.onNextWeek,
    required this.onTimePressed,
  });

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _monthLabel(DateTime date) {
    const months = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];
    return '${months[date.month - 1]} de ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final firstDay = DateTime(today.year, today.month, today.day)
        .add(Duration(days: weekOffset));
    final days =
        List.generate(7, (index) => firstDay.add(Duration(days: index)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeading(
          number: '03',
          title: 'Data e horário',
          subtitle: 'Escolha o melhor dia e um horário disponível.',
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _monthLabel(firstDay),
              style: GoogleFonts.inter(
                color: _BookingColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Row(
              children: [
                _CalendarArrow(
                  icon: Icons.chevron_left_rounded,
                  onPressed: onPreviousWeek,
                  label: 'Semana anterior',
                ),
                const SizedBox(width: 8),
                _CalendarArrow(
                  icon: Icons.chevron_right_rounded,
                  onPressed: onNextWeek,
                  label: 'Próxima semana',
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, constraints) {
          const gap = 8.0;
          final width = (constraints.maxWidth - gap * 6) / 7;
          return Row(
            children: List.generate(days.length, (index) {
              final day = days[index];
              final selected =
                  selectedDate != null && _sameDay(day, selectedDate!);
              return Padding(
                padding: EdgeInsets.only(right: index == 6 ? 0 : gap),
                child: SizedBox(
                  width: width,
                  child: _DateTile(
                    date: day,
                    selected: selected,
                    onPressed: () => onDatePressed(day),
                  ),
                ),
              );
            }),
          );
        }),
        const SizedBox(height: 28),
        Row(
          children: [
            Text(
              '04',
              style: GoogleFonts.inter(
                color: _BookingColors.gold,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'HORÁRIO',
              style: GoogleFonts.inter(
                color: _BookingColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: .4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (selectedDate == null)
          const _MessageState(label: 'Selecione uma data para ver os horários.')
        else if (controller.carregandoHorarios)
          const _LoadingState(label: 'Carregando horários...')
        else if (controller.horariosDisp.isEmpty)
          const _MessageState(label: 'Nenhum horário disponível nesta data.')
        else
          LayoutBuilder(builder: (context, constraints) {
            final columns = constraints.maxWidth >= 520 ? 4 : 2;
            const gap = 10.0;
            final width =
                (constraints.maxWidth - (gap * (columns - 1))) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: controller.horariosDisp.map((item) {
                final time = item['hora'].toString();
                return SizedBox(
                  width: width,
                  child: _TimeTile(
                    time: time,
                    selected: selectedTime == time,
                    onPressed: () => onTimePressed(time),
                  ),
                );
              }).toList(),
            );
          }),
        if (controller.erro.isNotEmpty) ...[
          const SizedBox(height: 16),
          _ErrorState(message: controller.erro),
        ],
      ],
    );
  }
}

class _DateTile extends StatelessWidget {
  final DateTime date;
  final bool selected;
  final VoidCallback onPressed;
  const _DateTile({
    required this.date,
    required this.selected,
    required this.onPressed,
  });

  static const weekdays = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        label: DateFormat('dd/MM/yyyy').format(date),
        child: SizedBox(
          height: 68,
          child: Material(
            color: selected ? _BookingColors.gold : _BookingColors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: selected ? _BookingColors.gold : _BookingColors.border,
              ),
            ),
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(12),
              focusColor: _BookingColors.gold.withValues(alpha: .12),
              hoverColor: _BookingColors.gold.withValues(alpha: .08),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    weekdays[date.weekday - 1],
                    style: GoogleFonts.inter(
                      color: selected
                          ? _BookingColors.background
                          : _BookingColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${date.day}',
                    style: GoogleFonts.inter(
                      color: selected
                          ? _BookingColors.background
                          : _BookingColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _CalendarArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String label;
  const _CalendarArrow({
    required this.icon,
    required this.onPressed,
    required this.label,
  });

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onPressed,
        tooltip: label,
        icon: Icon(icon, size: 20),
        color: _BookingColors.textPrimary,
        disabledColor: _BookingColors.textMuted.withValues(alpha: .4),
        hoverColor: _BookingColors.gold.withValues(alpha: .1),
        style: IconButton.styleFrom(
          backgroundColor: _BookingColors.surfaceSecondary,
          minimumSize: const Size.square(40),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
}

class _TimeTile extends StatelessWidget {
  final String time;
  final bool selected;
  final VoidCallback onPressed;
  const _TimeTile({
    required this.time,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 46,
        child: Material(
          color: selected ? _BookingColors.gold : _BookingColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: selected ? _BookingColors.gold : _BookingColors.border,
            ),
          ),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(10),
            hoverColor: _BookingColors.gold.withValues(alpha: .08),
            focusColor: _BookingColors.gold.withValues(alpha: .12),
            child: Center(
              child: Text(
                time,
                style: GoogleFonts.inter(
                  color: selected
                      ? _BookingColors.background
                      : _BookingColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      );
}

class _SelectionCard extends StatefulWidget {
  final bool selected;
  final VoidCallback onPressed;
  final String semanticLabel;
  final Widget child;
  const _SelectionCard({
    required this.selected,
    required this.onPressed,
    required this.semanticLabel,
    required this.child,
  });

  @override
  State<_SelectionCard> createState() => _SelectionCardState();
}

class _SelectionCardState extends State<_SelectionCard> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: widget.selected,
        label: widget.semanticLabel,
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          onShowHoverHighlight: (value) => setState(() => _hovered = value),
          onShowFocusHighlight: (value) => setState(() => _focused = value),
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
              widget.onPressed();
              return null;
            }),
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            transform: Matrix4.translationValues(0, _hovered ? -1 : 0, 0),
            decoration: BoxDecoration(
              color: widget.selected
                  ? _BookingColors.gold.withValues(alpha: .1)
                  : _hovered
                      ? _BookingColors.cardHover
                      : _BookingColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _focused || widget.selected
                    ? _BookingColors.gold
                    : _hovered
                        ? _BookingColors.borderGold
                        : _BookingColors.border,
                width: _focused ? 2 : 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onPressed,
                borderRadius: BorderRadius.circular(14),
                child: widget.child,
              ),
            ),
          ),
        ),
      );
}

class _BookingSummary extends StatelessWidget {
  final List<Map<String, dynamic>> services;
  final Map<String, dynamic>? professional;
  final DateTime? date;
  final String? time;
  final int totalDuration;
  final String totalPrice;
  final bool saving;
  final bool enabled;
  final String Function(dynamic) formatPrice;
  final String Function(String) initials;
  final VoidCallback onConfirm;
  final VoidCallback onAddService;
  final ValueChanged<Map<String, dynamic>> onRemoveService;

  const _BookingSummary({
    required this.services,
    required this.professional,
    required this.date,
    required this.time,
    required this.totalDuration,
    required this.totalPrice,
    required this.saving,
    required this.enabled,
    required this.formatPrice,
    required this.initials,
    required this.onConfirm,
    required this.onAddService,
    required this.onRemoveService,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _BookingColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _BookingColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Seu agendamento',
              style: GoogleFonts.inter(
                color: _BookingColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            const _SummaryLabel('SERVIÇOS'),
            const SizedBox(height: 10),
            if (services.isEmpty)
              const _SummaryPlaceholder('Ainda não selecionado')
            else
              ...services.map(
                (service) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.content_cut_rounded,
                        color: _BookingColors.gold,
                        size: 17,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              service['nome'].toString(),
                              style: GoogleFonts.inter(
                                color: _BookingColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${service['duracao_min']} min',
                              style: GoogleFonts.inter(
                                color: _BookingColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        formatPrice(service['preco']),
                        style: GoogleFonts.inter(
                          color: _BookingColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: () => onRemoveService(service),
                        tooltip: 'Remover ${service['nome']}',
                        icon: const Icon(Icons.close_rounded, size: 16),
                        color: _BookingColors.textMuted,
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
            TextButton.icon(
              onPressed: onAddService,
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text('Adicionar outro serviço'),
              style: TextButton.styleFrom(
                foregroundColor: _BookingColors.gold,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 44),
                textStyle: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const _SummaryDivider(),
            const _SummaryLabel('PROFISSIONAL'),
            const SizedBox(height: 10),
            if (professional == null)
              const _SummaryPlaceholder('Ainda não selecionado')
            else
              Row(
                children: [
                  _InitialAvatar(
                    initials: initials(professional!['nome'].toString()),
                    size: 40,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          professional!['nome'].toString(),
                          style: GoogleFonts.inter(
                            color: _BookingColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Barbeiro',
                          style: GoogleFonts.inter(
                            color: _BookingColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            const _SummaryDivider(),
            Row(
              children: [
                Expanded(
                  child: _SummaryValue(
                    label: 'DATA',
                    value: date == null
                        ? 'Ainda não selecionada'
                        : DateFormat('dd/MM/yyyy').format(date!),
                    placeholder: date == null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _SummaryValue(
                    label: 'HORÁRIO',
                    value: time ?? 'Ainda não selecionado',
                    placeholder: time == null,
                  ),
                ),
              ],
            ),
            const _SummaryDivider(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total',
                        style: GoogleFonts.inter(
                          color: _BookingColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      if (services.isNotEmpty)
                        Text(
                          '$totalDuration minutos',
                          style: GoogleFonts.inter(
                            color: _BookingColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  totalPrice,
                  style: GoogleFonts.inter(
                    color: _BookingColors.gold,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: enabled && !saving ? onConfirm : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _BookingColors.gold,
                  foregroundColor: _BookingColors.background,
                  disabledBackgroundColor:
                      _BookingColors.gold.withValues(alpha: .25),
                  disabledForegroundColor:
                      _BookingColors.background.withValues(alpha: .55),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .5,
                  ),
                ),
                child: saving
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _BookingColors.background,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text('Confirmando...', style: GoogleFonts.inter()),
                        ],
                      )
                    : const Text('Confirmar agendamento'),
              ),
            ),
          ],
        ),
      );
}

class _InitialAvatar extends StatelessWidget {
  final String initials;
  final double size;
  const _InitialAvatar({required this.initials, required this.size});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _BookingColors.gold.withValues(alpha: .15),
          borderRadius: BorderRadius.circular(size >= 50 ? 12 : 10),
        ),
        child: Text(
          initials,
          style: GoogleFonts.inter(
            color: _BookingColors.gold,
            fontSize: size >= 50 ? 16 : 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _SummaryLabel extends StatelessWidget {
  final String text;
  const _SummaryLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: GoogleFonts.inter(
          color: _BookingColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: .7,
        ),
      );
}

class _SummaryPlaceholder extends StatelessWidget {
  final String text;
  const _SummaryPlaceholder(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: GoogleFonts.inter(
          color: _BookingColors.textMuted,
          fontSize: 13,
        ),
      );
}

class _SummaryValue extends StatelessWidget {
  final String label;
  final String value;
  final bool placeholder;
  const _SummaryValue({
    required this.label,
    required this.value,
    required this.placeholder,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryLabel(label),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: placeholder
                  ? _BookingColors.textMuted
                  : _BookingColors.textPrimary,
              fontSize: placeholder ? 12 : 14,
              fontWeight: placeholder ? FontWeight.w400 : FontWeight.w600,
            ),
          ),
        ],
      );
}

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Divider(height: 1, color: _BookingColors.border),
      );
}

class _LoadingState extends StatelessWidget {
  final String label;
  const _LoadingState({required this.label});

  @override
  Widget build(BuildContext context) => Semantics(
        label: label,
        liveRegion: true,
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: CircularProgressIndicator(
              color: _BookingColors.gold,
              strokeWidth: 2,
            ),
          ),
        ),
      );
}

class _MessageState extends StatelessWidget {
  final String label;
  const _MessageState({required this.label});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _BookingColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _BookingColors.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: _BookingColors.textSecondary,
            fontSize: 13,
          ),
        ),
      );
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.erro.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          message,
          style: GoogleFonts.inter(color: AppTheme.erro, fontSize: 13),
        ),
      );
}
