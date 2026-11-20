import '../core/input_rules.dart';

enum QuoteStatus {
  pendiente('Pendiente'),
  aprobada('Aprobada'),
  enProceso('En proceso'),
  completado('Completado'),
  entregado('Entregado'),
  cancelada('Cancelada');

  final String label;
  const QuoteStatus(this.label);

  static QuoteStatus fromString(String val) {
    return QuoteStatus.values.firstWhere(
      (e) => e.label.toLowerCase() == val.toLowerCase(),
      orElse: () => QuoteStatus.pendiente,
    );
  }
}

class Product {
  /// Precio por m² con el que se crea un producto nuevo (valor de prueba).
  static const double defaultPricePerM2 = 100;

  final int id;
  final String name;
  final String material;

  /// Precio por metro cuadrado. El taller cobra cada pieza por su área.
  final double price;
  final double margin;
  final String img;
  final double? width;
  final double? height;
  final double? depth;

  Product({
    required this.id,
    required this.name,
    required this.material,
    required this.price,
    this.margin = 25,
    required this.img,
    this.width,
    this.height,
    this.depth,
  });

  Product copyWith({
    int? id,
    String? name,
    String? material,
    double? price,
    double? margin,
    String? img,
    double? width,
    double? height,
    double? depth,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      material: material ?? this.material,
      price: price ?? this.price,
      margin: margin ?? this.margin,
      img: img ?? this.img,
      width: width ?? this.width,
      height: height ?? this.height,
      depth: depth ?? this.depth,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'material': material,
      'price': price,
      'margin': margin,
      'img': img,
      'width': width,
      'height': height,
      'depth': depth,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] is int ? map['id'] : int.parse(map['id'].toString()),
      name: map['name'] ?? '',
      material: map['material'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      margin: (map['margin'] as num?)?.toDouble() ?? 25.0,
      img: map['img'] ?? '',
      width: (map['width'] as num?)?.toDouble(),
      height: (map['height'] as num?)?.toDouble(),
      depth: (map['depth'] as num?)?.toDouble(),
    );
  }
}

class Client {
  final int id;
  final String name;
  final String phone;

  /// Domicilio o dirección de obra (opcional). Rellena la solicitud de visita.
  final String address;

  Client({
    required this.id,
    required this.name,
    required this.phone,
    this.address = '',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'phone': phone,
    'address': address,
  };

  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      id: map['id'] is int ? map['id'] : int.parse(map['id'].toString()),
      name: displayName('${map['name'] ?? ''}'),
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
    );
  }
}

class QuoteItem {
  final int productId;

  /// Medidas en cm.
  final double width;
  final double height;
  final double? depth;
  final int qty;

  /// Precio de UNA pieza (área × precio por m²). El servidor calcula los
  /// totales con este valor.
  final double unitPrice;

  /// Precio por m² con el que se calculó [unitPrice]. Es null en las
  /// cotizaciones hechas antes del cobro por m² (precio fijo por pieza).
  final double? pricePerM2;

  /// Nota de la pieza, p. ej. "Ventana de la cocina".
  final String note;

  QuoteItem({
    required this.productId,
    required this.width,
    required this.height,
    this.depth,
    required this.qty,
    required this.unitPrice,
    this.pricePerM2,
    this.note = '',
  });

  /// Pieza cobrada por área: el precio de una pieza es ancho × alto (en m²)
  /// por el precio del m², redondeado a centavos.
  factory QuoteItem.byArea({
    required int productId,
    required double width,
    required double height,
    double? depth,
    required int qty,
    required double pricePerM2,
    String note = '',
  }) {
    return QuoteItem(
      productId: productId,
      width: width,
      height: height,
      depth: depth,
      qty: qty,
      unitPrice: priceFor(width, height, pricePerM2),
      pricePerM2: pricePerM2,
      note: note,
    );
  }

  /// Área en m² de una pieza con medidas en cm.
  static double areaOf(double widthCm, double heightCm) =>
      widthCm * heightCm / 10000;

  /// Precio de una pieza de [widthCm] × [heightCm] a [pricePerM2] el m².
  static double priceFor(double widthCm, double heightCm, double pricePerM2) =>
      (areaOf(widthCm, heightCm) * pricePerM2 * 100).roundToDouble() / 100;

  /// Área de una pieza en m².
  double get area => areaOf(width, height);

