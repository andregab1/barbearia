// ==========================================
// TELA: Home Admin
// RF12 - Serviços | RF13 - Relatório | RF14 - Colaboradores | RF04 - Personalização
// ==========================================
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'report_download_stub.dart'
    if (dart.library.html) 'report_download_web.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/barbearia_theme_service.dart';
import '../../../features/auth/controllers/auth_controller.dart';
import '../../../features/barbeiro/screens/horarios_schedule_screen.dart';
import '../../../shared/widgets/perfil_screen.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/app_modal.dart';
import '../../../shared/widgets/getcutt_calendar.dart';
import '../../../shared/widgets/premium_ui.dart';
import '../../../shared/widgets/responsive_nav_shell.dart';
import '../controllers/admin_controller.dart';
import '../widgets/chart_card.dart';
import 'personalizacao_screen.dart';
import 'financeiro_screen.dart';
import 'contabilidade_screen.dart';
import 'agenda_admin_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _paginaAtual = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminController>().carregarServicos();
      context.read<AdminController>().carregarCategorias();
      context.read<AdminController>().carregarColaboradores();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final paginas = [
      const AgendaAdminScreen(),
      const _RelatorioTab(),
      const FinanceiroScreen(),
      const ContabilidadeScreen(),
      const _EquipeTab(),
      const _ServicosTab(),
      const PersonalizacaoScreen(),
      const PerfilScreen(),
    ];
    const itens = [
      NavShellItem(
          icon: Icons.calendar_month_outlined,
          activeIcon: Icons.calendar_month,
          label: 'Agenda'),
      NavShellItem(
          icon: Icons.bar_chart_outlined,
          activeIcon: Icons.bar_chart,
          label: 'Relatório'),
      NavShellItem(
          icon: Icons.account_balance_wallet_outlined,
          activeIcon: Icons.account_balance_wallet,
          label: 'Financeiro'),
      NavShellItem(
          icon: Icons.account_tree_outlined,
          activeIcon: Icons.account_tree,
          label: 'Contabilidade'),
      NavShellItem(
          icon: Icons.group_outlined, activeIcon: Icons.group, label: 'Equipe'),
      NavShellItem(
          icon: Icons.content_cut_outlined,
          activeIcon: Icons.content_cut,
          label: 'Serviços'),
      NavShellItem(
          icon: Icons.palette_outlined,
          activeIcon: Icons.palette,
          label: 'Visual'),
      NavShellItem(
          icon: Icons.person_outline_rounded,
          activeIcon: Icons.person_rounded,
          label: 'Perfil'),
    ];
    return ResponsiveNavShell(
      currentIndex: _paginaAtual,
      onTap: (i) => setState(() => _paginaAtual = i),
      items: itens,
      tituloMarca: 'GetCutt',
      userName: auth.nomeUsuario ?? 'Administrador',
      userRole: 'Administrador',
      onLogout: auth.logout,
      onProfile: () => setState(() => _paginaAtual = itens.length - 1),
      body: paginas[_paginaAtual],
    );
  }
}

// ==========================================
// TAB: Relatório de Faturamento
// RF13 - Faturamento Diário
// ==========================================
class _RelatorioTab extends StatefulWidget {
  const _RelatorioTab();
  @override
  State<_RelatorioTab> createState() => _RelatorioTabState();
}

class _RelatorioTabState extends State<_RelatorioTab> {
  late DateTime _inicio;
  late DateTime _fim;
  bool _gerando = false;
  int? _profissionalId;
  int? _servicoId;
  String? _status;

  static const _statusLabels = <String, String>{
    'pendente': 'Pendente',
    'confirmado': 'Confirmado',
    'concluido': 'Concluído',
    'cancelado': 'Cancelado',
  };

  @override
  void initState() {
    super.initState();
    final hoje = DateTime.now();
    _fim = DateTime(hoje.year, hoje.month, hoje.day);
    _inicio = _fim.subtract(const Duration(days: 29));
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  String _date(DateTime value) => DateFormat('yyyy-MM-dd').format(value);
  String _label(DateTime value) => DateFormat('dd/MM/yyyy').format(value);
  int get _dias => _fim.difference(_inicio).inDays + 1;

  Future<void> _pickRange(BuildContext anchorContext) async {
    final selected = await showGetCuttDateRangePickerPopover(
      context: anchorContext,
      initialStart: _inicio,
      initialEnd: _fim,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      title: 'Selecionar período do relatório',
    );
    if (selected == null || !mounted) return;
    setState(() {
      _inicio = selected.start;
      _fim = selected.end;
    });
  }

  Future<void> _load() async {
    if (_fim.isBefore(_inicio) || _dias > 90) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Escolha um período válido de até 90 dias.')));
      return;
    }
    setState(() => _gerando = true);
    await context.read<AdminController>().carregarRelatorioPeriodo(
          dataIni: _date(_inicio),
          dataFim: _date(_fim),
          profissionalId: _profissionalId,
          servicoId: _servicoId,
          status: _status,
        );
    if (mounted) setState(() => _gerando = false);
  }

