# ALUMINIOS App (Flutter)

Aplicación móvil profesional desarrollada en Flutter para talleres de cancelería, aluminio y vidrio.
Migrada y optimizada a partir del prototipo React de Figma Make.

---

## 🚀 Cómo ejecutar la aplicación

Para ejecutar la aplicación en el navegador o en tu dispositivo móvil / emulador:

```bash
cd aluminios_app

# Obtener dependencias
flutter pub get

# Ejecutar en Google Chrome (Modo Web)
flutter run -d chrome

# O ejecutar en Windows Desktop
flutter run -d windows

# O si tienes un emulador o teléfono Android conectado:
flutter run -d android
```

### Backend

El backend es un proyecto separado en `C:\aluminios_api` (ver su `README.md`). Arráncalo antes de abrir la app:

```bash
cd C:\aluminios_api
dotnet run --project Aluminios.Api --launch-profile local       # emulador / Chrome / Windows
dotnet run --project Aluminios.Api --launch-profile red-local   # teléfono físico en la misma Wi-Fi
```

En un teléfono físico indica la IP de la PC al ejecutar la app:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.X.X:5000
```

Si el backend no está disponible, la app sigue funcionando con los datos guardados en el teléfono.

---

## 🔑 Credenciales de demostración

* **Administrador / Taller**:
  * **Correo:** `admin@aluminieros.com`
  * **Contraseña:** `123456`
* **Cliente:**
  * Puedes usar la pestaña **"Registrarme"** en la pantalla de bienvenida para crear una cuenta con tu nombre, teléfono y contraseña.

---

## 📁 Arquitectura del Proyecto

```
aluminios_app/lib/
├── core/
│   ├── constants.dart      # Tokens de diseño (Navy #1B3661, Blue #2248A0), paletas de estado
│   └── theme.dart          # Tema claro y tema oscuro real con tipografía Google Fonts (Inter)
├── models/
│   └── models.dart         # Product, Client, Quote, Payment, Visit, Work, Settings, Account
├── state/
│   └── app_state.dart      # Gestor de estado (ChangeNotifier) con persistencia local en SharedPreferences
├── widgets/
│   ├── top_bar.dart        # AppBar con logo y acciones
│   ├── app_drawer.dart     # Menú lateral para Admin y Cliente
│   ├── avatar_widget.dart  # Avatar dinámico con iniciales coloridas
│   ├── status_badge.dart   # Insignia de estado (Pendiente, Aprobada, En proceso, etc.)
│   └── ai_chat_sheet.dart  # Asistente IA para asesoría de cristal, perfiles y márgenes
├── screens/
│   ├── login_screen.dart   # Inicio de sesión y registro de cuentas
│   ├── main_shell.dart     # Scaffold principal con BottomNavigationBar según el rol
│   ├── admin/
│   │   ├── dashboard_screen.dart      # Métricas, gráfica de barras (fl_chart), gráfica dona
│   │   ├── products_screen.dart       # Catálogo de productos, filtros y alta/edición
│   │   ├── measure_screen.dart        # Medición con cámara, cuadrilátero interactivo y sensor LiDAR
│   │   ├── new_quote_screen.dart      # Cotizador con recomendación inteligente de IA
│   │   ├── quotes_screen.dart         # Listado con filtros por estado
│   │   ├── quote_detail_screen.dart   # Desglose, actualización de estado y envío por WhatsApp
│   │   ├── clients_screen.dart        # Directorio de clientes con llamada y WhatsApp directo
│   │   ├── payments_screen.dart       # Control de anticipos, saldo por cobrar e historial
│   │   ├── agenda_screen.dart         # Calendario mensual interactivo (table_calendar) y visitas del día
│   │   ├── catalog_screen.dart        # Catálogo visual de fotos de canceles, ventanas y domos
│   │   └── profile_screen.dart        # Datos de empresa, modo oscuro y configuración
│   └── client/
│       ├── client_home_screen.dart          # Dashboard de bienvenida y saldo del cliente
│       ├── client_catalog_screen.dart       # Catálogo público con solicitud de cotización o visita
│       ├── client_orders_screen.dart        # Historial de pedidos del cliente
│       └── client_order_detail_screen.dart  # Detalle de piezas y abonos de su pedido
└── main.dart               # Punto de entrada de la aplicación
```

---

## ✨ Mejoras añadidas respecto al prototipo web original:
1. **Persistencia Real**: Todos los datos (productos agregados, cotizaciones, anticipos, clientes, visitas) se guardan en el almacenamiento local (`SharedPreferences`), por lo que **no se pierden al cerrar la app**.
2. **Modo Oscuro Real**: Sin filtros CSS que inviertan fotos; utiliza temas nativos de Material 3.
3. **Validación y cálculos matemáticos precisos**: Cálculos automáticos de cuadriláteros para medición de vanos y cotizador con validación de márgenes.
4. **Integración con WhatsApp y Llamadas**: Enlaces nativos listos para enviar cotizaciones desglosadas al cliente con un solo toque.