  /// Área de todas las piezas de este renglón en m².
  double get totalArea => area * qty;

  double get subtotal => qty * unitPrice;

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'width': width,
      'height': height,
      'depth': depth,
      'qty': qty,
      'unitPrice': unitPrice,
      'pricePerM2': pricePerM2,
      'note': note,
    };
  }

  factory QuoteItem.fromMap(Map<String, dynamic> map) {
    return QuoteItem(
      productId: map['productId'] is int
          ? map['productId']
          : int.parse(map['productId'].toString()),
      width: (map['width'] as num?)?.toDouble() ?? 0.0,
      height: (map['height'] as num?)?.toDouble() ?? 0.0,
      depth: (map['depth'] as num?)?.toDouble(),
      qty: (map['qty'] as num?)?.toInt() ?? 1,
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0.0,
      pricePerM2: (map['pricePerM2'] as num?)?.toDouble(),
      note: map['note'] as String? ?? '',
    );
  }
}

class Quote {
  final int id;
  final String folio;
  final int clientId;
  final String date;
  final QuoteStatus status;
  final List<QuoteItem> items;
  final double discount;

  /// Fotos del avance o de la instalación que sube el taller
  /// (data:image/...;base64). El cliente las ve en el detalle de su pedido.
  final List<String> photos;

  /// Fecha estimada de entrega (aaaa-mm-dd) que pone el taller; vacía si
  /// aún no se ha definido.
  final String deliveryDate;

  Quote({
    required this.id,
    required this.folio,
    required this.clientId,
    required this.date,
    required this.status,
    required this.items,
    this.discount = 0.0,
    this.photos = const [],
    this.deliveryDate = '',
  });

  double get subtotal => items.fold(0.0, (acc, it) => acc + it.subtotal);
  double get discountAmount => (subtotal * discount) / 100.0;
  double get total => subtotal - discountAmount;

  Quote copyWith({
    int? id,
    String? folio,
    int? clientId,
    String? date,
    QuoteStatus? status,
    List<QuoteItem>? items,
    double? discount,
    List<String>? photos,
    String? deliveryDate,
  }) {
    return Quote(
      id: id ?? this.id,
      folio: folio ?? this.folio,
      clientId: clientId ?? this.clientId,
      date: date ?? this.date,
      status: status ?? this.status,
      items: items ?? this.items,
      discount: discount ?? this.discount,
      photos: photos ?? this.photos,
      deliveryDate: deliveryDate ?? this.deliveryDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'folio': folio,
      'clientId': clientId,
      'date': date,
      'status': status.label,
      'items': items.map((x) => x.toMap()).toList(),
      'discount': discount,
      'photos': photos,
      'deliveryDate': deliveryDate,
    };
  }

  /// Un solo formato de folio: "#0011" se muestra como "COT-0011".
  static String normalizeFolio(String folio) {
    final old = RegExp(r'^#(\d{1,6})$').firstMatch(folio.trim());
    return old == null ? folio : 'COT-${old.group(1)}';
  }

  /// Número consecutivo del folio, o null si no es de la forma COT-0001
  /// (los folios viejos con fecha y hora no cuentan para el consecutivo).
  static int? folioNumber(String folio) {
    final m = RegExp(r'^(?:COT-|#)(\d{1,6})$').firstMatch(folio.trim());
    return m == null ? null : int.parse(m.group(1)!);
  }

  factory Quote.fromMap(Map<String, dynamic> map) {
    return Quote(
      id: map['id'] is int ? map['id'] : int.parse(map['id'].toString()),
      folio: Quote.normalizeFolio('${map['folio'] ?? ''}'),
      clientId: map['clientId'] is int
          ? map['clientId']
          : int.parse(map['clientId'].toString()),
      date: map['date'] ?? '',
      status: QuoteStatus.fromString(map['status'] ?? 'Pendiente'),
      items:
          (map['items'] as List<dynamic>?)
              ?.map((x) => QuoteItem.fromMap(x as Map<String, dynamic>))
              .toList() ??
          [],
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      photos:
          (map['photos'] as List<dynamic>?)?.whereType<String>().toList() ??
          const [],
      deliveryDate: '${map['deliveryDate'] ?? ''}',
    );
  }
}

class Payment {
  final int id;
  final int quoteId;
  final String date;
  final double amount;
  final String method;

