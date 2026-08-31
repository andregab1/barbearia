import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:getcutt/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const onlyLogin = bool.fromEnvironment('E2E_ONLY_LOGIN');
  const buttonAudit = bool.fromEnvironment('E2E_BUTTON_AUDIT');
  const appointmentFlow = bool.fromEnvironment('E2E_APPOINTMENT_FLOW');

  Future<void> waitFor(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isNotEmpty) return;
    }
    final visibleTexts = find
        .byType(Text)
        .evaluate()
        .map((element) => (element.widget as Text).data)
        .whereType<String>()
        .toList();
    throw TestFailure(
      'Timed out waiting for ${finder.runtimeType}; visible texts: $visibleTexts',
    );
  }

  Future<void> launchAt(WidgetTester tester, Size logicalSize) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.clear();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = logicalSize;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    app.main();
    await tester.pump();
    await waitFor(tester, find.text('GESTÃO INTELIGENTE PARA BARBEARIAS'));
  }

  Future<void> submitLogin(WidgetTester tester,
      {required String identifier, required String expectedHomeText}) async {
    await tester.tap(find.text('Entrar').first);
    await waitFor(tester, find.text('Bem-vindo de volta'));
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), identifier);
    await tester.enterText(fields.at(1), 'QaSenha123!');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Entrar'));
    await waitFor(tester, find.text(expectedHomeText));
    expect(tester.takeException(), isNull);
  }

  Future<void> login(WidgetTester tester,
      {required String identifier, required String expectedHomeText}) async {
    await launchAt(tester, const Size(1440, 900));
    await submitLogin(
      tester,
      identifier: identifier,
      expectedHomeText: expectedHomeText,
    );
  }

  Future<void> logoutFromProfile(WidgetTester tester) async {
    await tester.tap(find.text('Perfil').first);
    await waitFor(tester, find.text('Meu perfil'));
    await tester.tap(find.text('Sair da conta'));
    await waitFor(tester, find.text('Entrar'));
    expect(tester.takeException(), isNull);
  }

  Future<void> verifyNavigation(WidgetTester tester, String buttonLabel,
      String expectedScreenText, List<String> failures) async {
    final button = find.text(buttonLabel).first;
    expect(button, findsOneWidget, reason: 'Botao $buttonLabel nao renderizado');
    await tester.tap(button);
    await waitFor(tester, find.text(expectedScreenText));
    expect(find.text(expectedScreenText), findsWidgets,
        reason: 'Botao $buttonLabel nao abriu $expectedScreenText');
    final exception = tester.takeException();
    if (exception != null) {
      failures.add('$buttonLabel -> $expectedScreenText: $exception');
    }
  }

  group('Catálogo GetCutt - interface real', () {
    if (!onlyLogin && !buttonAudit && !appointmentFlow) {
      for (final viewport in const <Size>[
        Size(390, 844),
        Size(768, 1024),
        Size(1440, 900),
      ]) {
        testWidgets('AI-RESP-01/AI-LAND-01 landing em ${viewport.width.toInt()}x${viewport.height.toInt()}', (tester) async {
          await launchAt(tester, viewport);
          expect(find.text('GetCutt'), findsWidgets);
          expect(find.text('Sua barbearia,\ndo seu jeito.'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }

    if (!buttonAudit && !appointmentFlow) {
      testWidgets('QA-E2E-050 login inválido mantém a interface recuperável', (tester) async {
      await launchAt(tester, const Size(1440, 900));
      await tester.tap(find.text('Entrar').first);
      await waitFor(tester, find.text('Bem-vindo de volta'));
      expect(find.text('Bem-vindo de volta'), findsOneWidget);

      final fields = find.byType(TextFormField);
      expect(fields, findsNWidgets(2));
      await tester.enterText(fields.at(0), 'qa-invalid@getcutt.test');
      await tester.enterText(fields.at(1), 'senha-incorreta');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Entrar'));
      await tester.pump();
      await waitFor(tester, find.widgetWithText(ElevatedButton, 'Entrar'));

      expect(find.text('Bem-vindo de volta'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
      if (find.textContaining('Credenciais').evaluate().isEmpty) {
        final visibleTexts = find
            .byType(Text)
            .evaluate()
            .map((element) => (element.widget as Text).data)
            .whereType<String>()
            .toList();
        throw TestFailure(
          'Expected invalid-credential feedback; visible texts: $visibleTexts',
        );
      }
      expect(find.textContaining('Sem conexão'), findsNothing);
      expect(tester.takeException(), isNull);
      });
    }

    if (buttonAudit) {
      testWidgets('QA-NAV-ADMIN botoes principais do administrador', (tester) async {
        final failures = <String>[];
        await login(tester,
            identifier: 'qa-admin-a@getcutt.test',
            expectedHomeText: 'Faturamento de hoje');
        await verifyNavigation(tester, 'Serviços', '+ Novo serviço', failures);
        await verifyNavigation(tester, 'Equipe', '+ Adicionar membro', failures);
        await verifyNavigation(tester, 'Financeiro', 'Nova despesa', failures);
        await verifyNavigation(tester, 'Visual', 'Personalizar barbearia', failures);
        await verifyNavigation(tester, 'Perfil', 'Meu perfil', failures);
        if (failures.isNotEmpty) throw TestFailure(failures.join('\n'));
      });

      testWidgets('QA-NAV-BARBER botoes principais do barbeiro', (tester) async {
        final failures = <String>[];
        await login(tester,
            identifier: 'qa-barber-a@getcutt.test', expectedHomeText: 'Agenda');
        await verifyNavigation(tester, 'Bloquear', 'Bloquear horário', failures);
        await verifyNavigation(tester, 'Horários', 'Horários de atendimento', failures);
        await verifyNavigation(tester, 'Contatos', 'Contatos', failures);
        await verifyNavigation(tester, 'Perfil', 'Meu perfil', failures);
        if (failures.isNotEmpty) throw TestFailure(failures.join('\n'));
      });

      testWidgets('QA-NAV-CLIENT botoes principais do cliente', (tester) async {
        final failures = <String>[];
        await login(tester,
            identifier: 'qa-client-a@getcutt.test',
            expectedHomeText: 'Agendar');
        await verifyNavigation(tester, 'Agenda', 'Minha agenda', failures);
        await verifyNavigation(tester, 'Histórico', 'Histórico', failures);
        await verifyNavigation(tester, 'Perfil', 'Meu perfil', failures);
        await verifyNavigation(tester, 'Início', 'Agendar', failures);
        if (failures.isNotEmpty) throw TestFailure(failures.join('\n'));
      });
    }

    if (appointmentFlow) {
      testWidgets(
          'QA-E2E-002/003/018/021/030/031 agendamento completo, persistência e cancelamento',
          (tester) async {
        await login(
          tester,
          identifier: 'qa-client-a@getcutt.test',
          expectedHomeText: 'Agendar',
        );

        await waitFor(tester, find.text('QA Barbearia A'));
        await tester.tap(find.text('QA Barbearia A').first);
        await waitFor(tester, find.text('QA Corte A'));

        await tester.tap(find.text('Profissional').first);
        await tester.pump();
        expect(find.text('QA Corte A'), findsOneWidget);

        // Interrupção/reload durante o fluxo: a seleção transitória não pode
        // criar reserva parcial nem sobreviver como confirmação implícita.
        await tester.tap(find.text('QA Corte A').first);
        app.main();
        await tester.pump();
        await waitFor(tester, find.text('Agendar'));
        await waitFor(tester, find.text('QA Corte A'));
        await tester.tap(find.text('Profissional').first);
        await tester.pump();
        expect(find.text('QA Corte A'), findsOneWidget);

        await tester.tap(find.text('QA Corte A').first);
        await tester.tap(find.text('QA Barba A').first);
        await tester.tap(find.textContaining('Continuar com 2'));
        await waitFor(tester, find.text('QA Barbeiro A'));

        // Retorno à etapa anterior preserva escolhas válidas e não envia API.
        await tester.tap(find.text('Voltar').first);
        await waitFor(
          tester,
          find.textContaining('Continuar com 2'),
        );
        await tester.tap(find.textContaining('Continuar com 2'));
        await waitFor(tester, find.text('QA Barbeiro A'));
        await tester.tap(find.text('QA Barbeiro A').first);
        await waitFor(tester, find.text('Selecione uma data para ver os horários.'));

        var confirmButton = find.widgetWithText(
          ElevatedButton,
          'Confirmar agendamento',
        );
        expect(confirmButton, findsOneWidget);
        expect(tester.widget<ElevatedButton>(confirmButton).onPressed, isNull);

        final bookingDate = DateTime.now().add(const Duration(days: 3));
        final dateLabel = DateFormat('dd/MM/yyyy').format(bookingDate);
        await tester.tap(find.bySemanticsLabel(dateLabel));
        await waitFor(tester, find.text('10:00'));
        confirmButton = find.widgetWithText(
          ElevatedButton,
          'Confirmar agendamento',
        );
        expect(tester.widget<ElevatedButton>(confirmButton).onPressed, isNull);

        await tester.tap(find.text('10:00').first);
        confirmButton = find.widgetWithText(
          ElevatedButton,
          'Confirmar agendamento',
        );
        expect(tester.widget<ElevatedButton>(confirmButton).onPressed, isNotNull);

        // Dois taps sem pump reproduzem um clique duplo real. A API deve
        // persistir uma única reserva e a UI deve permanecer recuperável.
        await tester.tap(confirmButton);
        await tester.tap(confirmButton);
        await waitFor(tester, find.text('Agendamento confirmado!'));
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Agenda').first);
        await waitFor(tester, find.text('Minha agenda'));
        await waitFor(tester, find.text('QA Corte A'));
        expect(find.text('Confirmado'), findsWidgets);

        // Reinicializa a árvore Flutter sem limpar SharedPreferences.
        app.main();
        await tester.pump();
        await waitFor(tester, find.text('Agendar'));
        await tester.tap(find.text('Agenda').first);
        await waitFor(tester, find.text('QA Corte A'));

        await logoutFromProfile(tester);
        await submitLogin(
          tester,
          identifier: 'qa-client-a@getcutt.test',
          expectedHomeText: 'Agendar',
        );
        await tester.tap(find.text('Agenda').first);
        await waitFor(tester, find.text('QA Corte A'));

        // A mesma reserva precisa ser visível na agenda do profissional.
        await logoutFromProfile(tester);
        await submitLogin(
          tester,
          identifier: 'qa-barber-a@getcutt.test',
          expectedHomeText: 'Agenda',
        );
        await waitFor(tester, find.text('QA Corte A'));

        await logoutFromProfile(tester);
        await submitLogin(
          tester,
          identifier: 'qa-client-a@getcutt.test',
          expectedHomeText: 'Agendar',
        );
        await tester.tap(find.text('Agenda').first);
        await waitFor(tester, find.text('QA Corte A'));
        await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
        await waitFor(tester, find.text('Cancelar agendamento?'));
        await tester.tap(find.text('Cancelar agendamento'));
        await waitFor(tester, find.text('Sua agenda está livre'));

        await tester.tap(find.text('Histórico').first);
        await waitFor(tester, find.text('Cancelado'));
        expect(find.text('QA Corte A'), findsOneWidget);

        // O slot cancelado precisa reaparecer no mesmo fluxo de interface.
        await tester.tap(find.text('Início').first);
        await waitFor(tester, find.text('QA Corte A'));
        await tester.tap(find.text('QA Corte A').first);
        await tester.tap(find.text('QA Barba A').first);
        await tester.tap(find.textContaining('Continuar com 2'));
        await waitFor(tester, find.text('QA Barbeiro A'));
        await tester.tap(find.text('QA Barbeiro A').first);
        await tester.tap(find.bySemanticsLabel(dateLabel));
        await waitFor(tester, find.text('10:00'));

        await tester.pump(const Duration(seconds: 2));
        expect(tester.takeException(), isNull);
      });
    }
  });
}
