# Manual de Integración Frontend–Backend
## XpressRides (Decarrerita) — UNEG, Sistemas de Base de Datos I
**Versión:** 2.0 — 25 de junio de 2026  
**Rama backend:** `integration/backend` → `develop`  
**Servidor:** `http://localhost:8080`  
**Autor:** Johanna Guédez

---

## Cómo funciona la comunicación

Todo el frontend usa `api.js` — un módulo centralizado ya escrito por Freddy. No necesitas escribir `fetch()` directamente. Siempre usa `fetchAPI()`.

```javascript
// Patrón general — SIEMPRE así:
const response = await fetchAPI('/endpoint-aqui', {
    method: 'POST',      // GET, POST, PUT, PATCH, DELETE
    body: JSON.stringify({ campo: valor })
});
// response.data contiene la información útil
// response.message contiene texto para mostrar al usuario
// Si el backend falla, fetchAPI lanza un Error automáticamente
```

El token JWT se agrega automáticamente si el usuario está logueado. No tienes que agregar headers manualmente.

---

## Módulo 1 — Autenticación

### 1.1 Login

**Pantalla:** `login.html` / `login.js`

```javascript
// Enviar al hacer submit del formulario
const response = await fetchAPI('/auth/login', {
    method: 'POST',
    body: JSON.stringify({
        correo: 'laurap',      // o 'carlosr' para el chofer
        password: 'password'
    })
});

// Guardar sesión en localStorage
localStorage.setItem('xpressUsuario', JSON.stringify(response.data));

// response.data contiene:
// {
//   id: 5,
//   username: "laurap",
//   nombre: "Laura",
//   apellido: "Pérez",
//   rol: "cliente",          // "cliente" | "chofer" | "administrador" | "personal_admin"
//   token: "eyJhbG...",      // JWT — fetchAPI lo usa automáticamente
//   refreshToken: "eyJhbG...",
//   saldoUsd: 20.00,         // solo si rol = "cliente"
//   esEstudiante: true        // solo si rol = "cliente"
// }

// Redirigir según rol
const rol = response.data.rol;
if (rol === 'cliente')         window.location.href = '/views/cliente-dashboard.html';
else if (rol === 'chofer')     window.location.href = '/views/chofer-dashboard.html';
else                           window.location.href = '/views/admin-dashboard.html';
```

**Usuarios de prueba disponibles en la BD:**
| Usuario | Contraseña | Rol | Notas |
|---|---|---|---|
| `laurap` | `password` | cliente | Saldo $20, estudiante, primer viaje gratis disponible |
| `carlosr` | `password` | chofer | Habilitado, disponible, vehículo activo |

---

### 1.2 Registro de Cliente

**Pantalla:** `registro.html` / `registro.js`

```javascript
// El formulario de cliente envía estos campos:
const response = await fetchAPI('/auth/register-cliente', {
    method: 'POST',
    body: JSON.stringify({
        nombre: 'María',
        apellido: 'González',
        cedula: 'V-20123456',
        telefono: '0414-5556677',
        password: 'mipassword1',
        esEstudiante: true       // true si marcó el checkbox de estudiante UNEG
    })
});

// El username queda igual a la cédula → el cliente hace login con su cédula
// response.data tiene el mismo formato que el login (con token incluido)
localStorage.setItem('xpressUsuario', JSON.stringify(response.data));
```

> **Importante:** El login posterior de este usuario se hace con `correo: "V-20123456"` (la cédula que usó al registrarse).

---

### 1.3 Registro de Chofer (flujo especial — 3 pasos)

El registro del chofer es un proceso de 3 pasos que NO se completa en un solo formulario:

**Paso 1 — Crear cuenta básica** (`/api/auth/registro`)
```javascript
await fetchAPI('/auth/registro', {
    method: 'POST',
    body: JSON.stringify({
        name: 'Carlos',
        lastName: 'Rodríguez',
        ci: 'V-15000001',
        phone: '0416-1234567',
        username: 'carlosr2',
        email: 'carlosr2@mail.com',
        password: 'password123',
        role: 'chofer',
        bankId: 1,           // ID del banco (obtenido de GET /api/bancos)
        accountNumber: '01750123456789012345'
    })
});
```