  Payment({
    required this.id,
    required this.quoteId,
    required this.date,
    required this.amount,
    required this.method,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'quoteId': quoteId,
    'date': date,
    'amount': amount,
    'method': method,
  };

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'] is int ? map['id'] : int.parse(map['id'].toString()),
      quoteId: map['quoteId'] is int
          ? map['quoteId']
          : int.parse(map['quoteId'].toString()),
      date: map['date'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      method: map['method'] ?? 'Efectivo',
    );
  }
}

class Visit {
  final int id;
  final String date;
  final String start;
  final String end;
  final String type; // 'Toma de medidas' | 'Instalación' | 'Cotización'
  final int clientId;
  final String place;

  /// 'Solicitada' (la pidió el cliente y falta confirmarla) o 'Confirmada'.
  /// "Realizada" no se guarda: se deduce de la fecha.
  final String status;

  static const requested = 'Solicitada';
  static const confirmed = 'Confirmada';

  /// La fecha ya pasó: se considera realizada.
  bool get isDone {
    final d = DateTime.tryParse(date);
    if (d == null) return false;
    final now = DateTime.now();
    return d.isBefore(DateTime(now.year, now.month, now.day));
  }

  bool get isRequested => !isDone && status == requested;

  /// Estado para mostrar: Realizada, Por confirmar o Confirmada.
  String get statusLabel => isDone
      ? 'Realizada'
      : isRequested
      ? 'Por confirmar'
      : 'Confirmada';

  Visit({
    required this.id,
    required this.date,
    required this.start,
    required this.end,
    required this.type,
    required this.clientId,
    required this.place,
    this.status = Visit.confirmed,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'date': date,
    'start': start,
    'end': end,
    'type': type,
    'clientId': clientId,
    'place': place,
    'status': status,
  };

  factory Visit.fromMap(Map<String, dynamic> map) {
    return Visit(
      id: map['id'] is int ? map['id'] : int.parse(map['id'].toString()),
      date: map['date'] ?? '',
      start: map['start'] ?? '',
      end: map['end'] ?? '',
      type: map['type'] ?? 'Toma de medidas',
      clientId: map['clientId'] is int
          ? map['clientId']
          : int.parse(map['clientId'].toString()),
      place: map['place'] ?? '',
      status: map['status'] ?? Visit.confirmed,
    );
  }
}

class Work {
  final int id;
  final String title;
  final String type;
  final String img;
  final bool custom;
  final List<String> photos;
  final double? width;
  final double? height;
  final double? depth;
  final String? notes;
  final int? clientId;

  Work({
    required this.id,
    required this.title,
    required this.type,
    required this.img,
    this.custom = false,
    this.photos = const [],
    this.width,
    this.height,
    this.depth,
    this.notes,
    this.clientId,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'type': type,
    'img': img,
    'custom': custom,
    'photos': photos,
    'width': width,
    'height': height,
    'depth': depth,
    'notes': notes,
    'clientId': clientId,
  };

  factory Work.fromMap(Map<String, dynamic> map) {
    return Work(
      id: map['id'] is int ? map['id'] : int.parse(map['id'].toString()),
      title: map['title'] ?? '',
      type: map['type'] ?? '',
      img: map['img'] ?? '',
      custom: map['custom'] ?? false,
      photos: List<String>.from(map['photos'] ?? const []),
      width: (map['width'] as num?)?.toDouble(),
      height: (map['height'] as num?)?.toDouble(),
      depth: (map['depth'] as num?)?.toDouble(),
      notes: map['notes'],
      clientId: map['clientId'] == null
          ? null
          : (map['clientId'] is int
                ? map['clientId']
                : int.parse(map['clientId'].toString())),
    );
  }
}

/// Configuración del taller. Los datos del negocio, de cotizaciones y de
/// pagos se guardan en el servidor ("perfil") y los ve también el cliente;
/// [dark], [ai] y [notifications] son preferencias de cada teléfono.
class Settings {
  // Negocio
  final String bizName;
  final String bizPhone;
  final String bizAddress;
  final String bizEmail;
  final String bizHours;
  final String profileDescription;

  // Dueño
  final String ownerName;
  final String avatarUrl;

  // Cotizaciones
  final int quoteValidityDays;
  final String quoteTerms;
  final double defaultPricePerM2;

  // Pagos por transferencia
  final String bankName;
  final String bankHolder;
  final String bankClabe;

