/// Pantallas del MainShell. Cada rol tiene su propia numeración, así que
/// navega siempre con estos nombres y nunca con números sueltos: el mismo
/// número abre pantallas distintas en el taller y en el portal del cliente.
abstract final class AdminScreen {
  static const inicio = 0;
  static const productos = 1;
  static const nuevaCotizacion = 2;
  static const cotizaciones = 3;
  static const clientes = 4;
  static const pagos = 5;
  static const agenda = 6;
  static const catalogo = 7;
  static const perfil = 8;
  static const detalleCotizacion = 9;
}

abstract final class ClientScreen {
  static const inicio = 0;
  static const catalogo = 1;
  static const pedidos = 2;
  static const perfil = 3;
}
