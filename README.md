# Aluminios API (.NET 10)

Backend de la app móvil **aluminios_app** (Flutter, en `C:\aluminios_app`). Se ejecuta por separado; la app se conecta por HTTP.

## Ejecutar

```bash
cd C:\aluminios_api

# Solo para emulador Android / Chrome / Windows en esta PC
dotnet run --project Aluminios.Api --launch-profile local

# Para un teléfono físico en la misma red Wi-Fi
dotnet run --project Aluminios.Api --launch-profile red-local
```

Comprobar que está vivo: `http://localhost:5000/` → `{"name":"Aluminios API","status":"ok"}`

### Conectar la app

| Dónde corre la app | URL que usa | Qué hacer |
|---|---|---|
| Emulador Android | `http://10.0.2.2:5000` | Nada, es el valor por defecto |
| Chrome / Windows | `http://localhost:5000` | Nada, es el valor por defecto |
| Teléfono físico | `http://<IP-de-la-PC>:5000` | Perfil `red-local`, abrir el puerto 5000 en el Firewall de Windows y ejecutar la app con `flutter run --dart-define=API_BASE_URL=http://<IP-de-la-PC>:5000` |

La IP de la PC se ve con `ipconfig` (Dirección IPv4 del adaptador Wi-Fi).

## Estructura

```
Aluminios.sln
├── Aluminios.Domain/          Entities/                      (por implementar)
├── Aluminios.Application/     DTOs/, Interfaces/, Services/  (por implementar)
├── Aluminios.Infrastructure/  Data/, Repositories/, Storage/ (por implementar)
└── Aluminios.Api/
    ├── Program.cs                         arranque + Store (guarda en Data/database.json)
    └── Controllers/ResourcesController.cs endpoints REST
```

## Endpoints

Recursos: `clientes`, `productos`, `cotizaciones`, `pedidos`, `trabajos`, `pagos`, `perfil`.

| Método | Ruta | Descripción |
|---|---|---|
| GET | `/api/{recurso}` | Listar |
| GET | `/api/{recurso}/{id}` | Obtener uno |
| POST | `/api/{recurso}` | Crear (409 si el id ya existe) |
| PUT | `/api/{recurso}/{id}` | Actualizar fusionando campos |
| DELETE | `/api/{recurso}/{id}` | Borrar |
| POST | `/api/{pedidos\|cotizaciones\|trabajos}/{id}/cancelar` | Mover a papelera (con sus pagos) |
| GET | `/api/papelera` | Ver papelera |
| POST | `/api/papelera/{id}/restaurar` | Restaurar |
| DELETE | `/api/papelera/{id}` | Borrar de la papelera |

Los IDs son `long`: la app los genera con `DateTime.now().millisecondsSinceEpoch` y el servidor los respeta.

## Asistente (Claude)

`POST /api/asistente/mensaje-whatsapp` redacta con Claude (`claude-opus-5-5`) el mensaje de WhatsApp de una cotización. La app envía los datos de la cotización y recibe `{ "mensaje": "..." }`.

La clave de API **solo vive en el servidor**, nunca en la app. Para activarlo, define la variable de entorno antes de arrancar:

```powershell
$env:ANTHROPIC_API_KEY = "sk-ant-..."     # solo para esta terminal
dotnet run --project Aluminios.Api --launch-profile red-local
```

O de forma permanente en Windows: `setx ANTHROPIC_API_KEY "sk-ant-..."` (abre una terminal nueva después).

Sin clave, el endpoint responde `503` y la app usa su plantilla de mensaje; el resto de la API funciona igual.

## Cuentas, sesiones y permisos

- `POST /api/auth/register` (cliente) y `POST /api/auth/login` devuelven `{ token, profile }`. Las contraseñas se guardan con PBKDF2-SHA256 + sal (tabla interna `cuentas`); nunca en texto plano.
- Todas las demás rutas `/api/*` exigen `Authorization: Bearer <token>` (si no, 401). Sesiones de 30 días; `POST /api/auth/logout` las revoca.
- `GET/PUT /api/auth/me` y `POST /api/auth/password` para el perfil del usuario.
- **Permisos:** el administrador ve y modifica todo. Un cliente solo lee su ficha, sus cotizaciones, pedidos, pagos y visitas (más el catálogo); solo puede crear cotizaciones y visitas a su nombre (las visitas quedan como `Solicitada` hasta que el taller las confirma) y editar su propia ficha. Borrar, cancelar, papelera y el asistente son solo del administrador.

### Contraseña del administrador

La cuenta `admin@aluminieros.com` se crea la **primera vez** que arranca el servidor, con la contraseña de `Admin:Password`:

- Desarrollo (perfiles `local` y `red-local`): `appsettings.Development.json`.
- Producción: variable de entorno `Admin__Password` (o `Admin__Email` para cambiar el correo). Si no se define, se genera una contraseña aleatoria y se muestra **una sola vez** en la consola.

Cambiar la configuración después no modifica una cuenta ya creada.
