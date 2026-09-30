import 'dart:convert';
import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'report_download_stub.dart'
    if (dart.library.html) 'report_download_web.dart';

class ServiceReceiptPdf {
  static Future<Uint8List> build({
    required Map<String, dynamic> appointment,
    Map<String, dynamic>? barbershop,
  }) async {
    final template = utf8
        .decode(await loadReportAsset('assets/Nota_de_servicos_GetCutt.svg'));
    final regularFont = pw.Font.ttf(ByteData.sublistView(
        await loadReportAsset('assets/fonts/Inter-Regular.ttf')));
    final boldFont = pw.Font.ttf(ByteData.sublistView(
        await loadReportAsset('assets/fonts/Inter-Bold.ttf')));
    final receipt = _ReceiptData.fromMaps(appointment, barbershop);
    final document = pw.Document(title: 'Comprovante de serviços GetCutt');

    document.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (_) => pw.SizedBox(
        width: PdfPageFormat.a4.width,
        height: PdfPageFormat.a4.height,
        child: pw.SvgImage(
          svg: _fillTemplate(template, receipt),
          width: PdfPageFormat.a4.width,
          height: PdfPageFormat.a4.height,
          fit: pw.BoxFit.fill,
          alignment: pw.Alignment.topLeft,
          customFontLookup: (_, __, fontWeight) =>
              fontWeight == 'bold' || fontWeight == '700'
                  ? boldFont
                  : regularFont,
        ),
      ),
    ));
    return document.save();
  }

  static String _fillTemplate(String source, _ReceiptData data) {
    var svg = source;
    svg = _replaceText(svg, 'Nº 000128', 'Nº ${data.receiptNumber}');
    svg = _replaceText(svg, 'Barbearia Exemplo', data.barbershopName);
    svg = _replaceText(svg, 'Rua Exemplo, 123 · Centro · Araucária / PR',
        data.barbershopAddress);
    svg = _replaceRaw(
        svg,
        '<text x="792" y="155" text-anchor="end" class="body" style="fill:#fff">28/09/2026 · 10:45</text>',
        '<text x="792" y="155" text-anchor="end" class="body" style="fill:#fff">${_xml(data.issuedAt)}</text>');
    svg = _replaceText(svg, 'Modelo demonstrativo · Dados fictícios',
        'Documento emitido pelo sistema');
    svg = _replaceText(svg, 'João da Silva', data.clientName);
    svg = _replaceText(
        svg, 'Telefone: (00) 00000-0000', 'Telefone: ${data.clientPhone}');
    svg = _replaceRaw(
        svg,
        '<text x="471" y="315" class="body bold">28/09/2026 · 10:00</text>',
        '<text x="471" y="315" class="body bold">${_xml(data.appointmentDate)}</text>');
    svg = _replaceText(svg, 'Profissional: Lucas · Agendamento #00482',
        'Profissional: ${data.professional} · Agendamento #${data.appointmentId}');
    svg = _replaceText(svg, '3 serviços',
        data.serviceCount == 1 ? '1 serviço' : '${data.serviceCount} serviços');

    final rowY = [506, 578, 650];
    final rowNames = ['Corte masculino', 'Barba completa', 'Sobrancelha'];
    final rowDescriptions = [
      'Degradê + acabamento',
      'Modelagem + finalização',
      'Acabamento com navalha',
    ];
    for (var index = 0; index < rowY.length; index++) {
      final row = index < data.serviceRows.length
          ? data.serviceRows[index]
          : const _ServiceRow.empty();
      svg = _replaceText(svg, rowNames[index], row.name);
      svg = _replaceText(svg, rowDescriptions[index], row.description);
      svg = _replaceRaw(
          svg,
          '<text x="493" y="${rowY[index]}" text-anchor="middle" class="body num">1</text>',
          '<text x="493" y="${rowY[index]}" text-anchor="middle" class="body num">${_xml(row.quantity)}</text>');
      svg = _replaceRaw(
          svg,
          '<text x="638" y="${rowY[index]}" text-anchor="end" class="body num">${_templateUnit(index)}</text>',
          '<text x="638" y="${rowY[index]}" text-anchor="end" class="body num">${_xml(_money(row.unit))}</text>');
      svg = _replaceRaw(
          svg,
          '<text x="776" y="${rowY[index]}" text-anchor="end" class="body bold num">${_templateTotal(index)}</text>',
          '<text x="776" y="${rowY[index]}" text-anchor="end" class="body bold num">${_xml(_money(row.total))}</text>');
    }

    svg = _replaceText(svg, 'Pago', data.statusLabel);
    svg = _replaceText(svg, r'Pix · R$ 90,00',
        '${data.paymentMethod} · ${_money(data.paidAmount)}');
    svg = _replaceText(
        svg,
        'Recebido em 28/09/2026 às 10:43',
        data.paymentDate.isEmpty
            ? 'Pagamento ainda não registrado'
            : 'Recebido em ${data.paymentDate}');
    svg = _replaceText(svg, r'Saldo pendente: R$ 0,00',
        'Saldo pendente: ${_money(data.outstandingAmount)}');
    svg = _replaceText(svg, r'R$ 100,00', _money(data.subtotal));
    svg = _replaceText(svg, 'Desconto (10%)', 'Desconto${data.discountLabel}');
    svg = _replaceText(svg, r'− R$ 10,00', '− ${_money(data.discount)}');
    svg = _replaceText(svg, r'R$ 90,00', _money(data.totalAmount));
    svg = _replaceText(
        svg,
        'Serviços concluídos. Desconto aplicado sobre o subtotal do atendimento.',
        data.observation);
    svg = _replaceText(svg, 'CONTROLE INTERNO · Nº 000128',
        'CONTROLE INTERNO · Nº ${data.receiptNumber}');
    return svg;
  }

  static String _templateUnit(int index) =>
      const [r'R$ 50,00', r'R$ 35,00', r'R$ 15,00'][index];
  static String _templateTotal(int index) =>
      const [r'R$ 50,00', r'R$ 35,00', r'R$ 15,00'][index];

  static String _replaceText(String source, String from, String to) {
    final marker = '>$from</text>';
    return _replaceRaw(source, marker, '>${_xml(to)}</text>');
  }

  static String _replaceRaw(String source, String from, String to) {
    if (!source.contains(from)) {
      throw StateError('Campo do modelo SVG não encontrado: $from');
    }
    return source.replaceFirst(from, to);
  }

  static String _xml(String value) =>
      const HtmlEscape(HtmlEscapeMode.element).convert(value);

  static String _money(double value) =>
      NumberFormat.currency(locale: 'pt_BR', symbol: r'R$').format(value);
}

