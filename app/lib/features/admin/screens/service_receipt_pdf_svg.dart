import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'report_download_stub.dart'
    if (dart.library.html) 'report_download_web.dart';

class ServiceReceiptPdf {
  static const _averageGlyphWidth = 0.6;

  static Future<Uint8List> build({
    required Map<String, dynamic> appointment,
    Map<String, dynamic>? barbershop,
    String? accentHex,
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
          svg: _fillTemplate(template, receipt, accentHex: accentHex),
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

  static String _fillTemplate(
    String source,
    _ReceiptData data, {
    String? accentHex,
  }) {
    final accent = _normalizeHex(accentHex) ?? 'F4D000';
    final accentDark = _darkenHex(accent);
    var svg = source
        .replaceAll('#f4d000', '#$accent')
        .replaceAll('#b88a00', '#$accentDark');
    svg = _replaceField(svg, 'field-receipt-number',
        _fitText('N\u00ba ${data.receiptNumber}', width: 160, fontSize: 11));
    svg = _replaceField(svg, 'field-verification', _fitText(
        'NFS-GETCUTT-${data.receiptNumber}',
        width: 160,
        fontSize: 8));
    svg = _replaceField(svg, 'field-barbershop-name',
        _fitText(data.barbershopName, width: 296, fontSize: 12));
    svg = _replaceField(svg, 'field-barbershop-address',
        _fitText(data.barbershopAddress, width: 296, fontSize: 10));
    svg = _replaceField(svg, 'field-issued-at', _fitText(data.issuedAt,
        width: 170, fontSize: 10, x: 786));
    svg = _replaceField(svg, 'field-client-name',
        _fitText(data.clientName, width: 360, fontSize: 11));
    svg = _replaceField(svg, 'field-client-phone',
        _fitText('Telefone: ${data.clientPhone}', width: 330, fontSize: 10));
    svg = _replaceField(svg, 'field-appointment-date',
        _fitText(data.appointmentDate, width: 200, fontSize: 10, x: 778));
    svg = _replaceField(
        svg,
        'field-professional',
        _fitText(
          'Profissional: ${data.professional} \u00b7 Agendamento #${data.appointmentId}',
          width: 540,
          fontSize: 10,
        ));
    svg = _replaceField(
        svg,
        'field-service-count',
        _fitText(
          data.serviceCount == 1
              ? '1 servico'
              : '${data.serviceCount} servicos',
          width: 70,
          fontSize: 8,
          x: 784,
        ));

    for (var index = 0; index < 3; index++) {
      final row = index < data.serviceRows.length
          ? data.serviceRows[index]
          : const _ServiceRow.empty();
      final suffix = index + 1;
      svg = _replaceField(svg, 'field-service-name-$suffix',
          _fitText(row.name, width: 410, fontSize: 11));
      svg = _replaceField(svg, 'field-service-description-$suffix',
          _fitText(row.description, width: 410, fontSize: 9, minFontSize: 6.5));
      svg = _replaceField(svg, 'field-service-qty-$suffix',
          _fitText(row.quantity, width: 60, fontSize: 10));
      svg = _replaceField(svg, 'field-service-unit-$suffix',
          _fitText(_money(row.unit), width: 125, fontSize: 10, x: 638));
      svg = _replaceField(svg, 'field-service-total-$suffix',
          _fitText(_money(row.total), width: 125, fontSize: 10, x: 776));
    }

    svg = _replaceField(svg, 'field-attendance',
        _fitText('Atendimento em ${data.appointmentDate}', width: 360, fontSize: 8));
    svg = _replaceField(svg, 'field-payment-status',
        _fitText('Pagamento: ${data.statusLabel}', width: 190, fontSize: 9));
    svg = _replaceField(
        svg,
        'field-payment-method',
        _fitText('${data.paymentMethod} \u00b7 ${_money(data.paidAmount)}',
            width: 225, fontSize: 9));
    svg = _replaceField(
        svg,
        'field-payment-date',
        _fitText(
          data.paymentDate.isEmpty
              ? 'Pagamento ainda nao registrado'
              : 'Recebido em ${data.paymentDate}',
          width: 280,
          fontSize: 9,
        ));
    svg = _replaceField(svg, 'field-balance',
        _fitText('Saldo pendente: ${_money(data.outstandingAmount)}',
            width: 240, fontSize: 9));
    svg = _replaceField(svg, 'field-subtotal',
        _fitText(_money(data.subtotal), width: 220, fontSize: 12));
    svg = _replaceField(svg, 'field-discount-label',
        _fitText('DESCONTO${data.discountLabel}', width: 220, fontSize: 8));
    svg = _replaceField(svg, 'field-discount',
        _fitText(_money(data.discount), width: 220, fontSize: 12));
    svg = _replaceField(svg, 'field-total',
        _fitText(_money(data.totalAmount), width: 220, fontSize: 13, x: 784));
    svg = _replaceField(
        svg,
        'field-observation',
        _fitTextLines(data.observation, x: 52, y: 888, width: 720, fontSize: 9));
    svg = _replaceField(svg, 'field-control-number',
        _fitText('CONTROLE INTERNO \u00b7 N\u00ba ${data.receiptNumber}',
            width: 240, fontSize: 8));
    return svg;
  }

  static String _replaceField(String source, String id, String content) {
    final pattern = RegExp(
      '(<text id="${RegExp.escape(id)}"[^>]*>).*?(</text>)',
      dotAll: true,
    );
    if (!pattern.hasMatch(source)) {
      throw StateError('Campo do modelo SVG nao encontrado: $id');
    }
    return source.replaceFirstMapped(
        pattern, (match) => '${match.group(1)}$content${match.group(2)}');
  }

  static String _fitText(
    String value, {
    required double width,
    required double fontSize,
    double? x,
    double minFontSize = 5.5,
  }) {
    final normalized = _normalize(value);
    if (normalized.isEmpty) return '';
    final estimatedWidth = normalized.length * fontSize * _averageGlyphWidth;
    final fittedSize = estimatedWidth <= width
        ? fontSize
        : (fontSize * width / estimatedWidth).clamp(minFontSize, fontSize);
    final xAttribute = x == null ? '' : ' x="${_svgNumber(x)}"';
    return '<tspan$xAttribute font-size="${_svgNumber(fittedSize)}">${_xml(normalized)}</tspan>';
  }

  static String _fitTextLines(
    String value, {
    required double x,
    required double y,
    required double width,
    required double fontSize,
    double lineHeight = 13,
    int maxLines = 3,
  }) {
    final normalized = _normalize(value);
    if (normalized.isEmpty) return '';
    final maxChars = max(1, (width / (fontSize * _averageGlyphWidth)).floor());
    final words = normalized.split(' ');
    final lines = <String>[];
    var current = '';
    for (final word in words) {
      final candidate = current.isEmpty ? word : '$current $word';
      if (current.isNotEmpty && candidate.length > maxChars) {
        lines.add(current);
        current = word;
      } else {
        current = candidate;
      }
    }
    if (current.isNotEmpty) lines.add(current);
    if (lines.length > maxLines) {
      final charsPerLine = (normalized.length / maxLines).ceil();
      lines
        ..clear()
        ..addAll(List.generate(
          maxLines,
          (index) {
            final start = index * charsPerLine;
            final end = min(start + charsPerLine, normalized.length);
            return normalized.substring(start, end).trim();
          },
        ));
    }
    final longestLine = lines.fold<int>(0,
        (longest, line) => line.length > longest ? line.length : longest);
    final estimatedWidth = longestLine * fontSize * _averageGlyphWidth;
    final fittedSize = estimatedWidth <= width
        ? fontSize
        : (fontSize * width / estimatedWidth).clamp(5.5, fontSize);
    final spans = <String>[];
    for (var index = 0; index < lines.length; index++) {
      spans.add(
          '<tspan x="${_svgNumber(x)}" y="${_svgNumber(y + index * lineHeight)}" font-size="${_svgNumber(fittedSize)}">${_xml(lines[index])}</tspan>');
    }
    return spans.join();
  }

  static String _normalize(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim();

  static String _svgNumber(num value) => value.toStringAsFixed(2);

  static String _xml(String value) =>
      const HtmlEscape(HtmlEscapeMode.element).convert(value);

  static String? _normalizeHex(String? value) {
    if (value == null) return null;
    final normalized = value.replaceAll('#', '').trim().toUpperCase();
    return RegExp(r'^[0-9A-F]{6}$').hasMatch(normalized) ? normalized : null;
  }

  static String _darkenHex(String hex) {
    final color = int.parse(hex, radix: 16);
    final red = ((color >> 16) & 0xFF) * .72;
    final green = ((color >> 8) & 0xFF) * .72;
    final blue = (color & 0xFF) * .72;
    final dark = (red.round() << 16) | (green.round() << 8) | blue.round();
    return dark.toRadixString(16).padLeft(6, '0').toUpperCase();
  }

  static String _money(double value) {
    final amount = NumberFormat.currency(locale: 'pt_BR', symbol: '')
        .format(value)
        .trim();
    return 'R\$ $amount';
  }
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