**Paso 2 — Registrar vehículo** (después de login como chofer, `POST /api/vehiculo/registrar`)
```javascript
await fetchAPI('/vehiculo/registrar', {
    method: 'POST',
    body: JSON.stringify({
        plate: 'ABC-123',
        brand: 'Toyota',
        model: 'Corolla',
        year: 2020,
        color: 'Blanco'
    })
});
```

**Paso 3 — Esperar habilitación por el admin**
El chofer NO puede recibir viajes hasta que un administrador registre:
- Evaluación psicológica (mínimo 73/100) → `POST /api/choferes/{id}/evaluacion-psicologica`
- Revisión vehicular (mínimo 65/100) → `POST /api/vehiculos/{id}/revision`

Cuando ambas aprueban, `habilitado` cambia a `true` automáticamente.

---

### 1.4 Cerrar Sesión

```javascript
await fetchAPI('/auth/cerrar-sesion', { method: 'POST' });
localStorage.removeItem('xpressUsuario');
window.location.href = '/views/login.html';
```

---

## Módulo 2 — Dashboard del Cliente

### 2.1 Cargar Zonas (mapa y selects)

**Pantalla:** `cliente-dashboard.html` / `dashboard.js`  
Ya funciona en el código actual de Freddy.

```javascript
const response = await fetchAPI('/zonas');
// response.data = array de zonas:
// [{id, name, parish, latitude, longitude, active}, ...]
// Ejemplo: {id: 1, name: "UNEG Sede Atlántico", parish: "Unare", latitude: 8.289, longitude: -62.714}
```

### 2.2 Preview de Tarifa (NUEVO — mostrar antes de confirmar)

Este endpoint calcula el costo estimado sin crear el viaje ni cobrar nada. Úsalo para mostrarle al usuario cuánto va a costar antes de que confirme.

```javascript
const preview = await fetchAPI('/traslados/calcular-tarifa', {
    method: 'POST',
    body: JSON.stringify({
        idZoneOrigin: 3,       // ID de la zona de origen seleccionada
        idZoneDestiny: 12,     // ID de la zona de destino seleccionada
        passengerCount: 1      // Entre 1 y 3 pasajeros
    })
});

// preview.data contiene:
// {
//   distanciaKm: 8.3,
//   tarifaBase: 1.00,
//   costoDistancia: 3.74,
//   recargoHoraPico: 1.20,           // factor multiplicador, no monto
//   recargoNocturnoFinSemana: 0.00,  // 1.50 si es noche o fin de semana
//   descuentoAplicado: "ninguno",    // "primerViaje" | "estudiantil" | "cupon" | "ninguno"
//   costoFinalUsd: 5.69,
//   costoFinalVes: 207.10,
//   tasaBcvId: 2,
//   primerViajeGratis: false,
//   descuentoEstudiantil: true
// }

// Mostrar al usuario antes de confirmar:
mostrarResumenTarifa(preview.data);
```

### 2.3 Solicitar Viaje (confirmar)

```javascript
// Payload que ya envía dashboard.js — CORRECTO como está:
const response = await fetchAPI('/solicitar-viaje', {
    method: 'POST',
    body: JSON.stringify({
        clienteId: usuario.id,           // ignorado por el backend (usa JWT), inofensivo
        zonaOrigenId: parseInt(origen),  // acepta este nombre ✅
        zonaDestinoId: parseInt(destino), // acepta este nombre ✅
        cantPasajeros: parseInt(pasajeros), // acepta este nombre ✅
        codigoCupon: null                 // null si no tiene cupón
    })
});

// response.data contiene los datos del traslado creado (TripResponse)
// incluyendo: id del traslado, costo, chofer asignado, estado: "solicitado"
```

> **Reglas de negocio que el backend aplica automáticamente:**
> - Si `primer_viaje_usado = false` → el viaje cuesta $0.00 al cliente (la empresa subsidia)
> - Si `es_estudiante = true` y el destino es UNEG Sede Atlántico, UNEG Sede Villa Asia o UNEXPO → 30% de descuento
> - Si el cliente no tiene saldo suficiente → el SP lanza un error y el viaje NO se crea

---

## Módulo 3 — Perfil del Cliente

### 3.1 Ver Perfil

