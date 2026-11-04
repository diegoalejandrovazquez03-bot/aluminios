import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../core/api_client.dart';
import '../core/input_rules.dart';
import '../core/password_hash.dart';

class AppState extends ChangeNotifier {
  static const String _keyAccounts = 'alu_accounts';
  static const String _keySession = 'alu_client_session';
  static const String _keySettings = 'alu_client_settings';
  static const String _keyQuotes = 'alu_quotes';
  static const String _keyProducts = 'alu_products';
  static const String _keyTrash = 'alu_trash';
  static const String _keyWorks = 'alu_works';
  static const String _keyPayments = 'alu_payments';
  static const String _keyClients = 'alu_clients';
  static const String _keyVisits = 'alu_visits';
  static const String _keyNotices = 'alu_notices';

  AppSession? _session;
  Settings _settings = Settings();
  List<Account> _accounts = [];
  List<Product> _products = [];
  List<Client> _clients = [];
  List<Quote> _quotes = [];
  List<Payment> _payments = [];
  List<Visit> _visits = [];
  List<AppNotice> _notices = [];
  List<Work> _works = [];
  List<Map<String, dynamic>> _trash = [];
  List<Map<String, dynamic>> get trash => _trash;

  int _selectedQuoteId = 12;
  String _quoteFilter =
      'Todas'; // 'Todas' | 'Pendiente' | 'Aprobada' | 'Cancelada'
  int? _presetClientId;

  // Getters
  AppSession? get session => _session;
  bool get isLoggedIn => _session != null;
  bool get isAdmin => _session?.isAdmin ?? false;
  Settings get settings => _settings;
  List<Product> get products => _products;
  List<Client> get clients => _clients;
  List<Quote> get quotes => _quotes;
  List<Payment> get payments => _payments;
  List<Visit> get visits => _visits;

  /// Avisos del cliente, del más reciente al más antiguo.
  List<AppNotice> get notices =>
      List.of(_notices)..sort((a, b) => b.date.compareTo(a.date));
  int get unreadNotices => _notices.where((n) => !n.read).length;

  void markNoticesRead() {
    if (unreadNotices == 0) return;
    _notices = _notices.map((n) => n.markRead()).toList();
    _saveToStorage();
    notifyListeners();
  }

  List<Work> get works => _works;
  int get selectedQuoteId => _selectedQuoteId;
  String get quoteFilter => _quoteFilter;
  int? get presetClientId => _presetClientId;

  Quote? get selectedQuote {
    if (_quotes.isEmpty) return null;
    return _quotes.firstWhere(
      (q) => q.id == _selectedQuoteId,
      orElse: () => _quotes.first,
    );
  }

  /// Cliente de la sesión, o null. Nunca se sustituye por otro cliente: eso
  /// mostraría pedidos y saldos de otra persona.
  Client? get currentClient {
    final id = _session?.clientId;
    if (id == null) return null;
    return _clients.where((c) => c.id == id).firstOrNull;
  }

  /// Cuenta del cliente con sesión iniciada (null para el administrador).
  Account? get currentAccount {
    if (_session == null || isAdmin) return null;
    return _accounts.where((a) => a.clientId == _session!.clientId).firstOrNull;
  }

  void _replaceAccount(Account updated) {
    final idx = _accounts.indexWhere((a) => a.clientId == updated.clientId);
    if (idx != -1) _accounts[idx] = updated;
  }

  /// Mensaje para el usuario a partir de un error de red o del servidor.
  static String _errorText(Object error) {
    if (error is ApiException) return error.message;
    return 'No se pudo conectar con el servidor. Revisa tu conexión e inténtalo de nuevo.';
  }

  // ---- Modo sin servidor ----
  // Si el servidor no responde (sin conexión), las cuentas se guardan y se
  // verifican en el teléfono con la contraseña cifrada (nunca en texto).

  static const _offlineAdminEmail = 'admin@aluminieros.com';

  /// Contraseña de desarrollo del administrador para entrar sin servidor,
  /// guardada solo cifrada. QUITAR antes de publicar la app.
  static const _offlineAdminHash =
      r'pbkdf2-sha256$20000$MfnlIWQAVP7ZQm8iInXUXA==$NRi7891Wn+2T2cpDJMsOs01r+pZxogtrwvM5PDmVWgk=';

  /// Sesión iniciada sin servidor (no tiene token).
  bool get _isOfflineSession => _session != null && _session!.token.isEmpty;

  /// Error de conexión (no hubo respuesta), a diferencia de un error que
  /// devolvió el servidor, como "contraseña incorrecta".
  static bool _isConnectionError(Object error) => error is! ApiException;

  Future<String?> _startOfflineSession(
    String email,
    int clientId,
    String role,
  ) async {
    _session = AppSession(email: email, clientId: clientId, role: role);
    ApiClient.token = null;
    sessionMessage = null;
    await _saveToStorage();
    notifyListeners();
    return null;
  }

  Future<String?> _offlineLogin(String email, String password) async {
    if (email == _offlineAdminEmail) {
      if (!PasswordHash.verify(password, _offlineAdminHash)) {
        return 'Correo o contraseña incorrectos';
      }
      return _startOfflineSession(email, 0, 'admin');
    }
    final account = _accounts
        .where((a) => a.email == email && a.passwordHash.isNotEmpty)
        .firstOrNull;
    if (account == null ||
        !PasswordHash.verify(password, account.passwordHash)) {
      return 'Correo o contraseña incorrectos';
    }
    return _startOfflineSession(email, account.clientId, 'client');
  }

  Future<String?> _offlineRegister(
    String name,
    String phone,
    String email,
    String password,
  ) async {
    if (email == _offlineAdminEmail || _accounts.any((a) => a.email == email)) {
      return 'Este correo ya está registrado';
    }
    final clientId = DateTime.now().millisecondsSinceEpoch;
    _clients.insert(0, Client(id: clientId, name: name, phone: phone));
    _accounts.add(
      Account(
        clientId: clientId,
        name: name,
        phone: phone,
        email: email,
        passwordHash: PasswordHash.hash(password),
      ),
    );
    return _startOfflineSession(email, clientId, 'client');
  }