  // Preferencias del teléfono
  final bool dark;
  final bool ai;
  final bool notifications;

  Settings({
    this.bizName = 'Aluminios AV',
    this.bizPhone = '999 340 9396',
    this.bizAddress = 'Calle 60 #450, Mérida, Yuc.',
    this.bizEmail = '',
    this.bizHours = '',
    this.profileDescription = '',
    this.ownerName = '',
    this.avatarUrl = '',
    this.quoteValidityDays = 15,
    this.quoteTerms = '',
    this.defaultPricePerM2 = Product.defaultPricePerM2,
    this.bankName = '',
    this.bankHolder = '',
    this.bankClabe = '',
    this.dark = false,
    this.ai = true,
    this.notifications = true,
  });

  /// Hay datos suficientes para pagar por transferencia.
  bool get hasBankInfo => bankClabe.isNotEmpty;

  /// Datos de transferencia en renglones, p. ej. para WhatsApp o el PDF.
  List<String> get bankLines => [
    if (bankName.isNotEmpty) 'Banco: $bankName',
    if (bankHolder.isNotEmpty) 'Titular: $bankHolder',
    if (bankClabe.isNotEmpty) 'CLABE: $bankClabe',
  ];

  Settings copyWith({
    String? bizName,
    String? bizPhone,
    String? bizAddress,
    String? bizEmail,
    String? bizHours,
    String? profileDescription,
    String? ownerName,
    String? avatarUrl,
    int? quoteValidityDays,
    String? quoteTerms,
    double? defaultPricePerM2,
    String? bankName,
    String? bankHolder,
    String? bankClabe,
    bool? dark,
    bool? ai,
    bool? notifications,
  }) {
    return Settings(
      bizName: bizName ?? this.bizName,
      bizPhone: bizPhone ?? this.bizPhone,
      bizAddress: bizAddress ?? this.bizAddress,
      bizEmail: bizEmail ?? this.bizEmail,
      bizHours: bizHours ?? this.bizHours,
      profileDescription: profileDescription ?? this.profileDescription,
      ownerName: ownerName ?? this.ownerName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      quoteValidityDays: quoteValidityDays ?? this.quoteValidityDays,
      quoteTerms: quoteTerms ?? this.quoteTerms,
      defaultPricePerM2: defaultPricePerM2 ?? this.defaultPricePerM2,
      bankName: bankName ?? this.bankName,
      bankHolder: bankHolder ?? this.bankHolder,
      bankClabe: bankClabe ?? this.bankClabe,
      dark: dark ?? this.dark,
      ai: ai ?? this.ai,
      notifications: notifications ?? this.notifications,
    );
  }

  /// Toma los datos del taller que vienen del servidor y conserva las
  /// preferencias de este teléfono.
  Settings withServerProfile(Map<String, dynamic> map) => Settings.fromMap({
    ...map,
    'dark': dark,
    'ai': ai,
    'notifications': notifications,
  });

  Map<String, dynamic> toMap() => {
    'bizName': bizName,
    'bizPhone': bizPhone,
    'bizAddress': bizAddress,
    'bizEmail': bizEmail,
    'bizHours': bizHours,
    'profileDescription': profileDescription,
    'ownerName': ownerName,
    'avatarUrl': avatarUrl,
    'quoteValidityDays': quoteValidityDays,
    'quoteTerms': quoteTerms,
    'defaultPricePerM2': defaultPricePerM2,
    'bankName': bankName,
    'bankHolder': bankHolder,
    'bankClabe': bankClabe,
    'dark': dark,
    'ai': ai,
    'notifications': notifications,
  };

  factory Settings.fromMap(Map<String, dynamic> map) {
    final defaults = Settings();
    String text(String key, String fallback) =>
        map[key] is String ? map[key] as String : fallback;
    return Settings(
      bizName: text('bizName', defaults.bizName),
      bizPhone: text('bizPhone', defaults.bizPhone),
      bizAddress: text('bizAddress', defaults.bizAddress),
      bizEmail: text('bizEmail', ''),
      bizHours: text('bizHours', ''),
      profileDescription: text('profileDescription', ''),
      ownerName: text('ownerName', ''),
      avatarUrl: text('avatarUrl', ''),
      quoteValidityDays:
          (map['quoteValidityDays'] as num?)?.toInt() ??
          defaults.quoteValidityDays,
      quoteTerms: text('quoteTerms', ''),
      defaultPricePerM2:
          (map['defaultPricePerM2'] as num?)?.toDouble() ??
          defaults.defaultPricePerM2,
      bankName: text('bankName', ''),
      bankHolder: text('bankHolder', ''),
      bankClabe: text('bankClabe', ''),
      dark: map['dark'] ?? false,
      ai: map['ai'] ?? true,
      notifications: map['notifications'] ?? true,
    );
  }
}

class AppSession {
  final String email;
  final int clientId;
  final String role; // 'admin' | 'client'