  List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Widget _buildCharts(Map<String, dynamic> rel, Color color) {
    final services = _mapList(rel['totais_por_servico']);
    final serviceValues = services
        .map((item) =>
            double.tryParse(item['concluidos']?.toString() ?? '0') ?? 0)
        .toList();
    final maxService = serviceValues.fold<double>(
        0, (max, value) => value > max ? value : max);
    final maxY = maxService <= 0 ? 1.0 : maxService + 1;
    final statuses = <Map<String, dynamic>>[
      {'label': 'Concluídos', 'value': rel['total_concluidos'], 'color': color},
      {
        'label': 'Em aberto',
        'value': rel['total_pendentes'],
        'color': const Color(0xFF3B82F6),
      },
      {
        'label': 'Cancelados',
        'value': rel['total_cancelados'],
        'color': const Color(0xFFE05252),
      },
    ]
        .map((item) => {
              ...item,
              'value': int.tryParse(item['value']?.toString() ?? '0') ?? 0,
            })
        .where((item) => (item['value'] as int) > 0)
        .toList();
    final statusTotal =
        statuses.fold<int>(0, (sum, item) => sum + item['value'] as int);

    Widget emptyChart(String message) => SizedBox(
          height: 230,
          child: Center(
            child: Text(
              message,
              style: GoogleFonts.inter(
                color: AppTheme.corTextoSecundario,
                fontSize: 13,
              ),
            ),
          ),
        );

    final barChart = services.isEmpty
        ? emptyChart('Sem atendimentos por serviço no período.')
        : SizedBox(
            height: 230,
            child: BarChart(
              BarChartData(
                minY: 0,
                maxY: maxY,
                alignment: BarChartAlignment.spaceAround,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppTheme.border.withValues(alpha: .55),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, _) => Text(
                        value.toInt().toString(),
                        style: GoogleFonts.inter(
                          color: AppTheme.corTextoSecundario,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      getTitlesWidget: (value, _) {
                        final index = value.toInt();
                        if (index < 0 || index >= services.length)
                          return SizedBox.shrink();
                        final label =
                            services[index]['servico']?.toString() ?? 'Serviço';
                        return Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            label.length > 12
                                ? '${label.substring(0, 12)}…'
                                : label,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: AppTheme.corTextoSecundario,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(services.length, (index) {
                  final value = serviceValues[index];
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: value,
                        width: 24,
                        color: color,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                    ],
                  );
                }),
              ),
            ),
          );

    final pieChart = statuses.isEmpty
        ? emptyChart('Sem status registrados no período.')
        : SizedBox(
            height: 230,
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      centerSpaceRadius: 42,
                      sectionsSpace: 2,
                      sections: statuses.map((item) {
                        final value = item['value'] as int;
                        return PieChartSectionData(
                          value: value.toDouble(),
                          color: item['color'] as Color,
                          radius: 72,
                          title: '${((value / statusTotal) * 100).round()}%',
                          titleStyle: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: statuses.map((item) {
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: item['color'] as Color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${item['label']}: ${item['value']}',
                                style: GoogleFonts.inter(
                                  color: AppTheme.corTextoSecundario,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          Expanded(
              child: ChartCard(
                  title: 'Atendimentos por serviço', child: barChart)),
          Expanded(
              child:
                  ChartCard(title: 'Status dos atendimentos', child: pieChart)),
        ];
        return constraints.maxWidth < 760
            ? Column(children: [cards[0], SizedBox(height: 16), cards[1]])
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [cards[0], SizedBox(width: 16), cards[1]]);
      },
    );
  }

  Future<Uint8List?> _loadOptionalReportAsset(String assetPath) async {
    try {
      return await loadReportAsset(assetPath)
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      return null;
    }
  }

  Future<void> _downloadModeloClassico() async {
    final rel = context.read<AdminController>().relatorio;
    final auth = context.read<AuthController>();
    final rawItems = (rel['atendimentos'] as List? ?? const []);
    final items =
        rawItems.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    final gold = pdf.PdfColor.fromInt(
        context.read<BarbeariaThemeService>().corPrimaria.value);
    final reportAssets = await Future.wait<Uint8List?>([
      _loadOptionalReportAsset('assets/logo_getcutt_mark.png'),
      _loadOptionalReportAsset('assets/logo_getcutt_wordmark.png'),
    ]);
    final mark =
        reportAssets[0] == null ? null : pw.MemoryImage(reportAssets[0]!);
    final wordmark =
        reportAssets[1] == null ? null : pw.MemoryImage(reportAssets[1]!);
    final money = (dynamic value) =>
        NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$')
            .format(double.tryParse(value?.toString() ?? '') ?? 0);
    final status = (dynamic value) {
      final key = value?.toString().toLowerCase() ?? '';
      return _statusLabels[key] ?? (key.isEmpty ? '-' : key);
    };
    final duration =
        int.tryParse(rel['duracao_total_realizada']?.toString() ?? '') ?? 0;
    final durationText = duration == 0
        ? '—'
        : (duration ~/ 60).toString() +
            'h' +
            (duration % 60).toString().padLeft(2, '0');
    final peak = rel['pico_hora'] == null
        ? '—'
        : rel['pico_hora'].toString() +
            'h - ' +
            ((int.tryParse(rel['pico_hora'].toString()) ?? 0) + 1).toString() +
            'h';
    final serviceGroups = (rel['totais_por_servico'] as List? ?? const []);
    final topService = serviceGroups.isEmpty
        ? '—'
        : (serviceGroups.first as Map)['servico']?.toString() ?? '—';
    final pageMargin = const pw.EdgeInsets.fromLTRB(40, 40, 40, 40);

    pw.Widget meta(String label, String value) => pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.SizedBox(
                width: 72,
                child: pw.Text(label,
                    style: const pw.TextStyle(
                        color: pdf.PdfColors.grey700, fontSize: 8))),
            pw.SizedBox(width: 6),
            pw.Expanded(
                child: pw.Text(value.isEmpty ? '—' : value,
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold))),
          ],
        );

    pw.Widget summary(String title, List<List<String>> rows,
            {bool last = false}) =>
        pw.Expanded(
          child: pw.Container(
            height: 145,
            margin: pw.EdgeInsets.only(right: last ? 0 : 8),
            decoration: pw.BoxDecoration(
                border: pw.Border.all(color: pdf.PdfColors.grey300, width: .6)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Container(
                    height: 26,
                    alignment: pw.Alignment.center,
                    color: gold,
                    child: pw.Text(title,
                        style: pw.TextStyle(
                            color: pdf.PdfColors.white,
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold))),
                pw.Table.fromTextArray(
                    border: pw.TableBorder.symmetric(
                        inside: pw.BorderSide(
                            color: pdf.PdfColors.grey300, width: .5)),
                    cellStyle: const pw.TextStyle(fontSize: 8),
                    cellPadding: const pw.EdgeInsets.symmetric(
                        horizontal: 7, vertical: 5),
                    columnWidths: const {
                      0: pw.FlexColumnWidth(),
                      1: pw.FixedColumnWidth(64)
                    },
                    cellAlignments: const {1: pw.Alignment.centerRight},
                    data: rows.map((row) => [row[0], row[1]]).toList()),
              ],
            ),
          ),
        );