  /// Aplica el perfil que devuelve el servidor (login, registro o edición):
  /// sesión y, para clientes, su ficha y sus datos de cuenta en el teléfono.
  void _applyProfile(Map<String, dynamic> profile, {String? token}) {
    final role = profile['role'] as String? ?? 'client';
    final clientId = (profile['clientId'] as num?)?.toInt() ?? 0;
    final email = profile['email'] as String? ?? '';
    final newToken = token ?? _session?.token ?? '';
    _session = AppSession(
      email: email,
      clientId: clientId,
      role: role,
      token: newToken,
    );
    ApiClient.token = newToken;
    sessionMessage = null;
    if (role != 'client') return;

    final name = profile['name'] as String? ?? '';
    final phone = profile['phone'] as String? ?? '';
    final address = profile['address'] as String? ?? '';
    _upsert(
      _clients,
      Client(id: clientId, name: name, phone: phone, address: address),
      (c) => c.id,
    );
    final existing = _accounts.where((a) => a.clientId == clientId).firstOrNull;
    final account = Account(
      clientId: clientId,
      name: name,
      phone: phone,
      email: email,
      address: address,
      // La foto del servidor (si hay) gana; si no, se conserva la local.
      avatarUrl: (profile['avatarUrl'] as String? ?? '').isNotEmpty
          ? profile['avatarUrl'] as String
          : existing?.avatarUrl ?? '',
      passwordHash: existing?.passwordHash ?? '',
      noticeOrders: existing?.noticeOrders ?? true,
      noticePayments: existing?.noticePayments ?? true,
      noticeVisits: existing?.noticeVisits ?? true,
    );
    if (existing == null) {
      _accounts.add(account);
    } else {
      _replaceAccount(account);
    }
  }

  /// Actualiza nombre, teléfono y correo del cliente en el servidor.
  /// Devuelve un mensaje de error, o null si se guardó.
  Future<String?> updateMyProfile({
    required String name,
    required String phone,
    required String email,
    String address = '',
  }) async {
    if (currentAccount == null) return 'No hay una cuenta de cliente activa';
    final cleanEmail = email.trim().toLowerCase();
    final error = name.trim().isEmpty
        ? 'Escribe tu nombre'
        : PhoneInput.validate(phone) ?? AccountInput.validateEmail(cleanEmail);
    if (error != null) return error;
    if (_isOfflineSession) {
      // Cuenta del teléfono: se actualiza aquí mismo.
      final account = currentAccount!;
      if (cleanEmail == _offlineAdminEmail ||
          _accounts.any(
            (a) => a.clientId != account.clientId && a.email == cleanEmail,
          )) {
        return 'Ese correo ya está registrado en otra cuenta';
      }
      _replaceAccount(
        account.copyWith(
          name: name.trim(),
          phone: phone,
          email: cleanEmail,
          address: address.trim(),
        ),
      );
      _upsert(
        _clients,
        Client(
          id: account.clientId,
          name: name.trim(),
          phone: phone,
          address: address.trim(),
        ),
        (c) => c.id,
      );
      _session = AppSession(
        email: cleanEmail,
        clientId: account.clientId,
        role: 'client',
      );
    } else {
      try {
        final profile = await ApiClient.request(
          'auth',
          method: 'PUT',
          action: 'me',
          body: {
            'name': name.trim(),
            'phone': phone,
            'email': cleanEmail,
            'address': address.trim(),
          },
        );
        _applyProfile(Map<String, dynamic>.from(profile));
      } catch (e) {
        return _errorText(e);
      }
    }
    await _saveToStorage();
    notifyListeners();
    return null;
  }

  /// Cambia la contraseña en el servidor (verifica la actual allá).
  Future<String?> changeMyPassword(String current, String newPassword) async {
    if (_session == null) return 'No hay una sesión activa';
    final error = AccountInput.validatePassword(newPassword);
    if (error != null) return error;
    if (newPassword == current) {
      return 'La nueva contraseña debe ser distinta de la actual';
    }
    if (_isOfflineSession) {
      final account = currentAccount;
      if (account == null || account.passwordHash.isEmpty) {
        return 'Para cambiar esta contraseña se necesita conexión con el servidor';
      }
      if (!PasswordHash.verify(current, account.passwordHash)) {
        return 'La contraseña actual no es correcta';
      }
      _replaceAccount(
        account.copyWith(passwordHash: PasswordHash.hash(newPassword)),
      );
      await _saveToStorage();
      return null;
    }
    try {
      await ApiClient.request(
        'auth',
        method: 'POST',
        action: 'password',
        body: {'current': current, 'new': newPassword},
      );
      return null;
    } catch (e) {
      return _errorText(e);
    }
  }

  /// Foto del cliente: se guarda en su cuenta, no en la configuración del
  /// taller (antes el cliente cambiaba la foto del dueño).
  /// Con servidor también se sube, para no perderla al cambiar de teléfono.
  void updateMyAvatar(String dataUrl) {
    final account = currentAccount;
    if (account == null) return;
    _replaceAccount(account.copyWith(avatarUrl: dataUrl));
    if (!_isOfflineSession) {
      ApiClient.request(
        'auth',
        method: 'PUT',
        action: 'avatar',
        body: {'avatarUrl': dataUrl},
      ).catchError((Object error) {
        debugPrint('No se pudo subir la foto de perfil: ');
        return null;
      });
    }
    _saveToStorage();
    notifyListeners();
  }