class _ReceiptData {
  final String receiptNumber;
  final String barbershopName;
  final String barbershopAddress;
  final String issuedAt;
  final String clientName;
  final String clientPhone;
  final String appointmentDate;
  final String professional;
  final String appointmentId;
  final String paymentMethod;
  final String paymentDate;
  final String statusLabel;
  final String observation;
  final String discountLabel;
  final double subtotal;
  final double discount;
  final double totalAmount;
  final double paidAmount;
  final double outstandingAmount;
  final int serviceCount;
  final List<_ServiceRow> serviceRows;

  const _ReceiptData({
    required this.receiptNumber,
    required this.barbershopName,
    required this.barbershopAddress,
    required this.issuedAt,
    required this.clientName,
    required this.clientPhone,
    required this.appointmentDate,
    required this.professional,
    required this.appointmentId,
    required this.paymentMethod,
    required this.paymentDate,
    required this.statusLabel,
    required this.observation,
    required this.discountLabel,
    required this.subtotal,
    required this.discount,
    required this.totalAmount,
    required this.paidAmount,
    required this.outstandingAmount,
    required this.serviceCount,
    required this.serviceRows,
  });

  factory _ReceiptData.fromMaps(
      Map<String, dynamic> appointment, Map<String, dynamic>? barbershop) {
    final total =
        _number(appointment['total_amount'] ?? appointment['valor_cobrado']);
    final paid = _number(appointment['paid_amount']);
    final outstanding = _number(appointment['outstanding_amount'],
        fallback: (total - paid).clamp(0, double.infinity));
    final discount =
        _number(appointment['discount_amount'] ?? appointment['desconto']);
    final subtotal = _number(
        appointment['subtotal_amount'] ?? appointment['subtotal'],
        fallback: total + discount);
    final status = appointment['status']?.toString().toLowerCase();
    final serviceRows = _serviceRows(appointment, total, subtotal);
    final discountPercentage =
        subtotal <= 0 ? 0 : (discount / subtotal * 100).round();

    return _ReceiptData(
      receiptNumber:
          (appointment['receipt_number']?.toString().trim().isNotEmpty ?? false)
              ? appointment['receipt_number'].toString()
              : _padded(appointment['appointment_id'] ?? appointment['id']),
      barbershopName: _value(
          barbershop?['name'] ?? appointment['barbearia_name'],
          'Barbearia GetCutt'),
      barbershopAddress: _value(
          barbershop?['address'] ?? appointment['barbearia_address'],
          'Endereço não informado'),
      issuedAt: _date(DateTime.now()),
      clientName: _value(appointment['client'] ?? appointment['client_name'],
          'Cliente não informado'),
      clientPhone: _value(
          appointment['client_phone'] ?? appointment['telefone'],
          'Não informado'),
      appointmentDate:
          _date(appointment['service_date'] ?? appointment['data_hora']),
      professional: _value(
          appointment['professional'] ?? appointment['professional_name'],
          'Profissional não informado'),
      appointmentId:
          _value(appointment['appointment_id'] ?? appointment['id'], '—'),
      paymentMethod: _paymentMethod(
          appointment['payment_method'] ?? appointment['payment_methods']),
      paymentDate: _date(appointment['paid_at'] ?? appointment['pago_em'],
          withTime: true),
      statusLabel: outstanding <= 0.005 || status == 'paid'
          ? 'Pago'
          : (paid > 0 ? 'Parcial' : 'Pendente'),
      observation: _value(
          appointment['observation'] ?? appointment['observacao'],
          'Serviços concluídos. Desconto aplicado sobre o subtotal do atendimento.'),
      discountLabel: discountPercentage > 0 ? ' ($discountPercentage%)' : '',
      subtotal: subtotal,
      discount: discount,
      totalAmount: total,
      paidAmount: paid,
      outstandingAmount: outstanding,
      serviceCount: int.tryParse('${appointment['service_count'] ?? 1}') ?? 1,
      serviceRows: serviceRows,
    );
  }

