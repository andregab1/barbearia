import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:getcutt/features/agendamento/controllers/agendamento_controller.dart';
import 'package:getcutt/features/agendamento/screens/assistente_agendamento_screen.dart';

class FakeAppointments extends AgendamentoController {
  int refreshes = 0;
  @override
  Map<String, dynamic>? get barbeariaSelecionada =>
      {'id': 1, 'nome': 'Barbearia Teste'};
  @override
  List<Map<String, dynamic>> get barbearias => [barbeariaSelecionada!];
  @override
  Future<void> carregarMeusAgendamentos() async {
    refreshes++;
  }
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  testWidgets('proposal requires explicit confirmation and refreshes agenda',
      (tester) async {
    final appointments = FakeAppointments();
    int confirmations = 0;
    await tester.pumpWidget(ChangeNotifierProvider<AgendamentoController>.value(
        value: appointments,
        child: MaterialApp(home: Scaffold(body: AssistenteAgendamentoScreen(
          request: (path, body) async {
            if (path.endsWith('confirmar')) {
              confirmations++;
              return {'id': 99};
            }
            return {
              'status': 'proposal',
              'message': 'Confira os dados',
              'proposal_token': 'signed',
              'proposal': {
                'services': [
                  {'nome': 'Corte + barba'}
                ],
                'professional': 'André',
                'date': '2099-01-02',
                'time': '15:00',
                'duration_min': 60,
                'total': 90,
              }
            };
          },
        )))));
    await tester.enterText(find.byType(TextField), 'corte e barba amanhã');
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();
    expect(confirmations, 0);
    expect(find.text('Editar pedido'), findsOneWidget);
    await tester.ensureVisible(find.text('Confirmar agendamento'));
    await tester.tap(find.text('Confirmar agendamento'));
    await tester.pumpAndSettle();
    expect(confirmations, 1);
    expect(appointments.refreshes, 1);
    expect(find.textContaining('seu horário foi confirmado'), findsOneWidget);
  });
}