```javascript
const response = await fetchAPI('/cliente/perfil');
// response = CustomerProfileResponse (objeto directo, sin wrapper {success,data,message})
// Campos: nombre, apellido, email, telefono, saldo, esEstudiante, etc.
```

> ⚠️ Este endpoint de Eliuber devuelve el objeto directo, sin el wrapper `{success, data, message}`. No usar `fetchAPI` directamente — hacer fetch manual o manejar el caso:

```javascript
// Forma segura de leer el perfil:
const usuario = JSON.parse(localStorage.getItem('xpressUsuario'));
// Los datos básicos (nombre, apellido, saldo, esEstudiante) ya están en localStorage
// desde el login. Para recargar el saldo actualizado, usar:
const response = await fetchAPI('/cliente/perfil');
```

### 3.2 Editar Perfil

```javascript
await fetchAPI('/users/' + usuario.id, {
    method: 'PUT',
    body: JSON.stringify({
        name: 'Nuevo Nombre',      // opcional — omitir si no cambia
        lastName: 'Nuevo Apellido',
        email: 'nuevo@mail.com',
        phone: '0414-9999999',
        ci: 'V-20000001'
    })
});
```

### 3.3 Ver Cupones Disponibles

```javascript
const response = await fetchAPI('/cliente/cupones');
// Devuelve los cupones del cliente que aún no han sido usados
// [{id, coupon: {code, type, discountUsd}, used: false, ...}]
```

---

## Módulo 4 — Historial de Viajes del Cliente

### 4.1 Historial propio (recomendado)

```javascript
// OPCIÓN A — Endpoint específico del cliente (más eficiente):
const response = await fetchAPI('/cliente/traslados');
// Devuelve SOLO los viajes del cliente autenticado

// OPCIÓN B — Lo que hace cliente-record.js actualmente (filtra la vista global):
const response = await fetchAPI('/reportes/historial-traslados');
const misViajes = response.data.filter(v => v.customerId === usuario.id);
// Funciona pero trae datos de todos los usuarios — no ideal para producción
```

### 4.2 Calificar un Viaje Completado

```javascript
await fetchAPI('/cliente/traslados/' + idTraslado + '/calificar', {
    method: 'PUT',
    body: JSON.stringify({
        rating: 5,          // 1 a 5 estrellas
        comment: 'Excelente servicio'  // opcional
    })
});
```

### 4.3 Ver Factura de un Viaje

```javascript
const response = await fetchAPI('/facturas/' + idTraslado);
// response.data contiene:
// {
//   montoUsd: 5.69,
//   montoVes: 207.10,
//   igtfUsd: 0.17,       // 3% sobre el monto en USD
//   totalUsd: 5.86,
//   fechaEmision: "2026-06-25T14:30:00",
//   numeroControl: "XR-000123"
// }
```

---

## Módulo 5 — Recarga de Saldo

**Pantalla:** `cliente-recharge.html` / `cliente-recharge.js`  
Ya funciona en el código actual de Freddy.

```javascript
// Paso 1 — Obtener tasa BCV del día (ya implementado en cliente-recharge.js)
const responseTasa = await fetchAPI('/tasa-bcv/vigente');
const tasa = responseTasa.data.rateVesToUsd; // bolívares por dólar

// Paso 2 — Obtener lista de bancos (ya implementado)
const responseBancos = await fetchAPI('/bancos');
// responseBancos.data = [{id, name, active}, ...]

// Paso 3 — Registrar la recarga (ya implementado)
await fetchAPI('/recargas', {
    method: 'POST',
    body: JSON.stringify({
        montoUsd: 10.00,
        montoVes: 10.00 * tasa,
        referencia: 'TRF-20260625-001',
        idBanco: 3,          // ID del banco de origen
        idCliente: usuario.id,
        idTasa: responseTasa.data.id
    })
});
```

---

## Módulo 6 — Notificaciones

**Pantalla:** todas las páginas autenticadas / `notifications.js`  
Ya funciona en el código actual de Freddy.

```javascript
// Cargar notificaciones pendientes del usuario
const response = await fetchAPI('/reportes/notificaciones');
const misNotificaciones = response.data.filter(n => n.userId === usuario.id);
// [{id, message, type, date, userId, read}, ...]
```

