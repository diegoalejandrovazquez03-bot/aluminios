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
  final int id;
  final String name;
  final String material;
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

  Client({required this.id, required this.name, required this.phone});

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'phone': phone};

  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      id: map['id'] is int ? map['id'] : int.parse(map['id'].toString()),
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
    );
  }
}

class QuoteItem {
  final int productId;
  final double width;
  final double height;
  final double? depth;
  final int qty;
  final double unitPrice;

  QuoteItem({
    required this.productId,
    required this.width,
    required this.height,
    this.depth,
    required this.qty,
    required this.unitPrice,
  });

  double get subtotal => qty * unitPrice;

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'width': width,
      'height': height,
      'depth': depth,
      'qty': qty,
      'unitPrice': unitPrice,
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

  Quote({
    required this.id,
    required this.folio,
    required this.clientId,
    required this.date,
    required this.status,
    required this.items,
    this.discount = 0.0,
    this.photos = const [],
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
    };
  }

  factory Quote.fromMap(Map<String, dynamic> map) {
    return Quote(
      id: map['id'] is int ? map['id'] : int.parse(map['id'].toString()),
      folio: map['folio'] ?? '',
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

class Settings {
  final String bizName;
  final String bizPhone;
  final String bizAddress;
  final bool dark;
  final bool ai;
  final bool notifications;
  final String avatarUrl;
  final String profileDescription;

  Settings({
    this.bizName = 'Aluminios AV',
    this.bizPhone = '999 340 9396',
    this.bizAddress = 'Calle 60 #450, Mérida, Yuc.',
    this.dark = false,
    this.ai = true,
    this.notifications = true,
    this.avatarUrl = '',
    this.profileDescription = '',
  });

  Settings copyWith({
    String? bizName,
    String? bizPhone,
    String? bizAddress,
    bool? dark,
    bool? ai,
    bool? notifications,
    String? avatarUrl,
    String? profileDescription,
  }) {
    return Settings(
      bizName: bizName ?? this.bizName,
      bizPhone: bizPhone ?? this.bizPhone,
      bizAddress: bizAddress ?? this.bizAddress,
      dark: dark ?? this.dark,
      ai: ai ?? this.ai,
      notifications: notifications ?? this.notifications,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      profileDescription: profileDescription ?? this.profileDescription,
    );
  }

  Map<String, dynamic> toMap() => {
    'bizName': bizName,
    'bizPhone': bizPhone,
    'bizAddress': bizAddress,
    'dark': dark,
    'ai': ai,
    'notifications': notifications,
    'avatarUrl': avatarUrl,
    'profileDescription': profileDescription,
  };

  factory Settings.fromMap(Map<String, dynamic> map) {
    return Settings(
      bizName: map['bizName'] ?? 'Aluminios AV',
      bizPhone: map['bizPhone'] ?? '999 340 9396',
      bizAddress: map['bizAddress'] ?? 'Calle 60 #450, Mérida, Yuc.',
      dark: map['dark'] ?? false,
      ai: map['ai'] ?? true,
      notifications: map['notifications'] ?? true,
      avatarUrl: map['avatarUrl'] ?? '',
      profileDescription: map['profileDescription'] ?? '',
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

  /// Foto de perfil del cliente (data:image/...;base64). Solo en el teléfono.
  final String avatarUrl;

  /// Contraseña cifrada (PBKDF2) de una cuenta creada sin servidor; vacía en
  /// las cuentas del servidor.
  final String passwordHash;

  Account({
    required this.clientId,
    required this.name,
    required this.phone,
    required this.email,
    this.avatarUrl = '',
    this.passwordHash = '',
  });

  Map<String, dynamic> toMap() => {
    'clientId': clientId,
    'name': name,
    'phone': phone,
    'email': email,
    'avatarUrl': avatarUrl,
    'passwordHash': passwordHash,
  };

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      clientId: map['clientId'] is int
          ? map['clientId']
          : int.parse(map['clientId'].toString()),
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      avatarUrl: map['avatarUrl'] ?? '',
      passwordHash: map['passwordHash'] ?? '',
    );
  }

  Account copyWith({
    String? name,
    String? phone,
    String? email,
    String? avatarUrl,
    String? passwordHash,
  }) {
    return Account(
      clientId: clientId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      passwordHash: passwordHash ?? this.passwordHash,
    );
  }
}

/// Aviso para el cliente dentro de la app (cambio de estado, abono, fotos,
/// visita confirmada). Se genera al actualizar los datos del servidor.
class AppNotice {
  final int id;
  final String text;
  final String date; // ISO 8601
  final int? quoteId;
  final bool read;

  AppNotice({
    required this.id,
    required this.text,
    required this.date,
    this.quoteId,
    this.read = false,
  });

  AppNotice markRead() =>
      AppNotice(id: id, text: text, date: date, quoteId: quoteId, read: true);

  Map<String, dynamic> toMap() => {
    'id': id,
    'text': text,
    'date': date,
    'quoteId': quoteId,
    'read': read,
  };

  factory AppNotice.fromMap(Map<String, dynamic> map) => AppNotice(
    id: (map['id'] as num).toInt(),
    text: map['text'] ?? '',
    date: map['date'] ?? '',
    quoteId: (map['quoteId'] as num?)?.toInt(),
    read: map['read'] == true,
  );
}