  /// Token de la sesión en el servidor.
  final String token;

  AppSession({
    required this.email,
    required this.clientId,
    required this.role,
    this.token = '',
  });

  bool get isAdmin => role == 'admin';

  Map<String, dynamic> toMap() => {
    'email': email,
    'clientId': clientId,
    'role': role,
    'token': token,
  };

  factory AppSession.fromMap(Map<String, dynamic> map) {
    return AppSession(
      email: map['email'] ?? '',
      clientId: map['clientId'] is int
          ? map['clientId']
          : int.parse(map['clientId'].toString()),
      role: map['role'] ?? 'client',
      token: map['token'] ?? '',
    );
  }
}

/// Datos del cliente con sesión, guardados en el teléfono para mostrarlos sin
/// conexión. Nunca se guarda la contraseña en texto: las cuentas creadas sin
/// servidor guardan solo su versión cifrada ([passwordHash]).
class Account {
  final int clientId;
  final String name;
  final String phone;
  final String email;
  final String address;

  /// Foto de perfil del cliente (data:image/...;base64). Solo en el teléfono.
  final String avatarUrl;

  /// Contraseña cifrada (PBKDF2) de una cuenta creada sin servidor; vacía en
  /// las cuentas del servidor.
  final String passwordHash;

  /// Qué avisos quiere recibir: pedidos (estado, cotización nueva, fotos),
  /// abonos y visitas.
  final bool noticeOrders;
  final bool noticePayments;
  final bool noticeVisits;

  Account({
    required this.clientId,
    required this.name,
    required this.phone,
    required this.email,
    this.address = '',
    this.avatarUrl = '',
    this.passwordHash = '',
    this.noticeOrders = true,
    this.noticePayments = true,
    this.noticeVisits = true,
  });

  Map<String, dynamic> toMap() => {
    'clientId': clientId,
    'name': name,
    'phone': phone,
    'email': email,
    'address': address,
    'avatarUrl': avatarUrl,
    'passwordHash': passwordHash,
    'noticeOrders': noticeOrders,
    'noticePayments': noticePayments,
    'noticeVisits': noticeVisits,
  };

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      clientId: map['clientId'] is int
          ? map['clientId']
          : int.parse(map['clientId'].toString()),
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      address: map['address'] ?? '',
      avatarUrl: map['avatarUrl'] ?? '',
      passwordHash: map['passwordHash'] ?? '',
      noticeOrders: map['noticeOrders'] != false,
      noticePayments: map['noticePayments'] != false,
      noticeVisits: map['noticeVisits'] != false,
    );
  }

  Account copyWith({
    String? name,
    String? phone,
    String? email,
    String? address,
    String? avatarUrl,
    String? passwordHash,
    bool? noticeOrders,
    bool? noticePayments,
    bool? noticeVisits,
  }) {
    return Account(
      clientId: clientId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      passwordHash: passwordHash ?? this.passwordHash,
      noticeOrders: noticeOrders ?? this.noticeOrders,
      noticePayments: noticePayments ?? this.noticePayments,
      noticeVisits: noticeVisits ?? this.noticeVisits,
    );
  }
}

/// Aviso dentro de la app. Para el cliente: cambios de sus pedidos,
/// solicitudes, abonos, fotos y visitas. Para el taller: solicitudes nuevas
/// y respuestas de los clientes a sus cotizaciones. Se genera al actualizar
/// los datos del servidor.
class AppNotice {
  final int id;
  final String text;
  final String date; // ISO 8601
  final int? quoteId;
  final int? requestId;
  final bool read;

  AppNotice({
    required this.id,
    required this.text,
    required this.date,
    this.quoteId,
    this.requestId,
    this.read = false,
  });