---

## Módulo 7 — Panel del Chofer (pendiente de crear)

### 7.1 Ver Estado del Chofer

```javascript
const response = await fetchAPI('/chofer/estado');
// Devuelve DriverStatusResponse — objeto directo (sin wrapper):
// {habilitado, disponible, nombreChofer, vehiculo: {...}}
```

### 7.2 Cambiar Disponibilidad

```javascript
// El chofer activa/desactiva su disponibilidad desde su panel
await fetchAPI('/chofer/disponibilidad', {
    method: 'PUT',
    body: JSON.stringify({ available: true })  // true = disponible, false = no disponible
});
```

### 7.3 Ver Viajes Asignados

```javascript
const response = await fetchAPI('/chofer/traslados');
// Lista de traslados asignados al chofer autenticado
```

### 7.4 Avanzar Estado del Viaje

Este es el flujo principal del chofer. Los estados van en orden estricto:

```
solicitado → aceptado → en_camino → chofer_llego → en_progreso → completado
```

```javascript
// El chofer avanza el estado usando su endpoint:
await fetchAPI('/chofer/traslados/' + idTraslado + '/estado', {
    method: 'PUT',
    body: JSON.stringify({ status: 'en_camino' })
});

// Significado de cada estado:
// "aceptado"     → El chofer aceptó el viaje
// "en_camino"    → El chofer salió hacia el cliente
// "chofer_llego" → El chofer llegó al punto de recogida
// "en_progreso"  → El viaje comenzó (cliente subió al vehículo)
// "completado"   → Viaje terminado (descuenta saldo, paga al chofer)
```

> **También existe** `PATCH /api/viajes/{id}/estado` con body `{"nuevoEstado": "en_camino"}` — funciona igual, es el endpoint original de Johanna.

### 7.5 Cancelar un Viaje

```javascript
await fetchAPI('/chofer/traslados/' + idTraslado + '/cancelar', {
    method: 'PUT',
    body: JSON.stringify({ motivo: 'Falla mecánica del vehículo' })
});
```

---

## Módulo 8 — Panel Administrativo (pendiente de crear)

### 8.1 Habilitar/Inhabilitar Chofer Manualmente

```javascript
// Solo admin o personal_admin pueden usar esto:
await fetchAPI('/chofer/habilitar/' + driverId, {
    method: 'PUT',
    body: JSON.stringify({ enabled: true })  // false para inhabilitar
});
```

### 8.2 Registrar Evaluación Psicológica del Chofer

```javascript
await fetchAPI('/choferes/' + driverId + '/evaluacion-psicologica', {
    method: 'POST',
    body: JSON.stringify({
        score: 85,          // calificación 0–100 (mínimo aprobatorio: 73)
        evaluatorName: 'Dra. Sánchez',
        notes: 'Aprobado sin observaciones'
    })
});
// Si la evaluación aprueba Y el vehículo ya tiene revisión aprobada → habilitado = true automáticamente
```

### 8.3 Registrar Revisión Vehicular

```javascript
await fetchAPI('/vehiculos/' + vehicleId + '/revision', {
    method: 'POST',
    body: JSON.stringify({
        score: 78,          // calificación 0–100 (mínimo: 65)
        technicianName: 'Ing. Pérez',
        notes: 'Apto con observaciones menores'
    })
});
// Si la revisión aprueba Y la evaluación psicológica ya aprobó → habilitado = true automáticamente
```

### 8.4 Registrar Tasa BCV del Día

```javascript
// Solo admin puede hacer esto — hacerlo cada día hábil:
await fetchAPI('/tasa-bcv', {
    method: 'POST',
    body: JSON.stringify({
        effectiveDate: '2026-06-25',    // fecha de vigencia (YYYY-MM-DD)
        rateVesToUsd: 36.45             // bolívares por dólar según BCV
    })
});
```

### 8.5 Crear y Asignar Cupones

```javascript
// Crear cupón:
const resp = await fetchAPI('/cupones', {
    method: 'POST',
    body: JSON.stringify({
        code: 'BIENVENIDA2026',
        type: 'bienvenida',         // "bienvenida" | "estudiante" | "promocional"
        discountUsd: 3.00,
        maxDistanceKm: 15           // opcional — null = sin límite de distancia
    })
});
const couponId = resp.data.id;

// Asignar a un cliente específico:
await fetchAPI('/cupones/' + couponId + '/asignar/' + clienteId, {
    method: 'POST'
});
```