    pw.Widget reportHeader() => pw.Column(children: [
          pw.Table(
            columnWidths: const {
              0: pw.FixedColumnWidth(115),
              1: pw.FlexColumnWidth(),
              2: pw.FixedColumnWidth(115)
            },
            children: [
              pw.TableRow(children: [
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Row(
                    children: [
                      if (mark != null)
                        pw.SizedBox(
                            width: 42,
                            height: 42,
                            child: pw.Image(mark, fit: pw.BoxFit.contain))
                      else
                        pw.Text('GETCUTT',
                            style: pw.TextStyle(
                                color: gold,
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold)),
                      if (wordmark != null) ...[
                        pw.SizedBox(width: 7),
                        pw.SizedBox(
                            width: 66,
                            height: 24,
                            child: pw.Image(wordmark, fit: pw.BoxFit.contain)),
                      ],
                    ],
                  ),
                ),
                pw.Center(
                    child: pw.Text('Relatório de Agendamentos',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                            fontSize: 17, fontWeight: pw.FontWeight.bold))),
                pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                              DateFormat('dd/MM/yyyy HH:mm')
                                  .format(DateTime.now()),
                              style: const pw.TextStyle(
                                  fontSize: 8,
                                  color: pdf.PdfColors.grey700,
                                  lineSpacing: 1.2)),
                          pw.SizedBox(height: 4),
                          pw.Text('MODELO 1 - ESPELHO CLÃSSICO',
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  color: gold,
                                  fontWeight: pw.FontWeight.bold,
                                  lineSpacing: 1.2)),
                        ])),
              ])
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Divider(color: pdf.PdfColors.grey500, thickness: .7),
          pw.SizedBox(height: 12),
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                  meta('Barbearia:',
                      rel['barbearia_nome']?.toString() ?? 'Não informada'),
                  meta('Período:', _label(_inicio) + ' a ' + _label(_fim)),
                  meta('Unidade:', 'Não informada'),
                ])),
            pw.SizedBox(width: 18),
            pw.Expanded(
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                  meta(
                      'Profissional:',
                      _profissionalId == null
                          ? 'Todos'
                          : _profissionalId.toString()),
                  meta('Status:', _status == null ? 'Todos' : status(_status)),
                  meta('Ordenação:', 'Data / horário'),
                ])),
            pw.SizedBox(width: 18),
            pw.Expanded(
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                  meta('Relatório:', 'Agendamentos'),
                  meta('Gerado por:', auth.nomeUsuario ?? 'Administrador'),
                  meta('Formato:', 'A4 / impressão'),
                ])),
          ]),
          pw.SizedBox(height: 16),
        ]);

    List<List<String>> tableRows(List<Map<String, dynamic>> source) =>
        source.map((item) {
          final when = DateTime.tryParse(item['data_hora']?.toString() ?? '');
          return [
            when == null ? '—' : DateFormat('dd/MM').format(when),
            when == null ? '—' : DateFormat('HH:mm').format(when),
            item['cliente']?.toString() ?? '—',
            item['servico']?.toString() ?? '—',
            item['barbeiro']?.toString() ?? '—',
            status(item['status']),
            money(item['valor_cobrado']),
          ];
        }).toList();

    pw.Widget appointmentsTable(List<Map<String, dynamic>> source) =>
        pw.Table.fromTextArray(
          headers: const [
            'Data',
            'Hora',
            'Cliente',
            'Serviço',
            'Profissional',
            'Status',
            'Valor'
          ],
          data: tableRows(source),
          headerDecoration: pw.BoxDecoration(color: gold),
          headerStyle: pw.TextStyle(
              color: pdf.PdfColors.white,
              fontSize: 8,
              fontWeight: pw.FontWeight.bold),
          headerPadding:
              const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 7),
          headerAlignments: const {
            0: pw.Alignment.center,
            1: pw.Alignment.center,
            2: pw.Alignment.center,
            3: pw.Alignment.center,
            4: pw.Alignment.center,
            5: pw.Alignment.center,
            6: pw.Alignment.center
          },
          cellStyle: const pw.TextStyle(fontSize: 8),
          cellPadding:
              const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
          border: pw.TableBorder.all(color: pdf.PdfColors.grey300, width: .5),
          columnWidths: const {
            0: pw.FixedColumnWidth(41),
            1: pw.FixedColumnWidth(41),
            2: pw.FixedColumnWidth(87),
            3: pw.FixedColumnWidth(105),
            4: pw.FixedColumnWidth(100),
            5: pw.FixedColumnWidth(71),
            6: pw.FixedColumnWidth(70)
          },
          cellAlignments: const {
            0: pw.Alignment.center,
            1: pw.Alignment.center,
            2: pw.Alignment.centerLeft,
            3: pw.Alignment.centerLeft,
            4: pw.Alignment.centerLeft,
            5: pw.Alignment.center,
            6: pw.Alignment.centerRight
          },
          cellDecoration: (index, data, rowNum) => pw.BoxDecoration(
              color:
                  rowNum.isEven ? pdf.PdfColors.grey100 : pdf.PdfColors.white),
        );

    pw.Widget periodSummary() => pw.Column(children: [
          pw.Text('Resumo do período',
              style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: pdf.PdfColors.grey700)),
          pw.SizedBox(height: 8),
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
            summary('Geral', [
              [
                'Agendamentos',
                rel['total_agendamentos']?.toString() ?? items.length.toString()
              ],
              ['Concluídos', rel['total_concluidos']?.toString() ?? '0'],
              ['Cancelados', rel['total_cancelados']?.toString() ?? '0'],
              ['Em aberto', rel['total_pendentes']?.toString() ?? '0'],
            ]),
            summary('Agenda', [
              ['Duração realizada', durationText],
              ['Horas disponíveis', '—'],
              ['Ocupação', '—'],
              ['Pico de agenda', peak],
            ]),
            summary(
                'Financeiro',
                [
                  ['Valor concluído', money(rel['valor_realizado'])],
                  ['Valor em aberto', money(rel['valor_agendado'])],
                  ['Ticket médio', money(rel['ticket_medio'])],
                  ['Serviço destaque', topService],
                ],
                last: true),
          ]),
          pw.SizedBox(height: 16),
          pw.Container(
            width: double.infinity,
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: pw.BoxDecoration(
                color: pdf.PdfColor.fromInt(0xFFFFF7E5),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5))),
            child: pw.RichText(
                text: pw.TextSpan(children: [
              pw.TextSpan(
                  text: 'Compatível com dados do GetCutt: ',
                  style: pw.TextStyle(
                      color: gold,
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold)),
              pw.TextSpan(
                  text:
                      'agenda, serviço, profissional, status, horários e valor do serviço.',
                  style: const pw.TextStyle(fontSize: 8)),
            ])),
          ),
        ]);

    final doc = pw.Document();
    const rowsPerPage = 12;
    if (items.isEmpty) {
      doc.addPage(pw.Page(
        pageFormat: pdf.PdfPageFormat.a4,
        margin: pageMargin,
        build: (_) => pw.Column(children: [
          reportHeader(),
          pw.Container(
              width: double.infinity,
              padding:
                  const pw.EdgeInsets.symmetric(vertical: 22, horizontal: 12),
              decoration: pw.BoxDecoration(
                  border:
                      pw.Border.all(color: pdf.PdfColors.grey300, width: .6)),
              child: pw.Center(
                  child: pw.Text(
                      'Nenhum agendamento encontrado para o período selecionado.',
                      style: const pw.TextStyle(
                          fontSize: 9, color: pdf.PdfColors.grey700)))),
          pw.SizedBox(height: 18),
          periodSummary(),
        ]),
      ));
    } else {
      for (var offset = 0; offset < items.length; offset += rowsPerPage) {
        final pageItems = items.skip(offset).take(rowsPerPage).toList();
        doc.addPage(pw.Page(
          pageFormat: pdf.PdfPageFormat.a4,
          margin: pageMargin,
          build: (_) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                reportHeader(),
                appointmentsTable(pageItems),
                if (offset + pageItems.length >= items.length) ...[
                  pw.SizedBox(height: 18),
                  periodSummary(),
                ],
              ]),
        ));
      }
    }
    try {
      final pdfBytes = await doc.save();
      await downloadReportPdf(
        pdfBytes,
        'relatorio-' + _date(_inicio) + '-' + _date(_fim) + '.pdf',
      );
      if (mounted) {
        AppToast.show(context, 'PDF gerado com sucesso.',
            type: AppToastType.success);
      }
    } catch (error, stackTrace) {
      debugPrint('Falha ao gerar/baixar relatório PDF: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        AppToast.show(context, 'Não foi possível baixar o PDF.',
            type: AppToastType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AdminController>();
    final rel = ctrl.relatorio;
    final cor = Theme.of(context).colorScheme.primary;
    final items = (rel['atendimentos'] as List? ?? const []);
    return _TabShell(
        child: SingleChildScrollView(
            child: PremiumPageFrame(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
          const PremiumPageHeader(
            title: 'Relatório',
            subtitle:
                'Consulte atendimentos e faturamento em períodos de até 90 dias.',
          ),
          SizedBox(height: 24),
          Wrap(spacing: 12, runSpacing: 12, children: [
            Builder(
                builder: (buttonContext) => OutlinedButton.icon(
                    onPressed: () => _pickRange(buttonContext),
                    icon: Icon(Icons.date_range_outlined),
                    label: Text(
                        'Período: ' + _label(_inicio) + ' a ' + _label(_fim)))),
            DropdownButton<String?>(
                value: _status,
                hint: Text('Todos os status'),
                items: [
                  DropdownMenuItem<String?>(
                      value: null, child: Text('Todos os status')),
                  ..._statusLabels.entries.map((entry) =>
                      DropdownMenuItem<String?>(
                          value: entry.key, child: Text(entry.value)))
                ],
                onChanged: (value) => setState(() => _status = value)),
            DropdownButton<int?>(
                value: _profissionalId,
                hint: Text('Todos os profissionais'),
                items: [
                  DropdownMenuItem<int?>(
                      value: null, child: Text('Todos os profissionais')),
                  ...context.read<AdminController>().colaboradores.map((item) =>
                      DropdownMenuItem<int?>(
                          value: int.tryParse(item['id'].toString()),
                          child: Text(item['nome']?.toString() ?? '-')))
                ],
                onChanged: (value) => setState(() => _profissionalId = value)),
            DropdownButton<int?>(
                value: _servicoId,
                hint: Text('Todos os serviços'),
                items: [
                  DropdownMenuItem<int?>(
                      value: null, child: Text('Todos os serviços')),
                  ...context.read<AdminController>().servicos.map((item) =>
                      DropdownMenuItem<int?>(
                          value: int.tryParse(item['id'].toString()),
                          child: Text(item['nome']?.toString() ?? '-')))
                ],
                onChanged: (value) => setState(() => _servicoId = value)),
            FilledButton.icon(
                onPressed: _gerando ? null : _load,
                icon: _gerando
                    ? SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.assessment_outlined),
                label: Text(_gerando ? 'Gerando...' : 'Gerar relatório')),
            OutlinedButton.icon(
                onPressed: _downloadModeloClassico,
                icon: Icon(Icons.download_outlined),
                label: Text('Baixar PDF')),
          ]),
          SizedBox(height: 10),
          Text(
              'Período selecionado: ' +
                  _dias.toString() +
                  ' dia(s) • limite máximo de 90 dias',
              style: GoogleFonts.inter(
                  color:
                      _dias > 90 ? AppTheme.erro : AppTheme.corTextoSecundario,
                  fontSize: 12)),
          SizedBox(height: 28),
          Container(
              width: double.infinity,
              padding: EdgeInsets.all(28),
              decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    cor.withValues(alpha: .16),
                    cor.withValues(alpha: .03)
                  ]),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cor.withValues(alpha: .25))),
              child: ctrl.carregandoRelatorio
                  ? Center(child: CircularProgressIndicator())
                  : Row(children: [
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('Faturamento do período',
                                style: GoogleFonts.inter(
                                    color: AppTheme.corTextoSecundario,
                                    fontSize: 13)),
                            SizedBox(height: 10),
                            Text(
                                'R\$ ' +
                                    (rel['total_geral']?.toString() ?? '0.00'),
                                style: GoogleFonts.inter(
                                    color: AppTheme.corTexto,
                                    fontSize: 36,
                                    fontWeight: FontWeight.w700))
                          ])),
                      Text(items.length.toString() + ' atendimentos',
                          style: GoogleFonts.inter(
                              color: AppTheme.corTextoSecundario, fontSize: 14))
                    ])),
          if (ctrl.erro.isNotEmpty) ...[
            SizedBox(height: 12),
            Text(
              ctrl.erro,
              style: GoogleFonts.inter(
                color: AppTheme.erro,
                fontSize: 13,
              ),
            ),
          ],
          SizedBox(height: 20),
          _buildCharts(rel, cor),
          SizedBox(height: 28),
          Text('Atendimentos do período',
              style: GoogleFonts.inter(
                  color: AppTheme.corTexto,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
          SizedBox(height: 12),
          if (items.isEmpty)
            Container(
                width: double.infinity,
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                    color: AppTheme.surfaceElev,
                    borderRadius: BorderRadius.circular(14)),
                child: Center(
                    child: Text('Nenhum atendimento concluído no período.',
                        style: GoogleFonts.inter(
                            color: AppTheme.corTextoSecundario, fontSize: 14))))
          else
            ...items.map((raw) {
              final item = Map<String, dynamic>.from(raw as Map);
              final when =
                  DateTime.tryParse(item['data_hora']?.toString() ?? '');
              final value =
                  double.tryParse(item['valor_cobrado']?.toString() ?? '0') ??
                      0;
              return Container(
                  margin: EdgeInsets.only(bottom: 10),
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                      color: AppTheme.surfaceElev,
                      borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    Text(
                        when == null
                            ? '-'
                            : DateFormat('dd/MM/yyyy').format(when),
                        style: GoogleFonts.inter(
                            color: cor, fontWeight: FontWeight.w700)),
                    SizedBox(width: 14),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(item['servico']?.toString() ?? 'Serviço',
                              style: GoogleFonts.inter(
                                  color: AppTheme.corTexto,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14)),
                          SizedBox(height: 2),
                          Text(
                              (item['barbeiro']?.toString() ?? '-') +
                                  ' • ' +
                                  (item['cliente']?.toString() ?? '-'),
                              style: GoogleFonts.inter(
                                  color: AppTheme.corTextoSecundario,
                                  fontSize: 12))
                        ])),
                    Text('R\$ ' + value.toStringAsFixed(2),
                        style: GoogleFonts.inter(
                            color: cor,
                            fontWeight: FontWeight.w700,
                            fontSize: 15))
                  ]));
            }),
        ]))));
  }
}