  AppNotice markRead() => AppNotice(
    id: id,
    text: text,
    date: date,
    quoteId: quoteId,
    requestId: requestId,
    read: true,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'text': text,
    'date': date,
    'quoteId': quoteId,
    'requestId': requestId,
    'read': read,
  };

  factory AppNotice.fromMap(Map<String, dynamic> map) => AppNotice(
    id: (map['id'] as num).toInt(),
    text: map['text'] ?? '',
    date: map['date'] ?? '',
    quoteId: (map['quoteId'] as num?)?.toInt(),
    requestId: (map['requestId'] as num?)?.toInt(),
    read: map['read'] == true,
  );
}

/// Solicitud de cotización que hace el cliente, describiendo lo que necesita
/// o pidiendo una pieza del catálogo. El taller la acepta o la rechaza y,
/// con esa información, arma la cotización con precio.
class QuoteRequest {
  /// Recién enviada: el taller aún no la revisa.
  static const sent = 'Enviada';
  static const accepted = 'Aceptada';
  static const rejected = 'Rechazada';

  /// El taller ya hizo la cotización ([quoteId]).
  static const quoted = 'Cotizada';

  /// Tipos que el cliente puede elegir en el formulario.
  static const types = [
    'Ventana',
    'Puerta',
    'Cancel de baño',
    'Barandal',
    'Domo',
    'Otro',
  ];

  final int id;
  final int clientId;
  final String date; // dd/mm/aaaa, como las cotizaciones
  final String type;
  final String description;

  /// Medidas aproximadas en cm, si el cliente las sabe.
  final double? width;
  final double? height;
  final int qty;

  /// Pieza del catálogo, si la pidió desde ahí.
  final int? productId;

  /// Fotos del lugar (data:image/...;base64).
  final List<String> photos;

  /// Quiere que el taller vaya a medir.
  final bool wantsVisit;
  final String status;

  /// Motivo del rechazo, para el cliente.
  final String reason;
  final int? quoteId;

  QuoteRequest({
    required this.id,
    required this.clientId,
    required this.date,
    required this.type,
    required this.description,
    this.width,
    this.height,
    this.qty = 1,
    this.productId,
    this.photos = const [],
    this.wantsVisit = false,
    this.status = sent,
    this.reason = '',
    this.quoteId,
  });

  bool get isNew => status == sent;

  /// Sigue abierta: falta que el taller mande la cotización o la rechace.
  bool get isOpen => status == sent || status == accepted;

  /// Estado como lo ve el cliente.
  String get clientLabel => switch (status) {
    sent => 'Enviada',
    accepted => 'Aceptada · en preparación',
    rejected => 'No aceptada',
    quoted => 'Cotización lista',
    _ => status,
  };

  QuoteRequest copyWith({String? status, String? reason, int? quoteId}) =>
      QuoteRequest(
        id: id,
        clientId: clientId,
        date: date,
        type: type,
        description: description,
        width: width,
        height: height,
        qty: qty,
        productId: productId,
        photos: photos,
        wantsVisit: wantsVisit,
        status: status ?? this.status,
        reason: reason ?? this.reason,
        quoteId: quoteId ?? this.quoteId,
      );

  Map<String, dynamic> toMap() => {
    'id': id,
    'clientId': clientId,
    'date': date,
    'type': type,
    'description': description,
    'width': width,
    'height': height,
    'qty': qty,
    'productId': productId,
    'photos': photos,
    'wantsVisit': wantsVisit,
    'status': status,
    'reason': reason,
    'quoteId': quoteId,
  };

  factory QuoteRequest.fromMap(Map<String, dynamic> map) => QuoteRequest(
    id: (map['id'] as num).toInt(),
    clientId: (map['clientId'] as num).toInt(),
    date: map['date'] ?? '',
    type: map['type'] ?? 'Otro',
    description: map['description'] ?? '',
    width: (map['width'] as num?)?.toDouble(),
    height: (map['height'] as num?)?.toDouble(),
    qty: (map['qty'] as num?)?.toInt() ?? 1,
    productId: (map['productId'] as num?)?.toInt(),
    photos: List<String>.from(map['photos'] ?? const []),
    wantsVisit: map['wantsVisit'] == true,
    status: map['status'] ?? sent,
    reason: map['reason'] ?? '',
    quoteId: (map['quoteId'] as num?)?.toInt(),
  );
}
