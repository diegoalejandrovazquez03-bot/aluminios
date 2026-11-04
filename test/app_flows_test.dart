import 'package:aluminios_app/core/api_client.dart';
import 'package:aluminios_app/core/app_routes.dart';
import 'package:aluminios_app/main.dart';
import 'package:aluminios_app/models/models.dart';
import 'package:aluminios_app/state/app_state.dart';
import 'package:aluminios_app/widgets/avatar_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_server.dart';

/// Servidor falso de cada prueba (se crea en setUp).
late FakeServer server;

/// Abre la app completa con sesión de administrador.
Future<AppState> pumpAdminApp(WidgetTester tester) async {
  // Pantalla de teléfono (390×844 lógicos), como el dispositivo real.
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final state = AppState();
  await tester.pumpAndSettle();
  expect(
    await state.login(FakeServer.adminEmail, FakeServer.adminPassword),
    isNull,
  );
  await tester.pumpWidget(AluminiosApp(appState: state));
  await tester.pumpAndSettle();
  return state;
}

Future<void> tapNav(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(NavigationDestination, label));
  await tester.pumpAndSettle();
}

void main() {
  // Sin red en pruebas: las fuentes usan la de respaldo.
  GoogleFonts.config.allowRuntimeFetching = false;
  setUp(() => server = FakeServer()..install());
  clientPortalTests();
  offlineTests();
  darkModeTests();
  clientPortalExtrasTests();
  clientProfileExtrasTests();

  testWidgets('Cotizaciones abre con datos de ejemplo', (tester) async {
    await pumpAdminApp(tester);
    await tapNav(tester, 'Cotizaciones');
    expect(tester.takeException(), isNull);
    expect(find.text('Nueva cotización'), findsWidgets);
  });

  testWidgets('Cotizaciones abre sin cotizaciones registradas', (tester) async {
    final state = await pumpAdminApp(tester);
    state.quotes.clear();
    state.payments.clear();
    await tapNav(tester, 'Cotizaciones');
    expect(tester.takeException(), isNull);
    expect(find.text('No hay cotizaciones con este filtro'), findsOneWidget);
    for (final f in ['Pendiente', 'Aprobada', 'Cancelada', 'Todas']) {
      await tester.tap(find.widgetWithText(FilterChip, f));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Cancelar una cotización y abrir la papelera', (tester) async {
    final state = await pumpAdminApp(tester);
    final quote = state.quotes.first;
    state.archiveQuote(quote);
    await tester.pumpAndSettle();
    await tapNav(tester, 'Cotizaciones');
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Papelera'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Cotización ${quote.folio}'), findsOneWidget);
  });

  testWidgets('El regreso lleva a la pantalla anterior', (tester) async {
    await pumpAdminApp(tester);
    await tapNav(tester, 'Clientes');
    await tapNav(tester, 'Cotizaciones');
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    expect(find.text('Clientes'), findsWidgets);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    // En Inicio no hay flecha: regresar ahí cerraría la app.
    await tapNav(tester, 'Inicio');
    expect(find.byTooltip('Volver'), findsNothing);
  });

  testWidgets('Nueva cotización conserva lo que se teclea, con decimales', (
    tester,
  ) async {
    await pumpAdminApp(tester);
    await tester.tap(find.byTooltip('Menú'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Nueva cotización'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar producto'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();

    final width = find.widgetWithText(TextField, 'Ancho').first;
    // Tecla por tecla, como en el teléfono: antes "120." perdía el punto.
    for (final text in ['1', '12', '120', '120.', '120.5']) {
      await tester.enterText(width, text);
      await tester.pump();
      expect(
        tester.widget<TextField>(width).controller!.text,
        text,
        reason: 'después de escribir "$text"',
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cliente: el teléfono solo acepta 10 dígitos', (tester) async {
    final state = await pumpAdminApp(tester);
    await tapNav(tester, 'Clientes');
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Nombre completo *'),
      'Prueba',
    );
    final phone = find.widgetWithText(TextField, 'Teléfono (10 dígitos) *');
    await tester.enterText(phone, '99-93a40');
    await tester.pump();
    // Letras y guiones se descartan: solo quedan los dígitos.
    expect(tester.widget<TextField>(phone).controller!.text, '999340');
    await tester.enterText(phone, '99934');
    await tester.tap(find.text('Guardar cliente'));
    await tester.pumpAndSettle();
    expect(state.clients.any((c) => c.name == 'Prueba'), isFalse);
    await tester.enterText(phone, '9993409396');
    await tester.tap(find.text('Guardar cliente'));
    await tester.pumpAndSettle();
    expect(
      state.clients.any((c) => c.name == 'Prueba' && c.phone == '9993409396'),
      isTrue,
    );
    // Deja que el aviso del formulario (2.5 s) termine.
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Chat del asesor: el campo queda arriba del teclado', (
    tester,
  ) async {
    await pumpAdminApp(tester);
    await tester.tap(find.byTooltip('Menú'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Nueva cotización'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Asesor de cotización'));
    await tester.pumpAndSettle();
    // Teclado de 300 px lógicos.
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    await tester.pumpAndSettle();
    final input = find.widgetWithText(
      TextField,
      'Pregunta sobre materiales o precios...',
    );
    expect(tester.getBottomLeft(input).dy, lessThanOrEqualTo(844 - 300));
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
  });

  testWidgets('Agenda muestra próximas y realizadas', (tester) async {
    await pumpAdminApp(tester);
    await tester.tap(find.byTooltip('Menú'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Agenda de visitas'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.textContaining('Realizadas'),
      find.byType(ListView).first,
      const Offset(0, -300),
    );
    await tester.tap(find.textContaining('Realizadas'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cada opción del menú abre su pantalla', (tester) async {
    await pumpAdminApp(tester);
    const titles = {
      'Productos': AdminScreen.productos,
      'Cotizaciones': AdminScreen.cotizaciones,
      'Clientes': AdminScreen.clientes,
      'Anticipos y pagos': AdminScreen.pagos,
      'Agenda de visitas': AdminScreen.agenda,
      'Catálogo visual': AdminScreen.catalogo,
    };
    for (final entry in titles.entries) {
      await tester.tap(find.byTooltip('Menú'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, entry.key));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: entry.key);
    }
  });
}

/// Registra un cliente desde la pantalla de login y abre su portal.
Future<AppState> pumpClientApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final state = AppState();
  await tester.pumpAndSettle();
  expect(
    await state.register(
      'Ana Ruiz',
      '9991234567',
      'ana@correo.com',
      'secreta1',
    ),
    isNull,
  );
  await tester.pumpWidget(AluminiosApp(appState: state));
  await tester.pumpAndSettle();
  return state;
}

void clientPortalTests() {
  test('El registro valida datos antes de ir al servidor', () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    expect(
      await state.register('Ana', '9991234567', 'ana', 'secreta1'),
      isNotNull,
    );
    expect(
      await state.register('Ana', '9991234567', 'ana@c.com', '123'),
      isNotNull,
    );
    expect(
      await state.register('Ana', '99912', 'ana@c.com', 'secreta1'),
      isNotNull,
    );
    expect(
      await state.register('', '9991234567', 'ana@c.com', 'secreta1'),
      isNotNull,
    );
    expect(server.accounts.length, 1, reason: 'solo el administrador');
    expect(
      await state.register('Ana', '9991234567', 'ana@c.com', 'secreta1'),
      isNull,
    );
    expect(server.accounts.length, 2);
    expect(state.isAdmin, isFalse);
    // Correo repetido: lo rechaza el servidor.
    final other = AppState();
    expect(
      await other.register('Otra', '9997654321', 'ANA@c.com', 'secreta1'),
      'Este correo ya está registrado',
    );
  });

  test('El inicio de sesión lo verifica el servidor', () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    expect(await state.login(FakeServer.adminEmail, '123456'), isNotNull);
    expect(state.isLoggedIn, isFalse);
    expect(
      await state.login(FakeServer.adminEmail, FakeServer.adminPassword),
      isNull,
    );
    expect(state.isAdmin, isTrue);
  });

  test('La app no guarda contraseñas en el teléfono', () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    await state.register('Ana', '9991234567', 'ana@c.com', 'secreta1');
    await Future<void>.delayed(Duration.zero);
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys()) {
      expect('${prefs.get(key)}', isNot(contains('secreta1')), reason: key);
    }
  });

  test('Nunca se muestran los datos de otro cliente', () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    await state.register('Ana', '9991234567', 'ana@c.com', 'secreta1');
    expect(state.currentClient?.name, 'Ana');
    state.clients.removeWhere((c) => c.name == 'Ana');
    // Antes devolvía el primer cliente de la lista (datos ajenos).
    expect(state.currentClient, isNull);
  });

  test(
    'La visita del cliente llega al taller y el taller la confirma',
    () async {
      SharedPreferences.setMockInitialValues({});
      final ana = AppState();
      await ana.register('Ana', '9991234567', 'ana@c.com', 'secreta1');
      ana.addVisit(
        Visit(
          id: 777,
          date: '2099-01-02',
          start: '09:00',
          end: '12:00',
          type: 'Toma de medidas',
          clientId: ana.session!.clientId,
          place: 'Centro',
          status: Visit.requested,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(server.table('visitas').single['status'], 'Solicitada');

      final admin = AppState();
      await admin.login(FakeServer.adminEmail, FakeServer.adminPassword);
      final received = admin.visits.firstWhere((v) => v.id == 777);
      expect(received.statusLabel, 'Por confirmar');
      admin.confirmVisit(777);
      await Future<void>.delayed(Duration.zero);

      // El cliente lo ve al actualizar.
      expect(await ana.refreshFromServer(), isTrue);
      expect(
        ana.visits.firstWhere((v) => v.id == 777).statusLabel,
        'Confirmada',
      );

      // Otro cliente no recibe del servidor las visitas de Ana, y su portal
      // solo muestra las suyas (aunque compartan el mismo teléfono).
      final beto = AppState();
      await beto.register('Beto', '9997654321', 'beto@c.com', 'secreta2');
      expect(await ApiClient.request('visitas'), isEmpty);
      expect(
        beto.visits.where((v) => v.clientId == beto.session!.clientId),
        isEmpty,
      );
    },
  );

  test('Una sesión vencida vuelve al login con aviso', () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    await state.register('Ana', '9991234567', 'ana@c.com', 'secreta1');
    server.sessions.clear(); // el servidor ya no reconoce el token
    expect(await state.refreshFromServer(), isFalse);
    expect(state.isLoggedIn, isFalse);
    expect(state.sessionMessage, contains('expiró'));
  });

  testWidgets('El perfil del cliente es propio, sin opciones del negocio', (
    tester,
  ) async {
    await pumpClientApp(tester);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Perfil'));
    await tester.pumpAndSettle();
    expect(find.text('Ana Ruiz'), findsWidgets);
    expect(find.text('ana@correo.com'), findsWidgets);
    expect(find.text('Información del negocio'), findsNothing);
    expect(find.text('Configuración del sistema'), findsNothing);
    expect(find.textContaining('Restaurar'), findsNothing);
    expect(find.text('Juan Pérez'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('El cliente edita sus datos y su contraseña en el servidor', (
    tester,
  ) async {
    final state = await pumpClientApp(tester);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Perfil'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Editar mis datos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar mis datos'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Teléfono (10 dígitos)'),
      '9993409396',
    );
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();
    expect(state.currentClient?.phone, '9993409396');
    expect(
      server
          .table('clientes')
          .firstWhere((c) => c['id'] == state.session!.clientId)['phone'],
      '9993409396',
    );

    await tester.ensureVisible(find.text('Cambiar contraseña'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cambiar contraseña'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Contraseña actual'),
      'secreta1',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Nueva contraseña (mín. 6 caracteres)'),
      'nueva123',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirmar nueva contraseña'),
      'nueva123',
    );
    await tester.tap(find.text('Guardar contraseña'));
    await tester.pumpAndSettle();
    expect(
      server.accounts.firstWhere(
        (a) => a['email'] == 'ana@correo.com',
      )['password'],
      'nueva123',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('El cliente ve "Mis visitas" con su estado', (tester) async {
    final state = await pumpClientApp(tester);
    state.addVisit(
      Visit(
        id: 888,
        date: '2099-03-04',
        start: '09:00',
        end: '12:00',
        type: 'Toma de medidas',
        clientId: state.session!.clientId,
        place: 'Centro',
        status: Visit.requested,
      ),
    );
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('Mis visitas'),
      find.byType(ListView).first,
      const Offset(0, -200),
    );
    expect(find.text('Por confirmar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// Simula que no hay conexión con el servidor.
void noServer() {
  ApiClient.token = null;
  ApiClient.clientFactory = () =>
      MockClient((_) async => throw http.ClientException('Sin conexión'));
}

void offlineTests() {
  test('Sin servidor se puede crear cuenta e iniciar sesión', () async {
    noServer();
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    expect(
      await state.register('Ana', '9991234567', 'ana@c.com', 'secreta1'),
      isNull,
    );
    expect(state.isLoggedIn, isTrue);
    expect(state.isAdmin, isFalse);
    expect(state.currentClient?.name, 'Ana');
    state.logout();

    expect(
      await state.login('ana@c.com', 'mala123'),
      'Correo o contraseña incorrectos',
    );
    expect(await state.login('ANA@c.com', 'secreta1'), isNull);
    expect(state.currentAccount?.email, 'ana@c.com');

    // Correo repetido.
    state.logout();
    expect(
      await state.register('Otra', '9997654321', 'ana@c.com', 'secreta2'),
      'Este correo ya está registrado',
    );

    // La contraseña nunca queda en texto en el teléfono.
    await Future<void>.delayed(Duration.zero);
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys()) {
      expect('${prefs.get(key)}', isNot(contains('secreta1')), reason: key);
    }
  });

  test('Sin servidor el administrador puede entrar', () async {
    noServer();
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    expect(await state.login('admin@aluminieros.com', '000000'), isNotNull);
    expect(await state.login('admin@aluminieros.com', '123456'), isNull);
    expect(state.isAdmin, isTrue);
  });

  test('La sesión sin servidor se conserva al reabrir la app', () async {
    noServer();
    SharedPreferences.setMockInitialValues({});
    final first = AppState();
    await first.register('Ana', '9991234567', 'ana@c.com', 'secreta1');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final reopened = AppState();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(reopened.isLoggedIn, isTrue);
    expect(reopened.currentClient?.name, 'Ana');
  });

  test('Sin servidor se cambia la contraseña de la cuenta', () async {
    noServer();
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    await state.register('Ana', '9991234567', 'ana@c.com', 'secreta1');
    expect(
      await state.changeMyPassword('mala', 'nueva123'),
      'La contraseña actual no es correcta',
    );
    expect(await state.changeMyPassword('secreta1', 'nueva123'), isNull);
    state.logout();
    expect(await state.login('ana@c.com', 'secreta1'), isNotNull);
    expect(await state.login('ana@c.com', 'nueva123'), isNull);
  });
}

void darkModeTests() {
  testWidgets('Cambiar a modo oscuro y de regreso no rompe la app', (
    tester,
  ) async {
    final state = await pumpAdminApp(tester);
    for (final screen in ['Inicio', 'Productos', 'Cotizaciones']) {
      await tapNav(tester, screen);
      // Desde el menú lateral, como lo hace el usuario.
      await tester.tap(find.byTooltip('Menú'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch).last);
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: screen);
      // Cierra el menú y verifica que la app sigue respondiendo.
      await tester.tapAt(const Offset(380, 400));
      await tester.pumpAndSettle();
    }
    expect(state.settings.dark, isTrue, reason: '3 cambios: queda en oscuro');
    await tapNav(tester, 'Clientes');
    expect(tester.takeException(), isNull);
  });
}

/// Cliente (Ana) con una cotización pendiente en el servidor.
Future<({AppState ana, AppState admin, int quoteId})> _anaWithQuote() async {
  SharedPreferences.setMockInitialValues({});
  final ana = AppState();
  await ana.register('Ana', '9991234567', 'ana@c.com', 'secreta1');
  final clientId = ana.session!.clientId;
  ana.addQuote(
    Quote(
      id: 9001,
      folio: '#9001',
      clientId: clientId,
      date: '28/10/2026',
      status: QuoteStatus.pendiente,
      items: [
        QuoteItem(
          productId: 1,
          width: 120,
          height: 100,
          qty: 1,
          unitPrice: 1200,
        ),
      ],
    ),
  );
  await Future<void>.delayed(Duration.zero);
  final admin = AppState();
  await admin.login(FakeServer.adminEmail, FakeServer.adminPassword);
  // Vuelve a dejar el token de Ana para sus siguientes peticiones.
  ApiClient.token = ana.session!.token;
  return (ana: ana, admin: admin, quoteId: 9001);
}

/// Hace las peticiones como [state] (cada sesión tiene su token).
Future<T> asUser<T>(AppState state, Future<T> Function() action) async {
  ApiClient.token = state.session!.token;
  final result = await action();
  await Future<void>.delayed(Duration.zero);
  return result;
}

void clientPortalExtrasTests() {
  test('El cliente aprueba su cotización y el taller lo ve', () async {
    final s = await _anaWithQuote();
    expect(s.ana.respondToQuote(s.quoteId, approve: true), isNull);
    await Future<void>.delayed(Duration.zero);
    expect(
      server.table('cotizaciones').firstWhere((q) => q['id'] == 9001)['status'],
      'Aprobada',
    );
    // Ya no está pendiente: no se puede volver a responder.
    expect(s.ana.respondToQuote(s.quoteId, approve: false), isNotNull);
    await asUser(s.admin, () => s.admin.refreshFromServer());
    expect(
      s.admin.quotes.firstWhere((q) => q.id == 9001).status,
      QuoteStatus.aprobada,
    );
  });

  test('El cliente rechaza su cotización', () async {
    final s = await _anaWithQuote();
    expect(s.ana.respondToQuote(s.quoteId, approve: false), isNull);
    await Future<void>.delayed(Duration.zero);
    expect(
      server.table('cotizaciones').firstWhere((q) => q['id'] == 9001)['status'],
      'Cancelada',
    );
  });

  test('El cliente no puede cambiar otros datos de la cotización', () async {
    final s = await _anaWithQuote();
    await expectLater(
      ApiClient.request(
        'cotizaciones',
        method: 'PUT',
        id: s.quoteId,
        body: {'discount': 90},
      ),
      throwsA(isA<ApiException>()),
    );
  });

  test('Las fotos del avance llegan al cliente con un aviso', () async {
    final s = await _anaWithQuote();
    await asUser(s.admin, () async {
      await s.admin.refreshFromServer();
      s.admin.setQuotePhotos(s.quoteId, ['data:image/jpeg;base64,AAAA']);
    });
    expect(s.ana.unreadNotices, 0);
    await asUser(s.ana, () => s.ana.refreshFromServer());
    expect(s.ana.quotes.firstWhere((q) => q.id == 9001).photos, hasLength(1));
    expect(s.ana.unreadNotices, 1);
    expect(s.ana.notices.first.text, contains('foto del avance'));
    s.ana.markNoticesRead();
    expect(s.ana.unreadNotices, 0);
  });

  test(
    'Abonos, cambios de estado y visitas confirmadas generan avisos',
    () async {
      final s = await _anaWithQuote();
      s.ana.addVisit(
        Visit(
          id: 555,
          date: '2099-01-02',
          start: '09:00',
          end: '12:00',
          type: 'Toma de medidas',
          clientId: s.ana.session!.clientId,
          place: 'Centro',
          status: Visit.requested,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await asUser(s.admin, () async {
        await s.admin.refreshFromServer();
        s.admin.updateQuote(
          s.admin.quotes
              .firstWhere((q) => q.id == 9001)
              .copyWith(status: QuoteStatus.enProceso),
        );
        s.admin.addPayment(
          Payment(
            id: 7001,
            quoteId: 9001,
            date: '28/10/2026',
            amount: 500,
            method: 'Efectivo',
          ),
        );
        s.admin.confirmVisit(555);
      });
      await asUser(s.ana, () => s.ana.refreshFromServer());
      final texts = s.ana.notices.map((n) => n.text).join(' | ');
      expect(texts, contains('ahora está: En proceso'));
      expect(texts, contains('abono'));
      expect(texts, contains('confirmó tu visita'));
    },
  );

  test('Iniciar sesión no genera avisos de cambios anteriores', () async {
    final s = await _anaWithQuote();
    s.ana.logout();
    expect(await s.ana.login('ana@c.com', 'secreta1'), isNull);
    expect(s.ana.unreadNotices, 0);
  });

  testWidgets('Detalle del pedido: aprobar, PDF y campana de avisos', (
    tester,
  ) async {
    final state = await pumpClientApp(tester);
    state.addQuote(
      Quote(
        id: 9100,
        folio: '#9100',
        clientId: state.session!.clientId,
        date: '28/10/2026',
        status: QuoteStatus.pendiente,
        items: [
          QuoteItem(
            productId: 1,
            width: 120,
            height: 100,
            qty: 1,
            unitPrice: 1200,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Avisos'), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Pedidos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('#9100'));
    await tester.pumpAndSettle();
    expect(find.text('¿Aceptas esta cotización?'), findsOneWidget);
    expect(find.text('Descargar o compartir PDF'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Aprobar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Aprobar').last);
    await tester.pumpAndSettle();
    expect(
      state.quotes.firstWhere((q) => q.id == 9100).status,
      QuoteStatus.aprobada,
    );
    // El detalle se actualizó solo: ya no pide aprobar.
    expect(find.text('¿Aceptas esta cotización?'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

void clientProfileExtrasTests() {
  test('La dirección se guarda en el servidor y en la ficha', () async {
    SharedPreferences.setMockInitialValues({});
    final ana = AppState();
    await ana.register('Ana', '9991234567', 'ana@c.com', 'secreta1');
    expect(
      await ana.updateMyProfile(
        name: 'Ana',
        phone: '9991234567',
        email: 'ana@c.com',
        address: 'Calle 60 #123, Centro',
      ),
      isNull,
    );
    expect(ana.currentClient?.address, 'Calle 60 #123, Centro');
    expect(ana.currentAccount?.address, 'Calle 60 #123, Centro');
    expect(
      server
          .table('clientes')
          .firstWhere((c) => c['id'] == ana.session!.clientId)['address'],
      'Calle 60 #123, Centro',
    );
  });

  test('La foto de perfil se sube y se recupera en otro teléfono', () async {
    SharedPreferences.setMockInitialValues({});
    final ana = AppState();
    await ana.register('Ana', '9991234567', 'ana@c.com', 'secreta1');
    ana.updateMyAvatar('data:image/jpeg;base64,FOTO');
    await Future<void>.delayed(Duration.zero);
    // "Otro teléfono": almacenamiento vacío, inicia sesión y trae la foto.
    SharedPreferences.setMockInitialValues({});
    final other = AppState();
    await Future<void>.delayed(Duration.zero);
    expect(await other.login('ana@c.com', 'secreta1'), isNull);
    expect(other.currentAccount?.avatarUrl, 'data:image/jpeg;base64,FOTO');
  });

  test('Eliminar la cuenta con servidor', () async {
    SharedPreferences.setMockInitialValues({});
    final ana = AppState();
    await ana.register('Ana', '9991234567', 'ana@c.com', 'secreta1');
    ana.addVisit(
      Visit(
        id: 321,
        date: '2099-01-02',
        start: '09:00',
        end: '12:00',
        type: 'Toma de medidas',
        clientId: ana.session!.clientId,
        place: 'Centro',
        status: Visit.requested,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(await ana.deleteMyAccount('mala'), 'La contraseña no es correcta');
    expect(ana.isLoggedIn, isTrue);
    expect(await ana.deleteMyAccount('secreta1'), isNull);
    expect(ana.isLoggedIn, isFalse);
    expect(ana.sessionMessage, 'Tu cuenta fue eliminada.');
    expect(server.accounts.any((a) => a['email'] == 'ana@c.com'), isFalse);
    expect(server.table('visitas'), isEmpty);
    // Ya no puede entrar.
    expect(await ana.login('ana@c.com', 'secreta1'), isNotNull);
  });

  test('Eliminar la cuenta sin servidor', () async {
    noServer();
    SharedPreferences.setMockInitialValues({});
    final ana = AppState();
    await ana.register('Ana', '9991234567', 'ana@c.com', 'secreta1');
    expect(await ana.deleteMyAccount('secreta1'), isNull);
    expect(ana.isLoggedIn, isFalse);
    expect(await ana.login('ana@c.com', 'secreta1'), isNotNull);
  });

  test('Las preferencias de avisos se respetan', () async {
    final s = await _anaWithQuote();
    s.ana.setNoticePrefs(payments: false);
    await asUser(s.admin, () async {
      await s.admin.refreshFromServer();
      s.admin.addPayment(
        Payment(
          id: 7002,
          quoteId: 9001,
          date: '28/10/2026',
          amount: 300,
          method: 'Efectivo',
        ),
      );
    });
    await asUser(s.ana, () => s.ana.refreshFromServer());
    expect(s.ana.notices.where((n) => n.text.contains('abono')), isEmpty);
  });

  testWidgets('Perfil: avatar real, resumen, errores en vivo y privacidad', (
    tester,
  ) async {
    await pumpClientApp(tester);
    // La barra superior muestra las iniciales del cliente, no "Usuario".
    final avatar = tester.widget<AvatarWidget>(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(AvatarWidget),
      ),
    );
    expect(avatar.name, 'Ana Ruiz');

    await tester.tap(find.widgetWithText(NavigationDestination, 'Perfil'));
    await tester.pumpAndSettle();
    expect(find.text('Pedidos activos'), findsOneWidget);
    expect(find.text('Saldo pendiente'), findsOneWidget);
    expect(find.text('Visitas próximas'), findsOneWidget);
    expect(find.text('Sin dirección'), findsOneWidget);

    await tester.ensureVisible(find.text('Editar mis datos'));
    await tester.tap(find.text('Editar mis datos'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Correo electrónico'),
      'ana@',
    );
    await tester.pump();
    // El error aparece mientras escribe, sin tener que guardar.
    expect(find.text('Escribe un correo válido'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Correo electrónico'),
      'ana@correo.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Dirección (opcional)'),
      'Calle 60 #123',
    );
    await tester.pump();
    expect(find.text('Escribe un correo válido'), findsNothing);
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();
    // Regresa arriba para ver el recuadro de datos.
    await tester.drag(find.byType(ListView).first, const Offset(0, 1500));
    await tester.pumpAndSettle();
    expect(find.text('Calle 60 #123'), findsOneWidget);

    // Espera a que desaparezca el aviso "Datos actualizados".
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Aviso de privacidad'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aviso de privacidad'));
    await tester.pumpAndSettle();
    expect(find.text('Responsable'), findsOneWidget);
    expect(find.textContaining('datos personales'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
