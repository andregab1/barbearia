import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:getcutt/features/admin/screens/service_receipt_pdf_svg.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('gera PDF A4 para atendimento pendente com dados longos', () async {
    final bytes = await ServiceReceiptPdf.build(
      appointment: {
        'appointment_id': 482,
        'service_date': '2026-09-28T10:00:00.000Z',
        'total_amount': '1250.90',
        'paid_amount': '0',
        'outstanding_amount': '1250.90',
        'client': 'Cliente com nome suficientemente longo para testar o ajuste',
        'client_phone': '(41) 99999-0000',
        'professional': 'Profissional com nome extenso para testar o layout',
        'service':
            'Serviço de tratamento e acabamento premium com descrição longa',
        'service_description':
            'Descrição detalhada do serviço realizado no atendimento.',
        'observation': 'Atendimento concluído sem pagamento registrado.',
        'status': 'open',
      },
      barbershop: {
        'name': 'Barbearia GetCutt Centro',
        'address': 'Rua Principal, 123 · Centro · Araucária / PR',
      },
    );

    expect(bytes.length, greaterThan(1000));
    expect(utf8.decode(bytes.take(4).toList()), '%PDF');
  });

  test('gera PDF para atendimento pago com desconto e forma de pagamento',
      () async {
    final bytes = await ServiceReceiptPdf.build(
      appointment: {
        'appointment_id': 128,
        'service_date': '2026-09-28T10:00:00.000Z',
        'total_amount': '90.00',
        'subtotal_amount': '100.00',
        'discount_amount': '10.00',
        'paid_amount': '90.00',
        'outstanding_amount': '0',
        'payment_methods': 'pix',
        'paid_at': '2026-09-28T10:43:00.000Z',
        'client': 'João da Silva',
        'professional': 'Lucas',
        'service': 'Corte masculino',
        'status': 'paid',
      },
    );

    expect(bytes.length, greaterThan(1000));
    expect(utf8.decode(bytes.take(4).toList()), '%PDF');
  });
}