  /// Qué avisos quiere recibir el cliente (se guarda en el teléfono).
  void setNoticePrefs({bool? orders, bool? payments, bool? visits}) {
    final account = currentAccount;
    if (account == null) return;
    _replaceAccount(
      account.copyWith(
        noticeOrders: orders,
        noticePayments: payments,
        noticeVisits: visits,
      ),
    );
    _saveToStorage();
    notifyListeners();
  }

  /// Elimina la cuenta del cliente (pide su contraseña). Con servidor se
  /// borra allá; sin servidor, en el teléfono. En ambos casos se quitan sus
  /// datos personales del teléfono y se cierra la sesión.
  Future<String?> deleteMyAccount(String password) async {
    final account = currentAccount;
    if (account == null || isAdmin) {
      return 'No hay una cuenta de cliente activa';
    }
    if (password.isEmpty) return 'Escribe tu contraseña para confirmar';
    if (_isOfflineSession) {
      if (!PasswordHash.verify(password, account.passwordHash)) {
        return 'La contraseña no es correcta';
      }
    } else {
      try {
        await ApiClient.request(
          'auth',
          method: 'DELETE',
          action: 'me',
          body: {'password': password},
        );
      } catch (e) {
        return _errorText(e);
      }
    }
    final clientId = account.clientId;
    _accounts.removeWhere((a) => a.clientId == clientId);
    _clients.removeWhere((c) => c.id == clientId);
    _visits.removeWhere((v) => v.clientId == clientId);
    _endSession('Tu cuenta fue eliminada.');
    return null;
  }

  List<Quote> get clientQuotes {
    final cId = _session?.clientId;
    if (cId == null) return [];
    return _quotes.where((q) => q.clientId == cId).toList();
  }

  int get nextFolioNum {
    int max = 0;
    for (final q in _quotes) {
      final clean = q.folio.replaceAll(RegExp(r'\D'), '');
      final num = int.tryParse(clean) ?? 0;
      if (num > max) max = num;
    }
    return max + 1;
  }

  // Formatting helpers
  static String formatMXN(num amount) {
    final formatter = NumberFormat.currency(
      locale: 'es_MX',
      symbol: '\$ ',
      decimalDigits: 0,
    );
    return formatter.format(amount.round());
  }

  static String today() {
    final now = DateTime.now();
    return "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
  }

  static String todayIso() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  AppState() {
    _initDefaultData();
    _loadFromStorage();
  }