  static List<_ServiceRow> _serviceRows(
      Map<String, dynamic> appointment, double total, double subtotal) {
    final raw = appointment['services'];
    if (raw is List && raw.isNotEmpty) {
      return raw.take(3).map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        final quantity =
            _number(map['quantity'] ?? map['quantidade'], fallback: 1);
        final unit =
            _number(map['unit_amount'] ?? map['preco'] ?? map['price']);
        final lineTotal = _number(map['total_amount'] ?? map['total'],
            fallback: unit * quantity);
        return _ServiceRow(
          name: _value(map['name'] ?? map['service'], ''),
          description: _value(map['description'] ?? map['descricao'], ''),
          quantity: quantity == quantity.roundToDouble()
              ? '${quantity.toInt()}'
              : quantity.toString(),
          unit: unit,
          total: lineTotal,
        );
      }).toList();
    }
    return [
      _ServiceRow(
        name: _value(appointment['service'] ?? appointment['service_name'],
            'Serviço não informado'),
        description: _value(
            appointment['service_description'] ??
                appointment['descricao_servico'],
            'Serviço realizado'),
        quantity: '1',
        unit: subtotal,
        total: total,
      ),
    ];
  }

  static String _value(dynamic value, String fallback) {
    final result = value?.toString().trim() ?? '';
    return result.isEmpty || result == 'null' ? fallback : result;
  }

  static double _number(dynamic value, {double fallback = 0}) =>
      double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? fallback;

  static String _padded(dynamic value) =>
      (int.tryParse(value?.toString() ?? '') ?? 0).toString().padLeft(6, '0');

  static String _date(dynamic value, {bool withTime = false}) {
    final parsed =
        value is DateTime ? value : DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return '';
    return DateFormat(withTime ? 'dd/MM/yyyy às HH:mm' : 'dd/MM/yyyy · HH:mm')
        .format(parsed.toLocal());
  }

  static String _paymentMethod(dynamic value) {
    final key = value?.toString().trim() ?? '';
    const labels = {
      'pix': 'Pix',
      'credit_card': 'Cartão de crédito',
      'debit_card': 'Cartão de débito',
      'cash': 'Dinheiro',
      'other': 'Outro',
    };
    return key.isEmpty
        ? 'Pagamento pendente'
        : key
            .split(',')
            .map((item) => labels[item.trim()] ?? item.trim())
            .join(', ');
  }
}

class _ServiceRow {
  final String name;
  final String description;
  final String quantity;
  final double unit;
  final double total;

  const _ServiceRow({
    required this.name,
    required this.description,
    required this.quantity,
    required this.unit,
    required this.total,
  });

  const _ServiceRow.empty()
      : name = '',
        description = '',
        quantity = '',
        unit = 0,
        total = 0;
}