// TAB: Gestão de Serviços
// RF12 - Serviços e Preços
// ==========================================
class _ServicosTab extends StatefulWidget {
  const _ServicosTab();
  @override
  State<_ServicosTab> createState() => _ServicosTabState();
}

class _ServicosTabState extends State<_ServicosTab> {
  static const _pageSize = 10;
  final _searchController = TextEditingController();
  String _search = '',
      _categoryFilter = 'all',
      _status = 'all',
      _sort = 'name-asc',
      _view = 'list';
  int _page = 1;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _norm(Object? value) => (value?.toString() ?? '')
      .toLowerCase()
      .replaceAll(RegExp(r'[áàãâä]'), 'a')
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[íìîï]'), 'i')
      .replaceAll(RegExp(r'[óòõôö]'), 'o')
      .replaceAll(RegExp(r'[úùûü]'), 'u')
      .replaceAll('ç', 'c');
  bool _active(Map<String, dynamic> s) {
    final v = s['ativo'];
    return v == null ||
        v == true ||
        v == 1 ||
        v.toString() == '1' ||
        v.toString() == 'true';
  }

  String _serviceCategory(Map<String, dynamic> s) {
    final explicit = s['categoria']?.toString().trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final t = _norm(
        (s['nome'] ?? '').toString() + ' ' + (s['descricao'] ?? '').toString());
    if (t.contains('combo') || t.contains('+')) return 'Combo';
    if (t.contains('barba')) return 'Barba';
    if (t.contains('limpeza')) return 'Limpeza';
    if (t.contains('corte')) return 'Corte';
    return 'Outros';
  }

  double _price(Map<String, dynamic> s) =>
      double.tryParse((s['preco'] ?? 0).toString()) ?? 0;
  int _duration(Map<String, dynamic> s) =>
      int.tryParse((s['duracao_min'] ?? 0).toString()) ?? 0;
  String _money(Object? v) =>
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$')
          .format(double.tryParse((v ?? 0).toString()) ?? 0);
  List<String> _categories(List<Map<String, dynamic>> all) {
    final r =
        all.map(_serviceCategory).where((v) => v != 'Outros').toSet().toList();
    r.sort((a, b) => _norm(a).compareTo(_norm(b)));
    return r;
  }

  List<Map<String, dynamic>> _result(List<Map<String, dynamic>> all) {
    final q = _norm(_search);
    final r = all.where((s) {
      final text = _norm((s['nome'] ?? '').toString() +
          ' ' +
          (s['descricao'] ?? '').toString() +
          ' ' +
          _serviceCategory(s));
      return (q.isEmpty || text.contains(q)) &&
          (_categoryFilter == 'all' ||
              _norm(_serviceCategory(s)) == _norm(_categoryFilter)) &&
          (_status == 'all' ||
              (_status == 'active' ? _active(s) : !_active(s)));
    }).toList();
    r.sort((a, b) {
      switch (_sort) {
        case 'name-desc':
          return _norm(b['nome']).compareTo(_norm(a['nome']));
        case 'price-asc':
          return _price(a).compareTo(_price(b));
        case 'price-desc':
          return _price(b).compareTo(_price(a));
        case 'duration-asc':
          return _duration(a).compareTo(_duration(b));
        case 'duration-desc':
          return _duration(b).compareTo(_duration(a));
        default:
          return _norm(a['nome']).compareTo(_norm(b['nome']));
      }
    });
    return r;
  }

  void _clear() {
    _searchController.clear();
    setState(() {
      _search = '';
      _categoryFilter = 'all';
      _status = 'all';
      _sort = 'name-asc';
      _page = 1;
    });
  }