  void _initDefaultData() {
    final imgs = [
      'https://images.unsplash.com/photo-1710883734891-93709398496d?w=160&h=120&fit=crop&auto=format',
      'https://images.unsplash.com/photo-1659720879327-827462ca3942?w=160&h=120&fit=crop&auto=format',
      'https://images.unsplash.com/photo-1638799869566-b17fa794c4de?w=160&h=120&fit=crop&auto=format',
      'https://images.unsplash.com/photo-1646164011652-36d408ae5d36?w=160&h=120&fit=crop&auto=format',
    ];

    _products = [
      Product(
        id: 1,
        name: 'Ventana corrediza',
        material: 'Aluminio natural',
        price: 1200,
        margin: 24,
        img: imgs[0],
        width: 120,
        height: 100,
        depth: 8,
      ),
      Product(
        id: 2,
        name: 'Puerta de aluminio',
        material: 'Cristal 6 mm',
        price: 2500,
        margin: 28,
        img: imgs[1],
        width: 90,
        height: 210,
        depth: 4,
      ),
      Product(
        id: 3,
        name: 'Cancel de baño',
        material: 'Aluminio blanco',
        price: 1800,
        margin: 22,
        img: imgs[2],
        width: 80,
        height: 190,
        depth: 6,
      ),
      Product(
        id: 4,
        name: 'Mosquitero',
        material: 'Aluminio natural',
        price: 450,
        margin: 31,
        img: imgs[3],
        width: 100,
        height: 100,
        depth: 3,
      ),
      Product(
        id: 5,
        name: 'Ventana "Pro-Max"',
        material: 'Aluminio anodizado',
        price: 1650,
        margin: 38,
        img: imgs[0],
        width: 150,
        height: 120,
        depth: 10,
      ),
    ];

    _clients = [
      Client(id: 1, name: 'Carlos Méndez', phone: '999 340 9396'),
      Client(id: 2, name: 'María López', phone: '999 340 9396'),
      Client(id: 3, name: 'Constructora Sur', phone: '999 340 9396'),
      Client(id: 4, name: 'Luis Pérez', phone: '999 340 9396'),
    ];

    _quotes = [
      Quote(
        id: 12,
        folio: '#0012',
        clientId: 1,
        date: '13/09/2026',
        status: QuoteStatus.pendiente,
        discount: 0,
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
      Quote(
        id: 11,
        folio: '#0011',
        clientId: 2,
        date: '12/09/2026',
        status: QuoteStatus.aprobada,
        discount: 5,
        items: [
          QuoteItem(
            productId: 2,
            width: 90,
            height: 210,
            qty: 1,
            unitPrice: 2500,
          ),
          QuoteItem(
            productId: 3,
            width: 80,
            height: 190,
            qty: 1,
            unitPrice: 1800,
          ),
        ],
      ),
      Quote(
        id: 10,
        folio: '#0010',
        clientId: 3,
        date: '10/09/2026',
        status: QuoteStatus.pendiente,
        discount: 0,
        items: [
          QuoteItem(
            productId: 1,
            width: 120,
            height: 100,
            qty: 4,
            unitPrice: 1200,
          ),
          QuoteItem(
            productId: 4,
            width: 120,
            height: 100,
            qty: 4,
            unitPrice: 450,
          ),
        ],
      ),
      Quote(
        id: 9,
        folio: '#0009',
        clientId: 4,
        date: '08/09/2026',
        status: QuoteStatus.cancelada,
        discount: 0,
        items: [
          QuoteItem(
            productId: 2,
            width: 90,
            height: 210,
            qty: 1,
            unitPrice: 2750,
          ),
        ],
      ),
      Quote(
        id: 8,
        folio: '#0008',
        clientId: 1,
        date: '13/09/2026',
        status: QuoteStatus.enProceso,
        discount: 0,
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
      Quote(
        id: 7,
        folio: '#0007',
        clientId: 2,
        date: '05/09/2026',
        status: QuoteStatus.completado,
        discount: 0,
        items: [
          QuoteItem(
            productId: 5,
            width: 150,
            height: 120,
            qty: 3,
            unitPrice: 1650,
          ),
        ],
      ),
      Quote(
        id: 6,
        folio: '#0006',
        clientId: 3,
        date: '02/09/2026',
        status: QuoteStatus.entregado,
        discount: 10,
        items: [
          QuoteItem(
            productId: 2,
            width: 90,
            height: 210,
            qty: 4,
            unitPrice: 2500,
          ),
          QuoteItem(
            productId: 4,
            width: 100,
            height: 100,
            qty: 6,
            unitPrice: 450,
          ),
        ],
      ),
    ];

    _payments = [
      Payment(
        id: 1,
        quoteId: 12,
        date: '01/10/2026',
        amount: 500,
        method: 'Efectivo',
      ),
      Payment(
        id: 2,
        quoteId: 11,
        date: '03/10/2026',
        amount: 2000,
        method: 'Transferencia',
      ),
      Payment(
        id: 3,
        quoteId: 8,
        date: '02/10/2026',
        amount: 1200,
        method: 'Tarjeta',
      ),
      Payment(
        id: 4,
        quoteId: 10,
        date: '04/10/2026',
        amount: 3000,
        method: 'Transferencia',
      ),
    ];

    _visits = [
      Visit(
        id: 1,
        date: '2026-10-07',
        start: '09:00',
        end: '10:30',
        type: 'Toma de medidas',
        clientId: 4,
        place: 'Cozumel',
      ),
      Visit(
        id: 2,
        date: '2026-10-07',
        start: '11:00',
        end: '13:00',
        type: 'Instalación',
        clientId: 3,
        place: 'Cancún',
      ),
      Visit(
        id: 3,
        date: '2026-10-09',
        start: '10:00',
        end: '11:00',
        type: 'Cotización',
        clientId: 2,
        place: 'Mérida',
      ),
      Visit(
        id: 4,
        date: '2026-10-14',
        start: '08:30',
        end: '12:00',
        type: 'Instalación',
        clientId: 1,
        place: 'Mérida',
      ),
      Visit(
        id: 5,
        date: '2026-10-21',
        start: '16:00',
        end: '17:00',
        type: 'Toma de medidas',
        clientId: 3,
        place: 'Progreso',
      ),
    ];

    String u(String id) =>
        'https://images.unsplash.com/photo-$id?w=420&h=320&fit=crop&auto=format';
    _works = [
      Work(
        id: 1,
        title: 'Cancel de baño templado',
        type: 'Cancel',
        img: u('1587527901949-ab0341697c1e'),
      ),
      Work(
        id: 2,
        title: 'Ventana moderna',
        type: 'Ventana',
        img: u('1758998256408-ab2c9fbec19b'),
      ),
      Work(
        id: 3,
        title: 'Domo residencial',
        type: 'Domo',
        img: u('1693098222752-3b84176b0e43'),
      ),
      Work(
        id: 4,
        title: 'Fachada comercial',
        type: 'Fachada',
        img: u('1621831337128-35676ca30868'),
      ),
      Work(
        id: 5,
        title: 'Barandal de cristal',
        type: 'Barandal',
        img: u('1758862528822-b0094ae44705'),
      ),
      Work(
        id: 6,
        title: 'Residencia con alberca',
        type: 'Residencial',
        img: u('1613490493576-7fde63acd811'),
      ),
      Work(
        id: 7,
        title: 'Fachada de oficinas',
        type: 'Fachada',
        img: u('1576731753569-3e93a228048c'),
      ),
      Work(
        id: 8,
        title: 'Ventanales de recámara',
        type: 'Ventana',
        img: u('1736593319421-250e17bb2f11'),
      ),
    ];
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Clients
      final rawClients = prefs.getString(_keyClients);
      if (rawClients != null) {
        _clients = (jsonDecode(rawClients) as List)
            .map((e) => Client.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      }

      // Accounts
      final rawAccounts = prefs.getString(_keyAccounts);
      if (rawAccounts != null) {
        final list = jsonDecode(rawAccounts) as List;
        _accounts = list.map((e) => Account.fromMap(e)).toList();
        for (final a in _accounts) {
          if (!_clients.any((c) => c.id == a.clientId)) {
            _clients.add(Client(id: a.clientId, name: a.name, phone: a.phone));
          }
        }
      }

      // Session
      final rawSession = prefs.getString(_keySession);
      if (rawSession != null) {
        // Sesión del servidor (con token) o del teléfono (sin token).
        final saved = AppSession.fromMap(jsonDecode(rawSession));
        _session = saved;
        ApiClient.token = saved.token.isEmpty ? null : saved.token;
      }

      // Settings
      final rawSettings = prefs.getString(_keySettings);
      if (rawSettings != null) {
        _settings = Settings.fromMap(jsonDecode(rawSettings));
      }

      // Custom quotes
      final rawQuotes = prefs.getString(_keyQuotes);
      if (rawQuotes != null) {
        final list = jsonDecode(rawQuotes) as List;
        _quotes = list.map((e) => Quote.fromMap(e)).toList();
      }

      // Custom products
      final rawProducts = prefs.getString(_keyProducts);
      if (rawProducts != null) {
        final list = jsonDecode(rawProducts) as List;
        _products = list.map((e) => Product.fromMap(e)).toList();
      }
      final rawTrash = prefs.getString(_keyTrash);
      if (rawTrash != null) {
        _trash = List<Map<String, dynamic>>.from(
          (jsonDecode(rawTrash) as List).map(
            (e) => Map<String, dynamic>.from(e),
          ),
        );
      }
      final rawWorks = prefs.getString(_keyWorks);
      if (rawWorks != null) {
        _works = (jsonDecode(rawWorks) as List)
            .map((e) => Work.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      }
      final rawPayments = prefs.getString(_keyPayments);
      if (rawPayments != null) {
        _payments = (jsonDecode(rawPayments) as List)
            .map((e) => Payment.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      }
      final rawVisits = prefs.getString(_keyVisits);
      if (rawVisits != null) {
        _visits = (jsonDecode(rawVisits) as List)
            .map((e) => Visit.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      }
      final rawNotices = prefs.getString(_keyNotices);
      if (rawNotices != null) {
        _notices = (jsonDecode(rawNotices) as List)
            .map((e) => AppNotice.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      }

      notifyListeners();
    } catch (_) {}
    await refreshFromServer();
  }

  /// Convierte un registro del backend; si viene incompleto o con otro
  /// formato se registra y se omite, en lugar de interrumpir toda la carga.
  static T? _parseRecord<T>(
    String what,
    dynamic raw,
    T Function(Map<String, dynamic>) parse,
  ) {
    try {
      return parse(Map<String, dynamic>.from(raw as Map));
    } catch (error, stack) {
      debugPrint(
        '[ERROR] Registro de $what inválido omitido: $error\n$raw\n$stack',
      );
      return null;
    }
  }

  /// Reemplaza en [list] el registro con el mismo id, o lo agrega.
  static void _upsert<T>(List<T> list, T item, int Function(T) idOf) {
    final idx = list.indexWhere((e) => idOf(e) == idOf(item));
    if (idx == -1) {
      list.add(item);
    } else {
      list[idx] = item;
    }
  }

  /// Mensaje para el login cuando la sesión se cerró sola (venció).
  String? sessionMessage;

  /// Trae del servidor los datos de la sesión actual. Cotizaciones, pagos,
  /// visitas y clientes se reemplazan por la versión del servidor (así el
  /// cliente ve los cambios del taller y viceversa); los productos solo se
  /// agregan porque el servidor no guarda sus fotos ni su margen.
  /// Con [notify] (por defecto) genera avisos para el cliente comparando lo
  /// que había con lo nuevo; al iniciar sesión no se generan.
  /// Devuelve false si no se pudo conectar.
  Future<bool> refreshFromServer({bool notify = true}) async {
    if (_session == null || _session!.token.isEmpty) return false;
    final resources = [
      'clientes',
      'productos',
      'cotizaciones',
      'trabajos',
      'pagos',
      'visitas',
    ];
    var expired = false;
    final results = await Future.wait(
      resources.map((resource) async {
        try {
          return await ApiClient.request(resource);
        } on ApiException catch (error) {
          if (error.statusCode == 401) expired = true;
          debugPrint('No se pudo cargar $resource: $error');
          return null;
        } catch (error) {
          debugPrint('Backend no disponible para $resource: $error');
          return null;
        }
      }),
    );
    if (expired) {
      _endSession('Tu sesión expiró. Vuelve a iniciar sesión.');
      return false;
    }
    if (results.every((r) => r == null)) return false;

    final before = notify && !isAdmin ? _snapshot() : null;
    final clients = results[0];
    final products = results[1];
    final quotes = results[2];
    final works = results[3];
    final payments = results[4];
    final visits = results[5];
    if (clients is List) {
      for (final raw in clients) {
        final item = _parseRecord('cliente', raw, Client.fromMap);
        if (item != null) _upsert(_clients, item, (c) => c.id);
      }
    }
    if (visits is List) {
      for (final raw in visits) {
        final item = _parseRecord('visita', raw, Visit.fromMap);
        if (item != null) _upsert(_visits, item, (v) => v.id);
      }
    }
    if (products is List) {
      for (final raw in products) {
        final data = Map<String, dynamic>.from(raw);
        data['material'] ??= data['category'] ?? '';
        data['img'] ??= '';
        final item = _parseRecord('producto', data, Product.fromMap);
        if (item != null &&
            !_products.any((existing) => existing.id == item.id)) {
          _products.add(item);
        }
      }
    }
    if (quotes is List) {
      for (final raw in quotes) {
        final item = _parseRecord('cotización', raw, Quote.fromMap);
        if (item != null) _upsert(_quotes, item, (q) => q.id);
      }
    }
    if (works is List) {
      for (final raw in works) {
        final item = _parseRecord('trabajo', raw, Work.fromMap);
        if (item != null && !_works.any((existing) => existing.id == item.id)) {
          _works.add(item);
        }
      }
    }
    if (payments is List) {
      for (final raw in payments) {
        final item = _parseRecord('pago', raw, Payment.fromMap);
        if (item != null) _upsert(_payments, item, (p) => p.id);
      }
    }
    if (before != null) _addNoticesSince(before);
    await _saveToStorage();
    notifyListeners();
    return true;
  }

  /// Estado de los pedidos, abonos y visitas del cliente antes de actualizar.
  ({
    Map<int, QuoteStatus> status,
    Map<int, int> photos,
    Set<int> payments,
    Map<int, String> visits,
  })
  _snapshot() {
    final mine = clientQuotes;
    return (
      status: {for (final q in mine) q.id: q.status},
      photos: {for (final q in mine) q.id: q.photos.length},
      payments: _payments.map((p) => p.id).toSet(),
      visits: {for (final v in _visits) v.id: v.status},
    );
  }

  /// Avisos por lo que cambió desde [before] (solo datos del cliente).
  void _addNoticesSince(
    ({
      Map<int, QuoteStatus> status,
      Map<int, int> photos,
      Set<int> payments,
      Map<int, String> visits,
    })
    before,
  ) {
    final now = DateTime.now();
    var seq = 0;
    void add(String text, {int? quoteId}) => _notices.add(
      AppNotice(
        id: now.microsecondsSinceEpoch + seq++,
        text: text,
        date: now.toIso8601String(),
        quoteId: quoteId,
      ),
    );

    final mine = clientQuotes;
    final myQuoteIds = mine.map((q) => q.id).toSet();
    // Preferencias del cliente (Perfil › Avisos).
    final prefs = currentAccount;
    final wantsOrders = prefs?.noticeOrders ?? true;
    final wantsPayments = prefs?.noticePayments ?? true;
    final wantsVisits = prefs?.noticeVisits ?? true;
    for (final q in wantsOrders ? mine : const <Quote>[]) {
      final oldStatus = before.status[q.id];
      if (oldStatus == null) {
        add('Tienes una nueva cotización ${q.folio}.', quoteId: q.id);
      } else if (oldStatus != q.status) {
        add(
          'Tu pedido ${q.folio} ahora está: ${q.status.label}.',
          quoteId: q.id,
        );
      }
      final newPhotos = q.photos.length - (before.photos[q.id] ?? 0);
      if (newPhotos > 0) {
        add(
          newPhotos == 1
              ? 'El taller agregó una foto del avance de ${q.folio}.'
              : 'El taller agregó $newPhotos fotos del avance de ${q.folio}.',
          quoteId: q.id,
        );
      }
    }
    for (final p in wantsPayments ? _payments : const <Payment>[]) {
      if (before.payments.contains(p.id) || !myQuoteIds.contains(p.quoteId)) {
        continue;
      }
      final folio = mine.firstWhere((q) => q.id == p.quoteId).folio;
      add(
        'Se registró un abono de ${formatMXN(p.amount)} en $folio.',
        quoteId: p.quoteId,
      );
    }
    final myId = _session?.clientId;
    for (final v in wantsVisits ? _visits : const <Visit>[]) {
      if (v.clientId != myId) continue;
      if (before.visits[v.id] == Visit.requested &&
          v.status == Visit.confirmed) {
        add('El taller confirmó tu visita del ${v.date} (${v.start}).');
      }
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_session != null) {
        await prefs.setString(_keySession, jsonEncode(_session!.toMap()));
      } else {
        await prefs.remove(_keySession);
      }
      await prefs.setString(_keySettings, jsonEncode(_settings.toMap()));
      await prefs.setString(
        _keyAccounts,
        jsonEncode(_accounts.map((a) => a.toMap()).toList()),
      );
      await prefs.setString(
        _keyQuotes,
        jsonEncode(_quotes.map((q) => q.toMap()).toList()),
      );
      await prefs.setString(
        _keyProducts,
        jsonEncode(_products.map((p) => p.toMap()).toList()),
      );
      await prefs.setString(_keyTrash, jsonEncode(_trash));
      await prefs.setString(
        _keyWorks,
        jsonEncode(_works.map((work) => work.toMap()).toList()),
      );
      await prefs.setString(
        _keyPayments,
        jsonEncode(_payments.map((payment) => payment.toMap()).toList()),
      );
      await prefs.setString(
        _keyClients,
        jsonEncode(_clients.map((client) => client.toMap()).toList()),
      );
      await prefs.setString(
        _keyVisits,
        jsonEncode(_visits.map((visit) => visit.toMap()).toList()),
      );
      await prefs.setString(
        _keyNotices,
        jsonEncode(_notices.map((n) => n.toMap()).toList()),
      );
    } catch (_) {}
  }

  // Authentication
  /// Inicia sesión en el servidor (administrador o cliente). Si no hay
  /// conexión, usa las cuentas guardadas en el teléfono.
  Future<String?> login(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    try {
      final result = await ApiClient.request(
        'auth',
        method: 'POST',
        action: 'login',
        body: {'email': cleanEmail, 'password': password},
      );
      _applyProfile(
        Map<String, dynamic>.from(result['profile']),
        token: result['token'] as String,
      );
    } catch (e) {
      if (_isConnectionError(e)) return _offlineLogin(cleanEmail, password);
      return _errorText(e);
    }
    await _saveToStorage();
    notifyListeners();
    // Al entrar no se generan avisos de cambios anteriores.
    await refreshFromServer(notify: false);
    return null;
  }

  /// Crea la cuenta del cliente en el servidor e inicia su sesión. Si no hay
  /// conexión, la crea en el teléfono (contraseña cifrada).
  Future<String?> register(
    String name,
    String phone,
    String email,
    String password,
  ) async {
    final cleanEmail = email.trim().toLowerCase();
    final error = name.trim().isEmpty
        ? 'Ingresa tu nombre completo'
        : PhoneInput.validate(phone) ??
              AccountInput.validateEmail(cleanEmail) ??
              AccountInput.validatePassword(password);
    if (error != null) return error;
    try {
      final result = await ApiClient.request(
        'auth',
        method: 'POST',
        action: 'register',
        body: {
          'name': name.trim(),
          'phone': phone,
          'email': cleanEmail,
          'password': password,
        },
      );
      _applyProfile(
        Map<String, dynamic>.from(result['profile']),
        token: result['token'] as String,
      );
    } catch (e) {
      if (_isConnectionError(e)) {
        return _offlineRegister(name.trim(), phone, cleanEmail, password);
      }
      return _errorText(e);
    }
    await _saveToStorage();
    notifyListeners();
    // Al entrar no se generan avisos de cambios anteriores.
    await refreshFromServer(notify: false);
    return null;
  }

  /// Cierra la sesión en el servidor (si hay conexión) y en el teléfono.
  void logout() {
    if (_session?.token.isNotEmpty ?? false) {
      ApiClient.request('auth', method: 'POST', action: 'logout').catchError((
        Object error,
      ) {
        debugPrint('No se pudo cerrar la sesión en el servidor: $error');
        return null;
      });
    }
    _endSession(null);
  }

  void _endSession(String? message) {
    _session = null;
    _notices = []; // Los avisos son de quien cerró la sesión.
    ApiClient.token = null;
    sessionMessage = message;
    _saveToStorage();
    notifyListeners();
  }

  // State actions
  void setSelectedQuoteId(int id) {
    _selectedQuoteId = id;
    notifyListeners();
  }

  void setQuoteFilter(String filter) {
    _quoteFilter = filter;
    notifyListeners();
  }

  void setPresetClientId(int? id) {
    _presetClientId = id;
    notifyListeners();
  }

  void updateSettings(Settings newSettings) {
    _settings = newSettings;
    _sync('perfil', newSettings.toMap(), method: 'PUT', id: 1);
    _saveToStorage();
    notifyListeners();
  }

  void toggleDarkMode(bool val) {
    _settings = _settings.copyWith(dark: val);
    _saveToStorage();
    notifyListeners();
  }

  // CRUD Products
  void addProduct(Product p) {
    _products.insert(0, p);
    _sync('productos', {
      'id': p.id,
      'name': p.name,
      'category': p.material,
      'unit': 'pieza',
      'price': p.price,
      'status': 'Activo',
    });
    _saveToStorage();
    notifyListeners();
  }

  void updateProduct(Product p) {
    final idx = _products.indexWhere((x) => x.id == p.id);
    if (idx != -1) {
      _products[idx] = p;
      _sync(
        'productos',
        {
          'id': p.id,
          'name': p.name,
          'category': p.material,
          'unit': 'pieza',
          'price': p.price,
          'status': 'Activo',
        },
        method: 'PUT',
        id: p.id,
      );
      _saveToStorage();
      notifyListeners();
    }
  }

  void deleteProduct(int id) {
    _products.removeWhere((p) => p.id == id);
    _sync('productos', {}, method: 'DELETE', id: id);
    _saveToStorage();
    notifyListeners();
  }

  // CRUD Clients
  void addClient(Client c) {
    _clients.insert(0, c);
    _sync('clientes', c.toMap());
    _saveToStorage();
    notifyListeners();
  }

  void updateClient(Client c) {
    final idx = _clients.indexWhere((x) => x.id == c.id);
    if (idx == -1) return;
    _clients[idx] = c;
    _sync('clientes', c.toMap(), method: 'PUT', id: c.id);
    _saveToStorage();
    notifyListeners();
  }

  // CRUD Quotes
  void addQuote(Quote q) {
    _quotes.insert(0, q);
    _sync('cotizaciones', {
      'id': q.id,
      'folio': q.folio,
      'clientId': q.clientId,
      'date': q.date,
      'status': q.status.label,
      'discount': q.discount,
      'items': q.items
          .map(
            (item) => {
              'productId': item.productId,
              'width': item.width,
              'height': item.height,
              'depth': item.depth,
              'qty': item.qty,
              'unitPrice': item.unitPrice,
            },
          )
          .toList(),
    });
    _selectedQuoteId = q.id;
    _quoteFilter = 'Todas';
    _saveToStorage();
    notifyListeners();
  }

  void updateQuote(Quote q) {
    final idx = _quotes.indexWhere((x) => x.id == q.id);
    if (idx != -1) {
      _quotes[idx] = q;
      _sync(
        'cotizaciones',
        {
          'id': q.id,
          'clientId': q.clientId,
          'date': q.date,
          'status': q.status.label,
          'discount': q.discount,
          'items': q.items.map((item) => item.toMap()).toList(),
        },
        method: 'PUT',
        id: q.id,
      );
      _saveToStorage();
      notifyListeners();
    }
  }

  /// El cliente aprueba o rechaza su cotización pendiente. Rechazar la deja
  /// como "Cancelada" (el taller la ve así; no se borra). Devuelve un mensaje
  /// de error, o null si se aplicó.
  String? respondToQuote(int quoteId, {required bool approve}) {
    final idx = _quotes.indexWhere((q) => q.id == quoteId);
    if (idx == -1) return 'No se encontró la cotización';
    final quote = _quotes[idx];
    if (quote.status != QuoteStatus.pendiente) {
      return 'Esta cotización ya no está pendiente';
    }
    final status = approve ? QuoteStatus.aprobada : QuoteStatus.cancelada;
    _quotes[idx] = quote.copyWith(status: status);
    // Solo se envía el estado: el servidor permite al cliente este cambio.
    _sync('cotizaciones', {'status': status.label}, method: 'PUT', id: quoteId);
    _saveToStorage();
    notifyListeners();
    return null;
  }

  /// Fotos del avance o de la instalación (las sube el taller).
  void setQuotePhotos(int quoteId, List<String> photos) {
    final idx = _quotes.indexWhere((q) => q.id == quoteId);
    if (idx == -1) return;
    _quotes[idx] = _quotes[idx].copyWith(photos: List.of(photos));
    _sync('cotizaciones', {'photos': photos}, method: 'PUT', id: quoteId);
    _saveToStorage();
    notifyListeners();
  }

  void archiveQuote(Quote quote) {
    final archivedAt = DateTime.now().toIso8601String();
    final entry = {
      'id': DateTime.now().microsecondsSinceEpoch,
      'type': 'cotizacion',
      'data': quote.toMap(),
      'archivedAt': archivedAt,
    };
    _trash.add(entry);
    _quotes.removeWhere((item) => item.id == quote.id);
    for (final payment
        in _payments.where((item) => item.quoteId == quote.id).toList()) {
      _trash.add({
        'id': DateTime.now().microsecondsSinceEpoch,
        'type': 'pago',
        'data': payment.toMap(),
        'archivedAt': archivedAt,
      });
    }
    _payments.removeWhere((item) => item.quoteId == quote.id);
    ApiClient.request(
          'cotizaciones',
          method: 'POST',
          id: quote.id,
          action: 'cancelar',
        )
        .then((result) {
          if (result is Map && result['id'] != null) {
            entry['backendId'] = result['id'];
            _saveToStorage();
          }
        })
        .catchError(
          (Object error) => debugPrint(
            'No se pudo archivar la cotización en backend: $error',
          ),
        );
    _selectedQuoteId = _quotes.isEmpty ? 0 : _quotes.first.id;
    _saveToStorage();
    notifyListeners();
  }

  void restoreTrashEntry(Map<String, dynamic> entry) {
    final backendId = entry['backendId'];
    if (backendId is int) {
      ApiClient.request(
        'papelera/$backendId',
        method: 'POST',
        action: 'restaurar',
      ).catchError((Object error) {
        debugPrint('No se pudo restaurar el registro en backend: $error');
        return null;
      });
    }
    if (entry['type'] == 'cotizacion') {
      _quotes.insert(
        0,
        Quote.fromMap(Map<String, dynamic>.from(entry['data'])),
      );
    }
    if (entry['type'] == 'pago') {
      _payments.add(Payment.fromMap(Map<String, dynamic>.from(entry['data'])));
    }
    if (entry['type'] == 'trabajo') {
      _works.insert(0, Work.fromMap(Map<String, dynamic>.from(entry['data'])));
    }
    if (entry['type'] == 'cotizacion') {
      final quoteId = Map<String, dynamic>.from(entry['data'])['id'];
      for (final paymentEntry
          in _trash
              .where(
                (item) =>
                    item['type'] == 'pago' &&
                    Map<String, dynamic>.from(item['data'])['quoteId'] ==
                        quoteId,
              )
              .toList()) {
        _payments.add(
          Payment.fromMap(Map<String, dynamic>.from(paymentEntry['data'])),
        );
        _trash.remove(paymentEntry);
      }
    }
    _trash.removeWhere((item) => item['id'] == entry['id']);
    _saveToStorage();
    notifyListeners();
  }

  void permanentlyDeleteTrashEntry(Map<String, dynamic> entry) {
    final backendId = entry['backendId'];
    if (backendId is int) {
      ApiClient.request('papelera', method: 'DELETE', id: backendId).catchError(
        (Object error) {
          debugPrint('No se pudo eliminar el registro del backend: $error');
          return null;
        },
      );
    }
    _trash.removeWhere((item) => item['id'] == entry['id']);
    _saveToStorage();
    notifyListeners();
  }

  void _sync(
    String resource,
    Map<String, dynamic> body, {
    String method = 'POST',
    int? id,
    String? action,
  }) {
    ApiClient.request(
      resource,
      method: method,
      id: id,
      body: body,
      action: action,
    ).catchError((Object error) {
      if (method == 'PUT' && id != null) {
        // Si el registro aún no existe en el backend, se crea. Este segundo
        // intento también puede fallar (sin conexión): se registra y listo.
        return ApiClient.request(
          resource,
          method: 'POST',
          body: {...body, 'id': id},
        ).catchError((Object retryError) {
          debugPrint(
            'No se pudo sincronizar $resource con el backend: $retryError',
          );
          return null;
        });
      }
      debugPrint('No se pudo sincronizar $resource con el backend: $error');
      return null;
    });
  }

  // CRUD Payments
  void addPayment(Payment p) {
    _payments.add(p);
    _sync('pagos', p.toMap());
    _saveToStorage();
    notifyListeners();
  }

  double paidOf(int quoteId) {
    return _payments
        .where((p) => p.quoteId == quoteId)
        .fold(0.0, (acc, p) => acc + p.amount);
  }

  // CRUD Visits
  /// Agenda una visita y la envía al servidor: así la solicitud del cliente
  /// le llega al taller (y la del taller aparece en el portal del cliente).
  void addVisit(Visit v) {
    _visits.insert(0, v);
    _sync('visitas', v.toMap());
    _saveToStorage();
    notifyListeners();
  }

  /// El taller confirma una visita que solicitó el cliente.
  void confirmVisit(int id) {
    final idx = _visits.indexWhere((v) => v.id == id);
    if (idx == -1) return;
    final v = _visits[idx];
    _visits[idx] = Visit(
      id: v.id,
      date: v.date,
      start: v.start,
      end: v.end,
      type: v.type,
      clientId: v.clientId,
      place: v.place,
      status: Visit.confirmed,
    );
    _sync('visitas', {'status': Visit.confirmed}, method: 'PUT', id: id);
    _saveToStorage();
    notifyListeners();
  }

  void deleteVisit(int id) {
    _visits.removeWhere((v) => v.id == id);
    ApiClient.request('visitas', method: 'DELETE', id: id).catchError((
      Object error,
    ) {
      debugPrint('No se pudo borrar la visita en el backend: $error');
      return null;
    });
    _saveToStorage();
    notifyListeners();
  }

  // CRUD Works
  void addWork(Work w) {
    _works.insert(0, w);
    _sync('trabajos', w.toMap());
    _saveToStorage();
    notifyListeners();
  }

  void deleteWork(int id) {
    final work = _works.where((item) => item.id == id).firstOrNull;
    if (work == null) return;
    final entry = {
      'id': DateTime.now().microsecondsSinceEpoch,
      'type': 'trabajo',
      'data': work.toMap(),
      'archivedAt': DateTime.now().toIso8601String(),
    };
    _trash.add(entry);
    _works.removeWhere((item) => item.id == id);
    ApiClient.request('trabajos', method: 'POST', id: id, action: 'cancelar')
        .then((result) {
          if (result is Map && result['id'] != null) {
            entry['backendId'] = result['id'];
            _saveToStorage();
          }
        })
        .catchError(
          (Object error) =>
              debugPrint('No se pudo archivar el trabajo en backend: $error'),
        );
    _saveToStorage();
    notifyListeners();
  }

  void resetData() {
    _initDefaultData();
    _saveToStorage();
    notifyListeners();
  }
}