### 8.6 Registrar Pago a Chofer

```javascript
await fetchAPI('/pagos-chofer', {
    method: 'POST',
    body: JSON.stringify({
        driverId: 3,
        amountUsd: 45.50,
        reference: 'TRF-20260625-007',
        bankId: 2,
        paymentDate: '2026-06-25'
    })
});
```

### 8.7 Reportes Administrativos

Todos devuelven `{success, data, message}` con un array en `data`:

```javascript
await fetchAPI('/reportes/historial-traslados');   // todos los viajes
await fetchAPI('/reportes/ganancias');             // ganancias de la empresa
await fetchAPI('/reportes/pagos-chofer');          // pagos realizados a choferes
await fetchAPI('/reportes/pendientes-pago');       // choferes con saldo pendiente
await fetchAPI('/reportes/cancelados');            // viajes cancelados
await fetchAPI('/reportes/facturas');              // facturas emitidas
await fetchAPI('/reportes/notificaciones');        // notificaciones del sistema
```

---

## Referencia rápida — Todos los Endpoints

### Públicos (sin login)
| Método | URL | Descripción |
|---|---|---|
| POST | `/api/auth/iniciar-sesion` o `/api/auth/login` | Login |
| POST | `/api/auth/registro` | Registro completo (campos en inglés) |
| POST | `/api/auth/register-cliente` | Registro de cliente (campos en español, para el frontend) |
| GET | `/api/zonas` | Zonas activas con coordenadas GPS |
| GET | `/api/bancos` | Bancos activos |

### Cliente (requiere login con rol `cliente`)
| Método | URL | Descripción |
|---|---|---|
| POST | `/api/solicitar-viaje` o `/api/traslado/solicitar` | Solicitar traslado |
| POST | `/api/traslados/calcular-tarifa` | Preview de tarifa (sin crear viaje) |
| GET | `/api/cliente/perfil` | Ver perfil |
| PUT | `/api/cliente/perfil` | Actualizar perfil |
| PUT | `/api/users/{id}` | Actualizar datos básicos |
| GET | `/api/cliente/traslados` | Mis viajes |
| GET | `/api/cliente/traslados/{id}` | Detalle de un viaje |
| PUT | `/api/cliente/traslados/{id}/calificar` | Calificar viaje |
| PUT | `/api/cliente/traslados/{id}/cancelar` | Cancelar viaje |
| GET | `/api/cliente/cupones` | Mis cupones disponibles |
| POST | `/api/recargas` | Recargar saldo |
| GET | `/api/recargas/cliente/{id}` | Historial de recargas |
| GET | `/api/tasa-bcv/vigente` | Tasa BCV del día |
| GET | `/api/facturas/{trasladoId}` | Factura de un viaje |

### Chofer (requiere login con rol `chofer`)
| Método | URL | Descripción |
|---|---|---|
| GET | `/api/chofer/estado` | Mi estado y datos |
| PUT | `/api/chofer/disponibilidad` | Activar/desactivar disponibilidad |
| GET | `/api/chofer/traslados` | Viajes asignados |
| GET | `/api/chofer/traslados/{id}` | Detalle de un viaje |
| PUT | `/api/chofer/traslados/{id}/estado` | Avanzar estado del viaje |
| PUT | `/api/chofer/traslados/{id}/cancelar` | Cancelar viaje |
| POST | `/api/vehiculo/registrar` | Registrar vehículo |
| PATCH | `/api/viajes/{id}/estado` | Avanzar estado (endpoint alternativo) |