  Widget _modalInput(
          {required TextEditingController controller,
          required String label,
          String? hint,
          TextInputType? keyboardType,
          int maxLines = 1}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: GoogleFonts.inter(
                color: AppTheme.corTexto,
                fontSize: 15,
                fontWeight: FontWeight.w600)),
        SizedBox(height: 8),
        TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: GoogleFonts.inter(color: AppTheme.corTexto, fontSize: 16),
            decoration: InputDecoration(
                hintText: hint,
                hintStyle: GoogleFonts.inter(
                    color: AppTheme.corTextoSecundario, fontSize: 15),
                filled: true,
                fillColor: AppTheme.surface,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 20, vertical: 17),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppTheme.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppTheme.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppTheme.gold, width: 1.2)))),
      ]);

  Future<Map<String, dynamic>?> _newCategory(BuildContext context) {
    final name = TextEditingController();
    return AppModal.showSidePanel<Map<String, dynamic>>(
      context: context,
      title: 'Nova categoria',
      subtitle: 'Organize seus serviços por uma nova divisão.',
      child: _modalInput(
          controller: name,
          label: 'Nome da categoria',
          hint: 'Ex.: Tratamentos'),
      actions: [
        Consumer<AdminController>(
            builder: (panelContext, ctrl, _) =>
                Row(mainAxisSize: MainAxisSize.min, children: [
                  AppModalCancelButton(
                      onPressed: () => Navigator.pop(panelContext)),
                  SizedBox(width: 12),
                  AppModalPrimaryButton(
                      label: 'Criar categoria',
                      isLoading: ctrl.salvando,
                      onPressed: ctrl.salvando
                          ? null
                          : () async {
                              final created = await ctrl.criarCategoria(
                                  nome: name.text.trim());
                              if (created != null && panelContext.mounted)
                                Navigator.pop(panelContext, created);
                            }),
                ]))
      ],
    ).whenComplete(name.dispose);
  }

  void _form(BuildContext context, {Map<String, dynamic>? service}) {
    final name = TextEditingController(text: service?['nome']?.toString());
    final price = TextEditingController(text: service?['preco']?.toString());
    final duration =
        TextEditingController(text: service?['duracao_min']?.toString());
    final description =
        TextEditingController(text: service?['descricao']?.toString());
    final editing = service != null;
    final controller = context.read<AdminController>();
    int? selectedCategoryId =
        int.tryParse(service?['categoria_id']?.toString() ?? '');
    if (selectedCategoryId == null) {
      for (final category in controller.categorias) {
        if (category['nome']?.toString() == service?['categoria']?.toString()) {
          selectedCategoryId = int.tryParse(category['id'].toString());
          break;
        }
      }
    }

    AppModal.show(
      context: context,
      title: editing ? 'Editar serviço' : 'Novo serviço',
      subtitle: 'Defina o serviço disponível para agendamento.',
      size: AppModalSize.large,
      child: StatefulBuilder(
          builder:
              (modalContext, setModalState) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _modalInput(
                            controller: name,
                            label: 'Nome do serviço',
                            hint: 'Ex.: Corte masculino'),
                        SizedBox(height: 28),
                        Text('Categoria',
                            style: GoogleFonts.inter(
                                color: AppTheme.corTexto,
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                        SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                              child: DropdownButtonFormField<int>(
                                  value: selectedCategoryId,
                                  isExpanded: true,
                                  dropdownColor: AppTheme.surfaceElev,
                                  style: GoogleFonts.inter(
                                      color: AppTheme.corTexto, fontSize: 15),
                                  decoration: InputDecoration(
                                      hintText: 'Selecione uma categoria',
                                      hintStyle: GoogleFonts.inter(
                                          color: AppTheme.corTextoSecundario,
                                          fontSize: 15),
                                      filled: true,
                                      fillColor: AppTheme.surface,
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 17),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: BorderSide(
                                              color: AppTheme.border)),
                                      enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: BorderSide(
                                              color: AppTheme.border)),
                                      focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: BorderSide(
                                              color: AppTheme.gold,
                                              width: 1.2))),
                                  items: controller.categorias.map((category) => DropdownMenuItem<int>(value: int.tryParse(category['id'].toString()), child: Text(category['nome']?.toString() ?? ''))).toList(),
                                  onChanged: (value) => setModalState(() => selectedCategoryId = value))),
                          SizedBox(width: 16),
                          TextButton(
                              onPressed: () async {
                                final created =
                                    await _newCategory(modalContext);
                                if (created != null)
                                  setModalState(() {
                                    selectedCategoryId =
                                        int.tryParse(created['id'].toString());
                                  });
                              },
                              child: Text('+ Nova categoria')),
                        ]),
                        SizedBox(height: 28),
                        Row(children: [
                          Expanded(
                              child: _modalInput(
                                  controller: price,
                                  label: 'Preço',
                                  hint: 'R\$ 0,00',
                                  keyboardType: TextInputType.number)),
                          SizedBox(width: 16),
                          Expanded(
                              child: _modalInput(
                                  controller: duration,
                                  label: 'Duração',
                                  hint: 'Em minutos',
                                  keyboardType: TextInputType.number))
                        ]),
                        SizedBox(height: 28),
                        _modalInput(
                            controller: description,
                            label: 'Descrição',
                            hint: 'Descreva o que está incluído no serviço',
                            maxLines: 4),
                      ])),
      actions: [
        Consumer<AdminController>(
            builder: (modalContext, ctrl, _) =>
                Row(mainAxisSize: MainAxisSize.min, children: [
                  AppModalCancelButton(
                      onPressed: () => Navigator.pop(modalContext)),
                  SizedBox(width: 12),
                  AppModalPrimaryButton(
                      label: editing ? 'Salvar serviço' : 'Criar serviço',
                      isLoading: ctrl.salvando,
                      onPressed: ctrl.salvando
                          ? null
                          : () async {
                              final ok = editing
                                  ? await ctrl.atualizarServico(
                                      id: service['id'],
                                      nome: name.text.trim(),
                                      preco: double.tryParse(price.text
                                              .replaceAll(',', '.')) ??
                                          0,
                                      duracaoMin:
                                          int.tryParse(duration.text) ?? 30,
                                      descricao: description.text.trim().isEmpty
                                          ? null
                                          : description.text.trim(),
                                      categoriaId: selectedCategoryId)
                                  : await ctrl.criarServico(
                                      nome: name.text.trim(),
                                      preco:
                                          double.tryParse(price.text.replaceAll(',', '.')) ??
                                              0,
                                      duracaoMin:
                                          int.tryParse(duration.text) ?? 30,
                                      descricao: description.text.trim().isEmpty
                                          ? null
                                          : description.text.trim(),
                                      categoriaId: selectedCategoryId);
                              if (ok && modalContext.mounted)
                                Navigator.pop(modalContext);
                            }),
                ]))
      ],
    ).whenComplete(() {
      name.dispose();
      price.dispose();
      duration.dispose();
      description.dispose();
    });
  }

  Widget _option(String value, String label, int count, String group) {
    final active = (group == 'category' ? _categoryFilter : _status) == value;
    return InkWell(
        onTap: () => setState(() {
              if (group == 'category')
                _categoryFilter = value;
              else
                _status = value;
              _page = 1;
            }),
        child: Container(
            height: 36,
            padding: EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
                color: active
                    ? AppTheme.gold.withValues(alpha: .12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Icon(
                  active
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: active ? AppTheme.gold : AppTheme.corTextoSecundario),
              SizedBox(width: 9),
              Expanded(
                  child: Text(label,
                      style: GoogleFonts.inter(
                          color: active
                              ? AppTheme.corTexto
                              : AppTheme.corTextoSecundario,
                          fontSize: 12))),
              Text(count.toString(),
                  style: GoogleFonts.inter(
                      color:
                          active ? AppTheme.gold : AppTheme.corTextoSecundario,
                      fontSize: 11,
                      fontWeight: FontWeight.w700))
            ])));
  }

  Widget _chip(String label, String sort, IconData icon) {
    final active = _sort == sort;
    final disabled = sort == 'popular';
    return InkWell(
        onTap: disabled
            ? null
            : () => setState(() {
                  _sort = sort;
                  _page = 1;
                }),
        child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
                color: active
                    ? AppTheme.gold.withValues(alpha: .14)
                    : AppTheme.surfaceElev,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: active ? AppTheme.gold : AppTheme.border)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon,
                  size: 14,
                  color:
                      disabled ? AppTheme.corTextoSecundario : AppTheme.gold),
              SizedBox(width: 5),
              Text(label,
                  style: GoogleFonts.inter(
                      color: disabled
                          ? AppTheme.corTextoSecundario
                          : AppTheme.corTextoSecundario,
                      fontSize: 10))
            ])));
  }

  Widget _sidebar(List<Map<String, dynamic>> all, {bool scrollable = false}) {
    final cats = _categories(all);
    final active = all.where(_active).length;
    final content =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.filter_alt_outlined, color: AppTheme.gold, size: 20),
        SizedBox(width: 9),
        Expanded(
            child: Text('Filtros',
                style: GoogleFonts.inter(
                    color: AppTheme.corTexto,
                    fontSize: 16,
                    fontWeight: FontWeight.w700))),
        InkWell(
            onTap: _clear,
            child: Text('Limpar tudo',
                style: GoogleFonts.inter(
                    color: AppTheme.gold,
                    fontSize: 11,
                    decoration: TextDecoration.underline)))
      ]),
      Divider(color: AppTheme.border),
      SizedBox(height: 6),
      Text('Categoria',
          style: GoogleFonts.inter(
              color: AppTheme.corTexto,
              fontWeight: FontWeight.w700,
              fontSize: 13)),
      _option('all', 'Todas', all.length, 'category'),
      for (final c in cats)
        _option(c, c, all.where((s) => _serviceCategory(s) == c).length,
            'category'),
      Divider(color: AppTheme.border),
      SizedBox(height: 6),
      Text('Status',
          style: GoogleFonts.inter(
              color: AppTheme.corTexto,
              fontWeight: FontWeight.w700,
              fontSize: 13)),
      _option('all', 'Todos', all.length, 'status'),
      _option('active', 'Ativo', active, 'status'),
      _option('inactive', 'Inativo', all.length - active, 'status'),
      Divider(color: AppTheme.border),
      SizedBox(height: 6),
      Text('Filtros rápidos',
          style: GoogleFonts.inter(
              color: AppTheme.corTexto,
              fontWeight: FontWeight.w700,
              fontSize: 13)),
      SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 7, children: [
        _chip('Mais procurados', 'popular', Icons.star_border),
        _chip('Menor preço', 'price-asc', Icons.arrow_downward),
        _chip('Maior preço', 'price-desc', Icons.arrow_upward),
        _chip('Menor duração', 'duration-asc', Icons.schedule),
        _chip('Maior duração', 'duration-desc', Icons.schedule)
      ])
    ]);
    return Container(
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppTheme.surface,
            border: Border.all(color: AppTheme.border),
            borderRadius: BorderRadius.circular(10)),
        child: scrollable
            ? SingleChildScrollView(primary: false, child: content)
            : content);
  }

  Widget _searchBox() => Container(
      height: 42,
      decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border.all(color: AppTheme.border),
          borderRadius: BorderRadius.circular(8)),
      child: TextField(
          controller: _searchController,
          onChanged: (v) => setState(() {
                _search = v;
                _page = 1;
              }),
          decoration: InputDecoration(
              border: InputBorder.none,
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar serviços por nome...',
              suffixIcon: _search.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _search = '');
                      },
                      icon: Icon(Icons.close, size: 17)))));
  Widget _sorter() => Row(mainAxisSize: MainAxisSize.min, children: [
        Text('Ordenar por',
            style: GoogleFonts.inter(
                color: AppTheme.corTextoSecundario, fontSize: 12)),
        SizedBox(width: 8),
        DropdownButton<String>(
            value: _sort,
            dropdownColor: AppTheme.surfaceElev,
            underline: Container(height: 1, color: AppTheme.border),
            style: GoogleFonts.inter(color: AppTheme.corTexto, fontSize: 12),
            onChanged: (v) {
              if (v != null) setState(() => _sort = v);
            },
            items: const [
              DropdownMenuItem(value: 'name-asc', child: Text('Nome (A → Z)')),
              DropdownMenuItem(value: 'name-desc', child: Text('Nome (Z → A)')),
              DropdownMenuItem(value: 'price-asc', child: Text('Menor preço')),
              DropdownMenuItem(value: 'price-desc', child: Text('Maior preço')),
              DropdownMenuItem(
                  value: 'duration-asc', child: Text('Menor duração')),
              DropdownMenuItem(
                  value: 'duration-desc', child: Text('Maior duração'))
            ])
      ]);
  Widget _toggle(String value, IconData icon) => InkWell(
      onTap: () => setState(() => _view = value),
      child: Container(
          width: 40,
          height: 40,
          color: _view == value ? AppTheme.gold : Colors.transparent,
          child: Icon(icon,
              color: _view == value
                  ? AppTheme.blackPure
                  : AppTheme.corTextoSecundario,
              size: 19)));
  Widget _badge(Map<String, dynamic> s) {
    final ok = _active(s);
    final color = ok ? AppTheme.sucesso : AppTheme.corTextoSecundario;
    return Container(
        padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(16)),
        child: Text(ok ? '? ATIVO' : '? INATIVO',
            style: GoogleFonts.inter(
                color: color, fontSize: 10, fontWeight: FontWeight.w700)));
  }

  Widget _actions(BuildContext context, Map<String, dynamic> s) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
            onPressed: () => _form(context, service: s),
            icon: Icon(Icons.edit_outlined, size: 18),
            color: AppTheme.corTextoSecundario),
        PopupMenuButton<String>(
            color: AppTheme.surfaceElev,
            onSelected: (v) async {
              if (v == 'editar') _form(context, service: s);
              if (v == 'desativar')
                await context.read<AdminController>().desativarServico(s['id']);
            },
            itemBuilder: (_) => [
                  PopupMenuItem(value: 'editar', child: Text('Editar')),
                  PopupMenuItem(
                      value: 'desativar',
                      child: Text('Desativar',
                          style: TextStyle(color: AppTheme.corErro)))
                ],
            child: Icon(Icons.more_vert,
                size: 18, color: AppTheme.corTextoSecundario))
      ]);
  Widget _row(BuildContext context, Map<String, dynamic> s) => Container(
      height: 76,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.border))),
      child: Row(children: [
        Expanded(
            flex: 5,
            child: Row(children: [
              Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                      color: AppTheme.gold.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(8)),
                  child:
                      Icon(Icons.content_cut, color: AppTheme.gold, size: 20)),
              SizedBox(width: 14),
              Expanded(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text((s['nome'] ?? 'Serviço').toString(),
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            color: AppTheme.corTexto,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    Text((s['descricao'] ?? '').toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            color: AppTheme.corTextoSecundario, fontSize: 11))
                  ]))
            ])),
        Expanded(
            flex: 2,
            child: Text(_duration(s).toString() + ' min',
                style: GoogleFonts.inter(
                    color: AppTheme.corTextoSecundario, fontSize: 12))),
        Expanded(
            flex: 2,
            child: Text(_money(s['preco']),
                style: GoogleFonts.inter(
                    color: AppTheme.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w700))),
        Expanded(flex: 2, child: _badge(s)),
        SizedBox(width: 76, child: _actions(context, s))
      ]));
  Widget _main(BuildContext context, List<Map<String, dynamic>> visible,
          List<Map<String, dynamic>> result, int page, int pages) =>
      Container(
        decoration: BoxDecoration(
            color: AppTheme.surface.withValues(alpha: .58),
            border: Border.all(color: AppTheme.border),
            borderRadius: BorderRadius.circular(10)),
        child: Column(children: [
          Padding(
              padding: EdgeInsets.fromLTRB(16, 18, 16, 18),
              child: LayoutBuilder(builder: (context, constraints) {
                final narrow = constraints.maxWidth < 620;
                final viewToggle = Container(
                    decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.border),
                        borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      _toggle('list', Icons.view_list),
                      _toggle('grid', Icons.grid_view)
                    ]));
                if (narrow) {
                  return Column(children: [
                    Row(children: [
                      Expanded(child: _searchBox()),
                      SizedBox(width: 10),
                      viewToggle,
                    ]),
                    SizedBox(height: 12),
                    Align(alignment: Alignment.centerLeft, child: _sorter()),
                  ]);
                }
                return Row(children: [
                  Expanded(child: _searchBox()),
                  SizedBox(width: 14),
                  _sorter(),
                  SizedBox(width: 10),
                  viewToggle,
                ]);
              })),
          Expanded(
              child: _view == 'list'
                  ? Column(children: [
                      Container(
                          height: 47,
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          color: AppTheme.surfaceElev,
                          child: Row(children: [
                            Expanded(flex: 5, child: Text('SERVIÇO')),
                            Expanded(flex: 2, child: Text('DURAÇÃO')),
                            Expanded(flex: 2, child: Text('PREÇO')),
                            Expanded(flex: 2, child: Text('STATUS')),
                            SizedBox(width: 76, child: Text('AÇÕES'))
                          ])),
                      Expanded(
                          child: visible.isEmpty
                              ? const _EmptyState(
                                  icon: Icons.search_off,
                                  message: 'Nenhum serviço encontrado.')
                              : ListView.builder(
                                  itemCount: visible.length,
                                  itemBuilder: (context, index) =>
                                      _row(context, visible[index]))),
                    ])
                  : GridView.builder(
                      padding: EdgeInsets.all(14),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 2.1),
                      itemCount: visible.length,
                      itemBuilder: (context, index) =>
                          _grid(context, visible[index]))),
          SizedBox(
              height: 64,
              child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    Text('Mostrando ' +
                        visible.length.toString() +
                        ' de ' +
                        result.length.toString() +
                        ' serviços'),
                    Spacer(),
                    IconButton(
                        onPressed:
                            page > 1 ? () => setState(() => _page--) : null,
                        icon: Icon(Icons.chevron_left)),
                    Text(page.toString()),
                    IconButton(
                        onPressed:
                            page < pages ? () => setState(() => _page++) : null,
                        icon: Icon(Icons.chevron_right))
                  ]))),
        ]),
      );
  Widget _grid(BuildContext context, Map<String, dynamic> s) => Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border.all(color: AppTheme.border),
          borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text((s['nome'] ?? 'Serviço').toString(),
                  style: GoogleFonts.inter(
                      color: AppTheme.corTexto, fontWeight: FontWeight.w700))),
          _actions(context, s)
        ]),
        Spacer(),
        Text((s['descricao'] ?? '').toString(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
                color: AppTheme.corTextoSecundario, fontSize: 11)),
        SizedBox(height: 10),
        Row(children: [
          Text(_duration(s).toString() + ' min',
              style: GoogleFonts.inter(
                  color: AppTheme.corTextoSecundario, fontSize: 11)),
          Spacer(),
          Text(_money(s['preco']),
              style: GoogleFonts.inter(
                  color: AppTheme.gold,
                  fontWeight: FontWeight.w700,
                  fontSize: 12))
        ]),
        SizedBox(height: 8),
        _badge(s)
      ]));
  @override
  Widget build(BuildContext context) {
    context.watch<BarbeariaThemeService>();
    final ctrl = context.watch<AdminController>();
    final narrow = MediaQuery.sizeOf(context).width < 900;
    final all = ctrl.servicos;
    final result = _result(all);
    final pages = (result.length / _pageSize).ceil().clamp(1, 999);
    final page = _page.clamp(1, pages);
    final visible =
        result.skip((page - 1) * _pageSize).take(_pageSize).toList();
    return _TabShell(
        child: PremiumPageFrame(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      PremiumPageHeader(
        title: 'Serviços',
        subtitle: 'Gerencie os serviços oferecidos pela sua barbearia.',
        actions: [
          _PrimaryButton(
              label: '+ Novo serviço',
              icon: Icons.add,
              onPressed: () => _form(context)),
        ],
      ),
      SizedBox(height: 20),
      Expanded(
          child: ctrl.carregandoServicos
              ? Center(child: CircularProgressIndicator(color: AppTheme.gold))
              : narrow
                  ? SingleChildScrollView(
                      child: Column(children: [
                        _sidebar(all),
                        SizedBox(height: 16),
                        SizedBox(
                            height: 560,
                            child:
                                _main(context, visible, result, page, pages)),
                      ]),
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                          SizedBox(
                              width: 270,
                              child: _sidebar(all, scrollable: true)),
                          SizedBox(width: 16),
                          Expanded(
                              child:
                                  _main(context, visible, result, page, pages))
                        ]))
    ])));
  }
}

