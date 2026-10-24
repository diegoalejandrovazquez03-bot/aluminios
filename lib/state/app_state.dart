import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../core/api_client.dart';

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

  AppSession? _session;
  Settings _settings = Settings();
  List<Account> _accounts = [];
  List<Product> _products = [];
  List<Client> _clients = [];
  List<Quote> _quotes = [];
  List<Payment> _payments = [];
  List<Visit> _visits = [];
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

  Client? get currentClient {
    if (_clients.isEmpty) return null;
    return _clients.firstWhere(
      (c) => c.id == _session?.clientId,
      orElse: () => _clients.first,
    );
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
      Client(id: 1, name: 'Carlos Méndez', phone: '999 123 4567'),
      Client(id: 2, name: 'María López', phone: '999 234 5678'),
      Client(id: 3, name: 'Constructora Sur', phone: '999 345 6789'),
      Client(id: 4, name: 'Luis Pérez', phone: '999 456 7890'),
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
        _session = AppSession.fromMap(jsonDecode(rawSession));
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

      notifyListeners();
    } catch (_) {}
    await _loadFromApi();
  }

  Future<void> _loadFromApi() async {
    final resources = [
      'clientes',
      'productos',
      'cotizaciones',
      'trabajos',
      'pagos',
    ];
    final results = await Future.wait(
      resources.map((resource) async {
        try {
          return await ApiClient.request(resource);
        } catch (error) {
          debugPrint('Backend no disponible para $resource: $error');
          return null;
        }
      }),
    );
    final clients = results[0];
    final products = results[1];
    final quotes = results[2];
    final works = results[3];
    final payments = results[4];
    if (clients is List) {
      for (final raw in clients) {
        final item = Client.fromMap(Map<String, dynamic>.from(raw));
        if (!_clients.any((existing) => existing.id == item.id)) {
          _clients.add(item);
        }
      }
    }
    if (products is List) {
      for (final raw in products) {
        final data = Map<String, dynamic>.from(raw);
        data['material'] ??= data['category'] ?? '';
        data['img'] ??= '';
        final item = Product.fromMap(data);
        if (!_products.any((existing) => existing.id == item.id)) {
          _products.add(item);
        }
      }
    }
    if (quotes is List) {
      for (final raw in quotes) {
        final item = Quote.fromMap(Map<String, dynamic>.from(raw));
        if (!_quotes.any((existing) => existing.id == item.id)) {
          _quotes.add(item);
        }
      }
    }
    if (works is List) {
      for (final raw in works) {
        final item = Work.fromMap(Map<String, dynamic>.from(raw));
        if (!_works.any((existing) => existing.id == item.id)) _works.add(item);
      }
    }
    if (payments is List) {
      for (final raw in payments) {
        final item = Payment.fromMap(Map<String, dynamic>.from(raw));
        if (!_payments.any((existing) => existing.id == item.id)) {
          _payments.add(item);
        }
      }
    }
    await _saveToStorage();
    notifyListeners();
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
    } catch (_) {}
  }

  // Authentication
  String? login(String email, String password) {
    final cleanEmail = email.trim().toLowerCase();
    final isAdminEmail = cleanEmail == 'admin@aluminieros.com';

    if (isAdminEmail) {
      if (password != '123456') {
        return 'La contraseña de administrador es incorrecta';
      }
      _session = AppSession(
        email: email,
        clientId: _clients.first.id,
        role: 'admin',
      );
      _saveToStorage();
      notifyListeners();
      return null;
    }

    final account = _accounts
        .where((a) => a.email.toLowerCase() == cleanEmail)
        .firstOrNull;
    if (account != null) {
      if (account.password != password) return 'La contraseña es incorrecta';
      _session = AppSession(
        email: email,
        clientId: account.clientId,
        role: 'client',
      );
      _saveToStorage();
      notifyListeners();
      return null;
    }

    return 'No encontramos una cuenta con ese correo';
  }

  String? register(String name, String phone, String email, String password) {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail == 'admin@aluminieros.com' ||
        _accounts.any((a) => a.email.toLowerCase() == cleanEmail)) {
      return 'Este correo ya está registrado';
    }

    final clientId = DateTime.now().millisecondsSinceEpoch;
    final account = Account(
      clientId: clientId,
      name: name.trim(),
      phone: phone.trim(),
      email: cleanEmail,
      password: password,
    );
    _accounts.add(account);
    _clients.insert(
      0,
      Client(id: clientId, name: account.name, phone: account.phone),
    );
    _sync('clientes', {
      'id': clientId,
      'name': account.name,
      'phone': account.phone,
    });
    _session = AppSession(
      email: cleanEmail,
      clientId: clientId,
      role: 'client',
    );
    _saveToStorage();
    notifyListeners();
    return null;
  }

  void logout() {
    _session = null;
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
    _sync('clientes', {'id': c.id, 'name': c.name, 'phone': c.phone});
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
        return ApiClient.request(
          resource,
          method: 'POST',
          body: {...body, 'id': id},
        );
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
  void addVisit(Visit v) {
    _visits.insert(0, v);
    _saveToStorage();
    notifyListeners();
  }

  void deleteVisit(int id) {
    _visits.removeWhere((v) => v.id == id);
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