### Admin / Personal Admin (requiere login con rol admin)
| Método | URL | Descripción |
|---|---|---|
| PUT | `/api/chofer/habilitar/{driverId}` | Habilitar/inhabilitar chofer |
| POST | `/api/choferes/{id}/evaluacion-psicologica` | Registrar evaluación psicológica |
| POST | `/api/vehiculos/{id}/revision` | Registrar revisión vehicular |
| POST | `/api/vehiculo/revision` | Registrar revisión (endpoint alternativo) |
| POST | `/api/tasa-bcv` | Registrar tasa BCV |
| POST | `/api/cupones` | Crear cupón |
| POST | `/api/cupones/{id}/asignar/{clienteId}` | Asignar cupón a cliente |
| POST | `/api/pagos-chofer` | Registrar pago a chofer |
| GET | `/api/pagos-chofer/chofer/{id}` | Historial de pagos de un chofer |
| GET | `/api/reportes/historial-traslados` | Reporte de todos los viajes |
| GET | `/api/reportes/ganancias` | Ganancias de la empresa |
| GET | `/api/reportes/pagos-chofer` | Pagos por chofer |
| GET | `/api/reportes/pendientes-pago` | Pendientes de pago |
| GET | `/api/reportes/cancelados` | Traslados cancelados |
| GET | `/api/reportes/facturas` | Facturas emitidas |
| GET | `/api/reportes/notificaciones` | Notificaciones pendientes |
| GET | `/api/tasa-bcv/historial` | Historial de tasas BCV |
| POST | `/api/auth/refrescar` | Renovar token JWT |
| POST | `/api/auth/cerrar-sesion` | Logout |
| POST | `/api/auth/cambiar-contrasena` | Cambiar contraseña |

---

## Cómo probar el sistema paso a paso

### Prueba 1 — Login como cliente
1. Abrir `http://localhost:8080/views/login.html`
2. Usuario: `laurap`, contraseña: `password`
3. Debe redirigir al dashboard del cliente
4. En consola del navegador (F12 → Console): `JSON.parse(localStorage.getItem('xpressUsuario'))` debe mostrar nombre "Laura", saldoUsd: 20, esEstudiante: true

### Prueba 2 — Solicitar un viaje
1. Logueado como `laurap`
2. En el dashboard, seleccionar origen y destino
3. El mapa debe mostrar marcadores de las zonas (GET /api/zonas funciona)
4. Hacer clic en "Solicitar"
5. Como `laurap` tiene `primer_viaje_usado = false` → el viaje debería costar $0.00

### Prueba 3 — Recargar saldo
1. Logueado como `laurap`
2. Ir a `http://localhost:8080/views/cliente-recharge.html`
3. La tasa BCV debe cargarse automáticamente
4. Los bancos deben aparecer en el select
5. Completar el formulario y enviar

### Prueba 4 — Login como chofer
1. Usuario: `carlosr`, contraseña: `password`
2. Verificar que `response.data.habilitado === true` y `response.data.disponible === true`

### Prueba 5 — Registro de nuevo cliente
1. Ir a `http://localhost:8080/views/registro.html`
2. Seleccionar "Cliente"
3. Completar datos (sin campo de email ni username — se genera automáticamente de la cédula)
4. Al terminar, hacer login con la cédula ingresada como usuario

---

## Pasos para el equipo antes de la entrega (5 de julio)

### Backend (Johanna)
- [x] Commit de todos los cambios en `integration/backend`
- [ ] Merge de `integration/backend` → `develop`
- [ ] Avisar a Freddy para que haga merge de `frontend-freddy` → `develop`
- [ ] Prueba de integración completa en `develop`

### Frontend (Freddy)
- [x] `api.js` — módulo de fetch listo ✅
- [x] `login.js` — URL ya apuntaba a `/auth/login` (ahora existe en backend) ✅
- [x] `registro.js` — URL ya apuntaba a `/auth/register-cliente` (ahora existe) ✅
- [x] `dashboard.js` — URL ya apuntaba a `/solicitar-viaje` (ahora existe) ✅
- [x] `cliente-recharge.js` — todos los endpoints correctos ✅
- [x] `cliente-record.js` — funciona con reporte global ✅
- [ ] Crear `chofer-dashboard.html` + JS para el flujo del chofer
- [ ] Agregar paso de "preview de tarifa" antes de confirmar solicitud
- [ ] Crear pantalla de panel administrativo

### Base de datos
- [x] `decarrerita.sql` completo con todas las tablas, SP, función y trigger
- [x] `datos_prueba.sql` con usuarios de prueba funcionales

---

*Manual generado el 25/06/2026. Rama: `integration/backend`. Build: SUCCESS — 127 archivos Java.*