// ==========================================
// TAB: Gestão de Colaboradores
// RF14 - Gestão Multiusuário
// ==========================================
class _EquipeTab extends StatefulWidget {
  const _EquipeTab();
  @override
  State<_EquipeTab> createState() => _EquipeTabState();
}

class _EquipeTabState extends State<_EquipeTab> {
  bool _horariosAberto = false;

  @override
  Widget build(BuildContext context) => _horariosAberto
      ? HorariosScreen(onBack: () => setState(() => _horariosAberto = false))
      : _ColaboradoresTab(
          onHorarios: () => setState(() => _horariosAberto = true));
}

class _ColaboradoresTab extends StatelessWidget {
  final VoidCallback? onHorarios;

  const _ColaboradoresTab({this.onHorarios});

  Future<void> _mostrarEdicaoColaborador(
      BuildContext context, Map<String, dynamic> colaborador) async {
    final nomeCtrl = TextEditingController(text: colaborador['nome'] ?? '');
    final telefoneCtrl =
        TextEditingController(text: colaborador['telefone'] ?? '');
    final emailCtrl = TextEditingController(text: colaborador['email'] ?? '');
    final cpfCtrl = TextEditingController(text: colaborador['cpf'] ?? '');
    final formKey = GlobalKey<FormState>();
    var ativo =
        colaborador['ativo'] == 1 || colaborador['ativo'].toString() == '1';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surfaceElev,
          title: Text('Editar profissional',
              style: GoogleFonts.inter(
                  color: AppTheme.corTexto, fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 440,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(
                      controller: nomeCtrl,
                      decoration: InputDecoration(labelText: 'Nome completo'),
                      validator: (value) => (value ?? '').trim().length < 2
                          ? 'Informe o nome.'
                          : null),
                  SizedBox(height: 12),
                  TextFormField(
                      controller: telefoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(labelText: 'Telefone'),
                      validator: (value) => (value ?? '').trim().length < 8
                          ? 'Informe um telefone valido.'
                          : null),
                  SizedBox(height: 12),
                  TextFormField(
                      controller: cpfCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: 'CPF (opcional)'),
                      validator: (value) {
                        final cpf = (value ?? '').replaceAll(RegExp(r'\D'), '');
                        return cpf.isNotEmpty && cpf.length != 11
                            ? 'Informe um CPF valido.'
                            : null;
                      }),
                  SizedBox(height: 12),
                  TextFormField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration:
                          InputDecoration(labelText: 'E-mail (opcional)')),
                  SizedBox(height: 8),
                  SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Profissional ativo'),
                      subtitle: Text(ativo
                          ? 'Pode acessar o sistema e receber agendamentos.'
                          : 'Nao pode acessar o sistema nem receber novos agendamentos.'),
                      value: ativo,
                      onChanged: (value) =>
                          setDialogState(() => ativo = value)),
                ]),
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text('Cancelar')),
            FilledButton(
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                final controller = context.read<AdminController>();
                final sucesso = await controller.atualizarColaborador(
                    id: colaborador['id'],
                    nome: nomeCtrl.text.trim(),
                    telefone: telefoneCtrl.text.trim(),
                    email: emailCtrl.text.trim(),
                    cpf: cpfCtrl.text.trim(),
                    ativo: ativo);
                if (!dialogContext.mounted) return;
                if (sucesso) {
                  Navigator.pop(dialogContext);
                } else {
                  AppToast.show(context, controller.erro,
                      type: AppToastType.error);
                }
              },
              child: Text('Salvar alteracoes'),
            ),
          ],
        ),
      ),
    );
    nomeCtrl.dispose();
    telefoneCtrl.dispose();
    emailCtrl.dispose();
    cpfCtrl.dispose();
  }

  void _mostrarFormColaborador(BuildContext context) {
    final nomeCtrl = TextEditingController();
    final telefoneCtrl = TextEditingController();
    final cpfCtrl = TextEditingController();
    final senhaCtrl = TextEditingController();
    final loading = ValueNotifier<bool>(false);
    final erroMsg = ValueNotifier<String>('');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceElev,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => Padding(
        padding: MediaQuery.of(sheetCtx).viewInsets,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                    child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppTheme.border,
                      borderRadius: BorderRadius.circular(2)),
                )),
                SizedBox(height: 20),
                Text('Novo Colaborador',
                    style: GoogleFonts.inter(
                        color: AppTheme.corTexto,
                        fontSize: 20,
                        fontWeight: FontWeight.w700)),
                SizedBox(height: 20),
                TextField(
                    controller: nomeCtrl,
                    style: GoogleFonts.inter(color: AppTheme.corTexto),
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(labelText: 'Nome completo')),
                SizedBox(height: 12),
                TextField(
                    controller: telefoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: GoogleFonts.inter(color: AppTheme.corTexto),
                    decoration: InputDecoration(labelText: 'Telefone')),
                SizedBox(height: 12),
                TextField(
                  controller: cpfCtrl,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.inter(color: AppTheme.corTexto),
                  decoration: InputDecoration(labelText: 'CPF (opcional)'),
                ),
                SizedBox(height: 12),
                TextField(
                    controller: senhaCtrl,
                    obscureText: true,
                    style: GoogleFonts.inter(color: AppTheme.corTexto),
                    decoration: InputDecoration(labelText: 'Senha inicial')),
                SizedBox(height: 20),
                ValueListenableBuilder<String>(
                  valueListenable: erroMsg,
                  builder: (_, msg, __) => msg.isEmpty
                      ? SizedBox.shrink()
                      : Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text(msg,
                              style: GoogleFonts.inter(
                                  color: AppTheme.corErro, fontSize: 13))),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: loading,
                  builder: (_, isLoading, __) => Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed:
                            isLoading ? null : () => Navigator.pop(sheetCtx),
                        child: Text('Cancelar',
                            style: GoogleFonts.inter(
                                color: AppTheme.corTextoSecundario)),
                      ),
                      SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : () async {
                                if (nomeCtrl.text.trim().isEmpty ||
                                    telefoneCtrl.text.trim().isEmpty ||
                                    senhaCtrl.text.trim().isEmpty) {
                                  erroMsg.value = 'Preencha todos os campos.';
                                  return;
                                }
                                loading.value = true;
                                erroMsg.value = '';

                                final adminController =
                                    context.read<AdminController>();
                                final sucesso =
                                    await adminController.cadastrarColaborador(
                                  nome: nomeCtrl.text.trim(),
                                  telefone: telefoneCtrl.text.trim(),
                                  senha: senhaCtrl.text.trim(),
                                  cpf: cpfCtrl.text.trim(),
                                );

                                loading.value = false;

                                if (!sucesso) {
                                  erroMsg.value = adminController.erro;
                                } else {
                                  if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                                  if (context.mounted) {
                                    AppToast.show(
                                        context, 'Colaborador cadastrado!');
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          padding: EdgeInsets.symmetric(horizontal: 24),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: isLoading
                            ? SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                    color: AppTheme.corTexto, strokeWidth: 2))
                            : Text('Cadastrar'),
                      ),
                    ],
                  ),
                ),
              ]),
        ),
      ),
    );
  }

  Widget _buildColaboradorCard(BuildContext context, Map<String, dynamic> c) {
    final cor = Theme.of(context).colorScheme.primary;
    final ctrl = context.read<AdminController>();
    final nome = c['nome'] ?? '';
    final telefone = c['telefone'] ?? '';
    final roleRaw = (c['role'] ?? 'barbeiro').toString();
    final roleLabel =
        roleRaw.toUpperCase().contains('ADMIN') ? 'ADMIN' : 'BARBEIRO';

    return _HoverCard(
      child: Row(children: [
        CircleAvatar(
          radius: 23,
          backgroundColor: cor.withValues(alpha: 0.15),
          child: Text(nome.isNotEmpty ? nome[0].toUpperCase() : '?',
              style: GoogleFonts.inter(
                  color: cor, fontSize: 16, fontWeight: FontWeight.w700)),
        ),
        SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(nome,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                  color: AppTheme.corTexto,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          SizedBox(height: 3),
          Text(telefone,
              style: GoogleFonts.inter(
                  color: AppTheme.corTextoSecundario, fontSize: 13)),
        ])),
        SizedBox(width: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(roleLabel,
              style: GoogleFonts.inter(
                  color: AppTheme.corTextoSecundario,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
        ),
        SizedBox(width: 16),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: (c['ativo'] == 1 ? AppTheme.corSucesso : AppTheme.corErro)
                .withValues(alpha: .12),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(c['ativo'] == 1 ? 'ATIVO' : 'INATIVO',
              style: GoogleFonts.inter(
                  color:
                      c['ativo'] == 1 ? AppTheme.corSucesso : AppTheme.corErro,
                  fontSize: 10,
                  fontWeight: FontWeight.w700)),
        ),
        SizedBox(width: 12),
        SizedBox(width: 8),
        IconButton(
          tooltip: 'Editar profissional',
          onPressed: () => _mostrarEdicaoColaborador(context, c),
          icon: Icon(Icons.edit_outlined),
        ),
        IconButton(
          tooltip: 'Configurar horários',
          onPressed: onHorarios,
          icon: Icon(Icons.schedule_outlined),
        ),
        _CardMenuButton(
          items: [
            PopupMenuItem(
                value: 'excluir',
                child: Text('Excluir',
                    style: GoogleFonts.inter(color: AppTheme.corErro))),
          ],
          onSelected: (v) async {
            if (v == 'excluir') {
              final confirmar = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: AppTheme.surfaceElev,
                  title: Text('Excluir colaborador?',
                      style: GoogleFonts.inter(
                          color: AppTheme.corTexto,
                          fontSize: 18,
                          fontWeight: FontWeight.w600)),
                  content: Text('Tem certeza que deseja excluir $nome?',
                      style: GoogleFonts.inter(
                          color: AppTheme.corTextoSecundario, fontSize: 14)),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text('Cancelar',
                            style: GoogleFonts.inter(
                                color: AppTheme.corTextoSecundario))),
                    TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text('Excluir',
                            style: GoogleFonts.inter(
                                color: AppTheme.corErro,
                                fontWeight: FontWeight.w600))),
                  ],
                ),
              );
              if (confirmar == true) {
                await ctrl.removerColaborador(c['id']);
              }
            }
          },
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<BarbeariaThemeService>();
    final ctrl = context.watch<AdminController>();
    final cor = Theme.of(context).colorScheme.primary;

    return _TabShell(
      child: PremiumPageFrame(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          PremiumPageHeader(
            title: 'Equipe',
            subtitle: 'Gerencie os membros da sua equipe.',
            actions: [
              _PrimaryButton(
                label: '+ Adicionar membro',
                icon: Icons.person_add,
                onPressed: () => _mostrarFormColaborador(context),
              ),
            ],
          ),
          SizedBox(height: 28),
          Expanded(
            child: ctrl.carregandoColaboradores
                ? Center(child: CircularProgressIndicator(color: cor))
                : ctrl.erroColaboradores.isNotEmpty
                    ? _EmptyState(
                        icon: Icons.cloud_off_outlined,
                        message:
                            'Não foi possível carregar a equipe: ${ctrl.erroColaboradores}')
                    : ctrl.colaboradores.isEmpty
                        ? const _EmptyState(
                            icon: Icons.group_outlined,
                            message: 'Nenhum colaborador cadastrado.')
                        : ListView.builder(
                            padding: EdgeInsets.only(bottom: 8),
                            itemCount: ctrl.colaboradores.length,
                            itemBuilder: (context, i) => _buildColaboradorCard(
                                context, ctrl.colaboradores[i]),
                          ),
          ),
        ]),
      ),
    );
  }
}

// ==========================================
// SHELL: Fundo com brilho radial + SafeArea
// ==========================================
class _TabShell extends StatelessWidget {
  final Widget child;
  const _TabShell({required this.child});

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.primary;
    return Container(
      color: AppTheme.black,
      child: Stack(children: [
        Positioned(
          top: -160,
          right: -140,
          child: _Glow(size: 480, cor: cor),
        ),
        Positioned(
          bottom: -180,
          left: -160,
          child: _Glow(size: 460, cor: cor, opacity: 0.04),
        ),
        Positioned.fill(child: SafeArea(child: child)),
      ]),
    );
  }
}

class _Glow extends StatelessWidget {
  final double size;
  final Color cor;
  final double opacity;
  const _Glow({required this.size, required this.cor, this.opacity = 0.05});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [cor.withValues(alpha: opacity), cor.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

// ==========================================
// BUTTON: Botão primário com hover
// ==========================================
class _PrimaryButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  const _PrimaryButton(
      {required this.label, required this.icon, required this.onPressed});

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.primary;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hover ? -1 : 0, 0),
        decoration: BoxDecoration(
          color: cor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: _hover
              ? [
                  BoxShadow(
                      color: cor.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8))
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: widget.onPressed,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(widget.icon, color: AppTheme.corTexto, size: 18),
                SizedBox(width: 8),
                Text(widget.label,
                    style: GoogleFonts.inter(
                        color: AppTheme.corTexto,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// CARD: Cartão elevável com hover
// ==========================================
class _HoverCard extends StatefulWidget {
  final Widget child;
  const _HoverCard({required this.child});

  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.primary;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
        margin: EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: AppTheme.surfaceElev,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: _hover ? cor.withValues(alpha: 0.2) : Colors.transparent),
          boxShadow: _hover
              ? [
                  BoxShadow(
                      color: cor.withValues(alpha: 0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 8))
                ]
              : null,
        ),
        child: widget.child,
      ),
    );
  }
}

// ==========================================
// MENU: Botão de três pontos com hover
// ==========================================
class _CardMenuButton extends StatefulWidget {
  final List<PopupMenuEntry<String>> items;
  final ValueChanged<String> onSelected;
  const _CardMenuButton({required this.items, required this.onSelected});

  @override
  State<_CardMenuButton> createState() => _CardMenuButtonState();
}

class _CardMenuButtonState extends State<_CardMenuButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _hover ? AppTheme.surfaceElev : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: PopupMenuButton<String>(
          color: AppTheme.surfaceElev,
          icon: Icon(Icons.more_vert,
              color: AppTheme.corTextoSecundario, size: 20),
          padding: EdgeInsets.zero,
          iconSize: 20,
          onSelected: widget.onSelected,
          itemBuilder: (_) => widget.items,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

// ==========================================
// EMPTY STATE: Nenhum registro
// ==========================================
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.primary;
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: cor.withValues(alpha: 0.3), size: 48),
        SizedBox(height: 16),
        Text(message,
            style: GoogleFonts.inter(
                color: AppTheme.corTextoSecundario, fontSize: 14)),
      ]),
    );
  }
}
