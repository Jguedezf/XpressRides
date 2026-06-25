# Informe Técnico Backend v3 — XpressRides (Decarrerita)
**Rama:** `integration/backend`  
**Fecha de auditoría:** 25 de junio de 2026  
**Autor del informe:** Generado con Claude Code para Johanna Guédez  
**Entrega final:** 5 de julio de 2026 — UNEG, Sistemas de Base de Datos I

---

## 1. Resumen Ejecutivo

El backend de XpressRides está en un estado avanzado y funcional. La rama `integration/backend` concentra el trabajo de Johanna Guédez y Eliuber González tras un merge exitoso que compila limpio (`BUILD SUCCESS`, 126 archivos Java, 0 errores).

**Lo que se logró hasta hoy:**
- Base de datos completa: 18 tablas, 7 vistas, 1 stored procedure, 1 función, 1 trigger
- 18 controladores REST activos con más de 45 endpoints
- Autenticación JWT completa (login, registro, refresh, logout, cambio de contraseña)
- Flujo completo de habilitación de choferes con habilitación automática doble-condición
- Solicitud de traslado vía stored procedure MySQL (atómica, con tarifa, saldo, cupones y asignación)
- Módulo de facturación con IGTF
- Módulo financiero: recargas, pagos a choferes, distribución 70/30
- 7 reportes administrativos desde vistas SQL
- Cálculo de tarifa preview (sin crear viaje)
- Gestión de cupones: creación y asignación por admin
- Ciclo completo de estados del traslado con timestamps

**Problema crítico detectado:** Los controladores de Eliuber (auth, cliente, chofer, vehículo, solicitar-traslado) usan formatos de respuesta diferentes al estándar `{success, data, message}` que usa Johanna. Freddy construyó su `api.js` esperando ese estándar — esto rompe login, registro y solicitud de viaje. **Se deben corregir antes del merge a develop.**

---

## 2. Base de Datos

### 2.1 Tablas (18)

| Tabla | Descripción |
|---|---|
| `usuario` | Tabla base: credenciales (username, password hash BCrypt), nombre, apellido, cédula, teléfono, rol (`cliente`, `chofer`, `personal_admin`, `administrador`) |
| `cliente` | Extiende `usuario`: `saldo_usd` DECIMAL(10,2), `es_estudiante` BOOLEAN, `primer_viaje_usado` BOOLEAN |
| `chofer` | Extiende `usuario`: `id_banco`, `numero_cuenta`, `saldo_acumulado_usd`, `habilitado` BOOLEAN, `disponible` BOOLEAN |
| `personal_admin` | Extiende `usuario`: `cargo` VARCHAR |
| `banco` | Catálogo de bancos venezolanos: id, nombre, activo |
| `zona` | 54 zonas de Ciudad Guayana con coordenadas GPS (`latitud`, `longitud`), parroquia, activo |
| `contacto_emergencia` | Mínimo 2 por chofer: nombre, teléfono, parentesco, id_chofer |
| `vehiculo` | Un vehículo por chofer: placa, marca, modelo, año, color, activo, id_chofer |
| `evaluacion_psicologica` | Calificación 0–100, columna generada `aprobado` (`calificacion >= 73`), fecha, id_chofer |
| `revision_vehiculo` | Calificación 0–100, columna generada `apto` (`calificacion >= 65`), columna generada `proxima_revision` (fecha + 1 año), id_vehiculo |
| `tasa_bcv` | Historial: `fecha_vigencia`, `tasa_ves` (bolívares por dólar) |
| `traslado` | Registro central del viaje: zonas, pasajeros, costos (USD y VES), distribución 70/30, estado, timestamps, id_tasa, id_cupon_usado |
| `pago_chofer` | Transferencias al chofer: monto, fecha, referencia, id_banco, id_chofer |
| `cupon` | `codigo` (único, uppercase), `tipo` (bienvenida/estudiante/promocional), `descuento_usd`, `distancia_max_km`, `activo` |
| `cupon_cliente` | Relación cupon ↔ cliente: `usado` BOOLEAN, `fecha_uso`, `created_at` |
| `recarga_saldo` | Recargas: `monto_usd`, `monto_ves`, `referencia`, `id_banco`, `id_cliente`, `id_tasa` |
| `factura` | Factura fiscal por traslado: `monto_usd`, `monto_ves`, `igtf_usd` (3%), `total_usd`, `fecha_emision`, `numero_control` |
| `notificacion` | Notificaciones del sistema: `tipo`, `mensaje`, `leida`, `fecha`, `id_usuario` |

### 2.2 Función SQL

```sql
fn_distancia_km(lat1, lon1, lat2, lon2) RETURNS DECIMAL(10,2)
```
Implementa la fórmula Haversine para calcular distancia en km entre dos puntos GPS. Usada por `sp_solicitar_traslado` y por `FareService.java` para el cálculo preview.

### 2.3 Stored Procedure

```sql
sp_solicitar_traslado(
  p_id_cliente, p_id_zona_origen, p_id_zona_destino,
  p_cantidad_pasajeros, p_codigo_cupon
)
```
Flujo completo y atómico en una transacción:
1. Obtiene tasa BCV vigente
2. Calcula distancia con `fn_distancia_km`
3. Aplica tarifa dinámica (base + km + recargo nocturno/fin de semana + factor hora pico)
4. Verifica si aplica primer viaje gratis (y marca `primer_viaje_usado = true`)
5. Verifica si aplica descuento estudiante (destino = sede universitaria)
6. Aplica cupón si se proporcionó código válido y activo
7. Verifica que el cliente tenga saldo suficiente
8. Descuenta saldo del cliente
9. Asigna chofer disponible por proximidad (radio 5→10→15 km, selección aleatoria)
10. Inserta registro en `traslado`
11. Genera factura con IGTF (3% si pago en USD)
12. Distribuye 70% al chofer (acumula en `saldo_acumulado_usd`)

### 2.4 Trigger

```sql
trg_traslado_eventos — AFTER UPDATE ON traslado
```
Se dispara en cada cambio de estado del traslado. Registra el evento con timestamp en una tabla de auditoría interna.

### 2.5 Vistas SQL (7) — con modelo Java y endpoint

| Vista DB | Modelo Java | Endpoint |
|---|---|---|
| `historial_traslados` | `TripHistory` | `GET /api/reportes/historial-traslados` |
| `ganancias_empresa` | `CompanyEarnings` | `GET /api/reportes/ganancias` |
| `pagos_por_chofer` | `DriverPaymentReport` | `GET /api/reportes/pagos-chofer` |
| `pendientes_pago_chofer` | `PendingDriverPayment` | `GET /api/reportes/pendientes-pago` |
| `traslados_cancelados` | `CancelledTrip` | `GET /api/reportes/cancelados` |
| `facturas_emitidas` | `IssuedInvoice` | `GET /api/reportes/facturas` |
| `notificaciones_pendientes` | `PendingNotification` | `GET /api/reportes/notificaciones` |

---

## 3. Inventario Completo de Código Java

### 3.1 Modelos (`model/`)

**Entidades principales:**
- `User` — tabla `usuario`, con `@JsonIgnore` en password
- `Customer extends User` — tabla `cliente`
- `Driver extends User` — tabla `chofer`
- `AdminPersonnel extends User` — tabla `personal_admin`
- `Vehicle` — tabla `vehiculo`
- `VehicleInspection` — tabla `revision_vehiculo`
- `PsychologicalEvaluation` — tabla `evaluacion_psicologica`
- `Bank` — tabla `banco`
- `Zone` — tabla `zona`
- `ExchangeRate` — tabla `tasa_bcv`
- `Trip` — tabla `traslado` (campo `rate` → `@ManyToOne ExchangeRate`)
- `Coupon` — tabla `cupon`
- `CustomerCoupon` — tabla `cupon_cliente`
- `TopUp` — tabla `recarga_saldo`
- `DriverPayment` — tabla `pago_chofer`
- `Invoice` — tabla `factura`
- `EmergencyContact` — tabla `contacto_emergencia`
- `Notification` — tabla `notificacion`

**Modelos de vistas (solo lectura, `@Immutable`):**
`TripHistory`, `CompanyEarnings`, `DriverPaymentReport`, `PendingDriverPayment`, `CancelledTrip`, `IssuedInvoice`, `PendingNotification`

### 3.2 Repositorios (`repository/`)

| Repositorio | Notas relevantes |
|---|---|
| `UserRepository` | `findByUsername(String)` |
| `CustomerRepository` | `findByUser_Username(String)` |
| `DriverRepository` | `findByUser_Username(String)` |
| `PsychologicalEvaluationRepository` | `existsByDriver_IdAndApprovedTrue(Integer)` — clave para habilitación |
| `VehicleRepository` | `findByDriver_Id(Integer)` |
| `VehicleInspectionRepository` | `findFirstByVehicle_IdOrderByInspectionDateDesc(Integer)` — clave para habilitación |
| `BankRepository` | `@Repository` import añadido en esta sesión |
| `ZoneRepository` | `@Repository` import añadido en esta sesión |
| `ExchangeRateRepository` | `findFirstByEffectiveDateLessThanEqualOrderByEffectiveDateDesc(LocalDate)` |
| `TripRepository` | CRUD + queries del SP |
| `CouponRepository` | `existsByCode(String)` — añadido esta sesión |
| `CustomerCouponRepository` | `findByCustomer_IdAndUsedFalse(Integer)`, `existsByCoupon_IdAndCustomer_Id(Integer, Integer)` — añadido esta sesión |
| `TopUpRepository`, `DriverPaymentRepository` | CRUD |
| `InvoiceRepository`, `NotificationRepository`, `EmergencyContactRepository` | CRUD |
| `TripHistoryRepository`, `CompanyEarningsRepository`, `DriverPaymentReportRepository`, `PendingDriverPaymentRepository`, `CancelledTripRepository`, `IssuedInvoiceRepository`, `PendingNotificationRepository` | Solo `findAll()` sobre vistas |
| `AdminPersonnelRepository` | CRUD |

### 3.3 Servicios (`service/`)

| Servicio | Responsabilidad |
|---|---|
| `AuthService` | Registro cliente/chofer, login, refresh token, cambio contraseña. Usa BCrypt + JWT. Asigna `isStudent` en registro. |
| `CustomerService` | Perfil, historial de viajes, calificación, cancelación, cupones del cliente |
| `DriverService` | Disponibilidad, habilitación manual, estado, traslados del chofer, cancelación. **Incluye `chofer_llego` y timestamps de viaje** |
| `VehicleService` | Registro de vehículo (Eliuber), inspección vehicular. **Incluye `checkAndEnableDriver`** |
| `PsychEvaluationService` | Registro de evaluación psicológica (Eliuber). **Incluye `checkAndEnableDriver`** |
| `DriverRegistrationService` | Registro de vehículo, evaluación psicológica y revisión vehicular (versión Johanna — coexiste) |
| `TripService` | Invoca `sp_solicitar_traslado` vía JDBC |
| `TripStatusService` | Actualiza estado del traslado con validación de transiciones y timestamps |
| `CatalogService` | Zonas activas, todas las zonas, bancos activos, todos los bancos |
| `ExchangeRateService` | Tasa BCV vigente (cubre feriados/fines de semana), historial, registro |
| `PaymentService` | Recarga de saldo cliente, pago a chofer, historiales |
| `ReportService` | Lee las 7 vistas SQL |
| `InvoiceService` | Detalle de factura por id de traslado |
| `NotificationService` | Notificaciones del usuario |
| `EmergencyContactService` | Contactos de emergencia del chofer |
| `FareService` | **NUEVO** — Preview de tarifa (llama `fn_distancia_km` + Java, sin crear viaje) |
| `CouponService` | **NUEVO** — Creación de cupones y asignación a clientes |
| `UserService` | **NUEVO** — Actualización de perfil (nombre, apellido, email, teléfono, cédula) |
| `CustomUserDetailsService` | Carga usuario por username para Spring Security |

### 3.4 Controladores (`controller/`) — 18 en total

| Controlador | Base URL | Autor |
|---|---|---|
| `AuthController` | `/api/auth` | Eliuber |
| `TripController` | `/api/traslado` | Eliuber |
| `CustomerController` | `/api/cliente` | Eliuber |
| `DriverController` | `/api/chofer` | Eliuber |
| `VehicleController` | `/api/vehiculo` | Eliuber (URL corregida a español esta sesión) |
| `PsychEvaluationController` | `/api/...` | Eliuber |
| `EmergencyContactController` | `/api/...` | Eliuber |
| `NotificationController` | `/api/...` | Eliuber |
| `CatalogController` | `/api` | Johanna |
| `ExchangeRateController` | `/api` | Johanna |
| `PaymentController` | `/api` | Johanna |
| `ReportController` | `/api/reportes` | Johanna |
| `DriverRegistrationController` | `/api` | Johanna (original, coexiste) |
| `TripStatusController` | `/api` | Johanna (original, coexiste) |
| `InvoiceController` | `/api` | Johanna |
| `FareController` | `/api/traslados` | Johanna — **NUEVO** |
| `CouponController` | `/api/cupones` | Johanna — **NUEVO** |
| `UserController` | `/api/users` | Johanna — **NUEVO** |

### 3.5 DTOs (`dto/`)

**Request:** `LoginRequest`, `RegisterRequest` (campo `isStudent` añadido), `FareRequest` (NUEVO), `CouponRequest` (NUEVO), `UserUpdateRequest` (NUEVO), `TripRequest`, `TripStatusRequest`, `CustomerProfileRequest`, `AvailabilityRequest`, `EnableRequest`, `InspectionRequest`, `PsychEvaluationRequest`, `RatingRequest`, `RechargeRequest`, `RefreshTokenRequest`, `VehicleRequest`, `EmergencyContactRequest`, `ChangePasswordRequest`

**Response:** `AuthResponse`, `TripResponse`, `CustomerProfileResponse`, `DriverStatusResponse`, `VehicleResponse`, `InspectionResponse`, `PsychEvaluationResponse`, `FareResponse` (NUEVO — con `@JsonProperty` para claves en español), `InvoiceResponseDTO`

**Otros:** `TripStatusUpdateDTO`, `PsychEvaluationStatus`, `VehicleInspectionDTO`, `VehicleInspectionStatus`

### 3.6 Seguridad (`segurity/`)

- `SecurityConfig` — CORS, JWT filter chain, rutas públicas (`/api/auth/**`, `/api/zonas/**`, `/api/bancos/**`)
- `JwtAuthenticationFilter` — extrae y valida token en cada request
- `JwtService` — generación y validación de tokens
- `TokenBlacklistService` — revocación de tokens en logout

---

## 4. Endpoints Completos — Todos los 45+ Endpoints

### 4.1 Autenticación — AuthController (`/api/auth`) — Eliuber
> ⚠️ FORMATO DIFERENTE: devuelve `AuthResponse`, NO `{success, data, message}`

#### `POST /api/auth/registro`
**Auth:** Pública  
**Request Body:**
```json
{
  "nombre": "Laura",
  "apellido": "Pérez",
  "cedula": "V-12345678",
  "telefono": "0414-1234567",
  "correo": "laura@mail.com",
  "password": "password123",
  "rol": "cliente",
  "isStudent": true
}
```
**Response:**
```json
{
  "username": "laura@mail.com",
  "role": "cliente",
  "accesToken": "<JWT>",
  "refreshToken": "<JWT>",
  "message": "Usuario registrado exitosamente"
}
```
> ⚠️ Nota: El campo es `accesToken` (un solo 's') — typo en el código original de Eliuber.

#### `POST /api/auth/iniciar-sesion`
**Auth:** Pública  
**Request Body:**
```json
{ "correo": "carlosr", "password": "password" }
```
**Response:** Igual que registro (AuthResponse)

#### `POST /api/auth/refrescar`
**Auth:** Pública  
**Request Body:** `{ "refreshToken": "<JWT>" }`  
**Response:** AuthResponse con nuevos tokens

#### `POST /api/auth/cambiar-contrasena`
**Auth:** JWT requerido  
**Request Body:** `{ "currentPassword": "...", "newPassword": "..." }`  
**Response:** `{ "message": "Contraseña cambiada correctamente" }`

#### `POST /api/auth/cerrar-sesion`
**Auth:** JWT requerido (en header `Authorization: Bearer <token>`)  
**Request Body:** vacío  
**Response:** `{ "message": "Sesión cerrada exitosamente" }`

---

### 4.2 Solicitud de Traslado — TripController (`/api/traslado`) — Eliuber
> ⚠️ FORMATO DIFERENTE: devuelve `TripResponse`, NO `{success, data, message}`  
> ⚠️ URL en SINGULAR `/api/traslado` (vs `/api/traslados` del FareController)

#### `POST /api/traslado/solicitar`
**Auth:** JWT, rol `cliente`  
**Request Body:**
```json
{
  "idZonaOrigen": 1,
  "idZonaDestino": 15,
  "cantidadPasajeros": 2,
  "codigoCupon": "BIENVENIDA" 
}
```
**Response:** `TripResponse` (campos pendientes de verificar en `TripResponse.java`)  
> Internamente llama a `sp_solicitar_traslado` — toda la lógica de negocio está en MySQL.

---

### 4.3 Cliente — CustomerController (`/api/cliente`) — Eliuber
> ⚠️ FORMATO DIFERENTE: devuelve objetos directos, NO `{success, data, message}`

| Método | URL | Auth | Descripción |
|---|---|---|---|
| GET | `/api/cliente/perfil` | JWT cliente | Perfil del cliente (CustomerProfileResponse) |
| PUT | `/api/cliente/perfil` | JWT cliente | Actualizar perfil (CustomerProfileRequest) |
| GET | `/api/cliente/traslados` | JWT cliente | Todos los viajes del cliente |
| GET | `/api/cliente/traslados/{id}` | JWT cliente | Detalle de un viaje |
| PUT | `/api/cliente/traslados/{id}/calificar` | JWT cliente | Calificar viaje completado |
| PUT | `/api/cliente/traslados/{id}/cancelar` | JWT cliente | Cancelar viaje |
| GET | `/api/cliente/cupones` | JWT cliente | Cupones disponibles del cliente |

---

### 4.4 Chofer — DriverController (`/api/chofer`) — Eliuber
> ⚠️ FORMATO DIFERENTE: devuelve strings y objetos directos

| Método | URL | Auth | Body | Descripción |
|---|---|---|---|---|
| PUT | `/api/chofer/disponibilidad` | JWT chofer | `{"available": true}` | Cambiar disponibilidad |
| PUT | `/api/chofer/habilitar/{driverId}` | JWT admin | `{"enabled": true}` | Habilitar/inhabilitar chofer manualmente |
| GET | `/api/chofer/estado` | JWT chofer | — | Estado y datos del chofer (DriverStatusResponse) |
| GET | `/api/chofer/traslados` | JWT chofer | — | Traslados asignados al chofer |
| GET | `/api/chofer/traslados/{id}` | JWT chofer | — | Detalle de un traslado |
| PUT | `/api/chofer/traslados/{id}/estado` | JWT chofer | `{"status": "en_camino"}` | Avanzar estado del traslado |
| PUT | `/api/chofer/traslados/{id}/cancelar` | JWT chofer | `{"motivo": "texto"}` | Cancelar traslado |

**Estados válidos del traslado (en orden):**
`solicitado` → `aceptado` → `en_camino` → `chofer_llego` → `en_progreso` → `completado`

---

### 4.5 Vehículo — VehicleController (`/api/vehiculo`) — Eliuber
> ⚠️ FORMATO DIFERENTE: devuelve objetos directos

| Método | URL | Auth | Descripción |
|---|---|---|---|
| POST | `/api/vehiculo/registrar` | JWT chofer | Chofer registra su vehículo |
| POST | `/api/vehiculo/revision` | JWT admin | Admin registra revisión vehicular |

---

### 4.6 Habilitación de Choferes — DriverRegistrationController (`/api`) — Johanna
> ✅ Formato estándar `{success, data, message}`

| Método | URL | Auth | Body / Descripción |
|---|---|---|---|
| POST | `/api/choferes/{id}/vehiculo` | — | Chofer registra vehículo (requiere auth a definir) |
| POST | `/api/choferes/{id}/evaluacion-psicologica` | — | Admin registra eval psicológica |
| POST | `/api/vehiculos/{id}/revision` | — | Admin registra revisión vehicular |

> ⚠️ Duplicado funcional con VehicleController y PsychEvaluationController de Eliuber — coexisten.

---

### 4.7 Catálogos — CatalogController (`/api`) — Johanna
> ✅ Formato estándar. ✅ Rutas públicas (sin JWT).

| Método | URL | Auth | Response data |
|---|---|---|---|
| GET | `/api/zonas` | Pública | Array de zonas activas: `[{id, name, parish, latitude, longitude, active}]` |
| GET | `/api/zonas/todas` | Pública | Todas las zonas sin filtro |
| GET | `/api/bancos` | Pública | Array de bancos activos: `[{id, name, active}]` |
| GET | `/api/bancos/todos` | Pública | Todos los bancos sin filtro |

---

### 4.8 Tasa BCV — ExchangeRateController (`/api`) — Johanna
> ✅ Formato estándar.

| Método | URL | Auth | Body | Response data |
|---|---|---|---|---|
| GET | `/api/tasa-bcv/vigente` | — | — | `{id, effectiveDate, rateVesToUsd}` |
| GET | `/api/tasa-bcv/historial` | — | — | Array de tasas |
| POST | `/api/tasa-bcv` | — ⚠️ | `{effectiveDate, rateVesToUsd}` | Tasa creada |

> ⚠️ `POST /api/tasa-bcv` no tiene `@PreAuthorize` — cualquier usuario autenticado puede registrar tasas.

---

### 4.9 Pagos — PaymentController (`/api`) — Johanna
> ✅ Formato estándar.

| Método | URL | Auth | Body / Descripción |
|---|---|---|---|
| POST | `/api/recargas` | — ⚠️ | `TopUp` completo — cliente recarga saldo |
| GET | `/api/recargas/cliente/{id}` | — ⚠️ | Historial de recargas del cliente |
| POST | `/api/pagos-chofer` | — ⚠️ | `DriverPayment` — admin registra pago a chofer |
| GET | `/api/pagos-chofer/chofer/{id}` | — ⚠️ | Historial de pagos del chofer |

> ⚠️ Ninguno de estos endpoints tiene `@PreAuthorize`.

---

### 4.10 Reportes — ReportController (`/api/reportes`) — Johanna
> ✅ Formato estándar.

| Método | URL | Auth | Descripción |
|---|---|---|---|
| GET | `/api/reportes/historial-traslados` | JWT ⚠️ | Vista completa de todos los traslados |
| GET | `/api/reportes/ganancias` | JWT ⚠️ | Ganancias de la empresa |
| GET | `/api/reportes/pagos-chofer` | JWT ⚠️ | Reporte de pagos por chofer |
| GET | `/api/reportes/pendientes-pago` | JWT ⚠️ | Traslados pendientes de pago al chofer |
| GET | `/api/reportes/cancelados` | JWT ⚠️ | Traslados cancelados |
| GET | `/api/reportes/facturas` | JWT ⚠️ | Facturas emitidas |
| GET | `/api/reportes/notificaciones` | JWT ⚠️ | Notificaciones pendientes del sistema |

> ⚠️ Requieren JWT pero no tienen `@PreAuthorize(hasRole('administrador'))` — cualquier usuario autenticado (incluyendo clientes) puede verlos.

---

### 4.11 Estado de Traslado — TripStatusController (`/api`) — Johanna
> ✅ Formato estándar.

#### `PATCH /api/viajes/{id}/estado`
**Auth:** JWT (sin @PreAuthorize explícito)  
**Request Body:**
```json
{ "nuevoEstado": "en_camino" }
```
**Response data:** `{id, nuevoEstado, mensaje}` y timestamps actualizados

> ⚠️ Duplicado funcional con `PUT /api/chofer/traslados/{id}/estado` de Eliuber.

---

### 4.12 Facturación — InvoiceController (`/api`) — Johanna
> ✅ Formato estándar.

#### `GET /api/facturas/{trasladoId}`
**Auth:** JWT  
**Response data:** `InvoiceResponseDTO` con montos USD/VES, IGTF (3%), número de control

---

### 4.13 Tarifa Preview — FareController (`/api/traslados`) — Johanna **NUEVO**
> ✅ Formato estándar.

#### `POST /api/traslados/calcular-tarifa`
**Auth:** JWT, rol `cliente`  
**Request Body:**
```json
{
  "idZoneOrigin": 1,
  "idZoneDestiny": 15,
  "passengerCount": 2
}
```
**Response data:**
```json
{
  "distanciaKm": 12.5,
  "tarifaBase": 1.00,
  "costoDistancia": 5.63,
  "recargoHoraPico": 1.20,
  "recargoNocturnoFinSemana": 0.00,
  "descuentoAplicado": "ninguno",
  "costoFinalUsd": 7.96,
  "costoFinalVes": 290.00,
  "tasaBcvId": 3,
  "primerViajeGratis": false,
  "descuentoEstudiantil": false
}
```

---

### 4.14 Cupones — CouponController (`/api/cupones`) — Johanna **NUEVO**
> ✅ Formato estándar.

#### `POST /api/cupones`
**Auth:** JWT, rol `administrador` o `personal_admin`  
**Request Body:**
```json
{
  "code": "PROMO25",
  "type": "promocional",
  "discountUsd": 2.50,
  "maxDistanceKm": 20
}
```
**Response data:** Cupón creado

#### `POST /api/cupones/{id}/asignar/{clienteId}`
**Auth:** JWT, rol `administrador` o `personal_admin`  
**Response data:** Registro de `CustomerCoupon`

---

### 4.15 Perfil de Usuario — UserController (`/api/users`) — Johanna **NUEVO**
> ✅ Formato estándar.

#### `PUT /api/users/{id}`
**Auth:** JWT  
**Request Body:**
```json
{
  "name": "Laura",
  "lastName": "Pérez",
  "email": "laura@nuevo.com",
  "phone": "0414-9999999",
  "ci": "V-12345678"
}
```
**Response data:** Objeto `User` actualizado  
> ⚠️ Sin `@PreAuthorize` — cualquier usuario autenticado puede actualizar cualquier perfil por ID.

---

## 5. Dónde Vive Cada Lógica de Negocio

### Algoritmo de Tarifas Dinámicas
**Primario:** `sp_solicitar_traslado` (MySQL) — ejecutado en `TripService.java`  
**Secundario (preview):** `FareService.java` — misma fórmula reimplementada en Java  

**Fórmula:**
```
distancia = fn_distancia_km(lat_origen, lon_origen, lat_destino, lon_destino)
costoDistancia = distancia × 0.45
recargo = 1.50 si es (19–5h) o (sábado o domingo), sino 0
factorPico = 1.20 si 7–9h | 1.15 si 11:30–12h | 1.25 si 17–18h | 1.00 resto
tarifaRaw = (1.00 + costoDistancia + recargo) × factorPico
Si primer_viaje_gratis → costoFinal = 0.00
Sino si es_estudiante Y destino en {UNEG Sede Atlántico, UNEG Sede Villa Asia, UNEXPO} → costoFinal = tarifaRaw × 0.70
Sino si tiene cupón → costoFinal = max(0, tarifaRaw - descuento_cupon)
costoVes = costoFinal × tasa_bcv_vigente
```

### Habilitación Automática de Choferes
**Dónde vive:** `VehicleService.checkAndEnableDriver()` y `PsychEvaluationService.checkAndEnableDriver()`  
**Regla:** Cuando se registra una inspección vehicular **apta** (≥65) O una evaluación psicológica **aprobada** (≥73), el sistema verifica si la otra condición ya se cumple. Si ambas están OK → `driver.enabled = true` automáticamente.

### Distribución 70/30
**Dónde vive:** `sp_solicitar_traslado` (MySQL)  
**Regla:** El chofer recibe 70% de la tarifa base. La empresa retiene 30%. Los descuentos al cliente los absorbe la empresa.

### IGTF (3%)
**Dónde vive:** `InvoiceService.java` + `sp_solicitar_traslado`  
**Regla:** Se aplica sobre pagos en USD. `igtf = costoFinalUsd × 0.03`, `totalUsd = costoFinalUsd + igtf`.

### Ciclo de Vida del Traslado + Timestamps
**Dónde vive:** `DriverService.updateTripStatus()` + `TripStatusService.updateStatus()`  
**Estados:** `solicitado → aceptado → en_camino → chofer_llego → en_progreso → completado`  
**Timestamps:** `fecha_aceptacion`, `fecha_inicio`, `fecha_fin`, `duracion_minutos` se asignan en cada transición.

### Tasa BCV (cubre feriados/fines de semana)
**Dónde vive:** `ExchangeRateService.getCurrentRate()`  
**Query:** `SELECT TOP 1 FROM tasa_bcv WHERE fecha_vigencia <= TODAY ORDER BY fecha_vigencia DESC`

### Cupones
**Dónde vive:** `CouponService.java` (creación/asignación) + `sp_solicitar_traslado` (aplicación)  
**Regla:** El SP descuenta el `descuento_usd` del cupón del costo final; marca `cupon_cliente.usado = true`.

---

## 6. Estado del Frontend de Freddy

### 6.1 Vistas HTML Existentes (`frontend-freddy`)
| Archivo | Descripción |
|---|---|
| `login.html` | Formulario de login |
| `registro.html` | Registro de cliente y chofer con tabs |
| `cliente-dashboard.html` | Dashboard con mapa Leaflet, formulario de solicitud de viaje |
| `cliente-recharge.html` | Formulario de recarga de saldo |
| `cliente-recharge-history.html` | Historial de recargas |
| `cliente-record.html` | Historial de viajes del cliente |

### 6.2 Módulos JavaScript — ¿Fetch real o simulado?

**TODO es fetch() real.** Freddy construyó un módulo centralizado `api.js` con `fetchAPI()` que incluye manejo de JWT, headers y parsing de `{success, data, message}`. No hay `setTimeout()` ni datos simulados.

| Archivo JS | Estado actual | Endpoints que consume |
|---|---|---|
| `api.js` | ✅ Listo — fetchAPI centralizado | — (módulo base) |
| `login.js` | ❌ URL incorrecta | `/api/auth/login` → debe ser `/api/auth/iniciar-sesion` |
| `registro.js` | ❌ URL incorrecta | `/api/auth/register-cliente` → debe ser `/api/auth/registro` |
| `dashboard.js` | ✅ zonas OK / ❌ solicitar viaje mal | `/api/zonas` ✅, `/api/solicitar-viaje` ❌ → debe ser `/api/traslado/solicitar` |
| `cliente-recharge.js` | ✅ Todos correctos | `/api/tasa-bcv/vigente`, `/api/bancos`, `/api/recargas` |
| `cliente-record.js` | ✅ Correcto (filtrado client-side) | `/api/reportes/historial-traslados` |
| `notifications.js` | ✅ Correcto (filtrado client-side) | `/api/reportes/notificaciones` |
| `user-profile.js` | ✅ Lee solo de localStorage | Sin backend |

### 6.3 Lo que Freddy puede conectar YA (sin cambios en backend)

- `GET /api/zonas` — carga zonas en el mapa y en los selects del dashboard ✅
- `GET /api/bancos` — carga bancos en el formulario de registro y recargas ✅
- `GET /api/tasa-bcv/vigente` — muestra tasa BCV en la pantalla de recarga ✅
- `POST /api/recargas` — formulario de recarga funcional ✅
- `GET /api/reportes/historial-traslados` — historial de viajes del cliente ✅
- `GET /api/reportes/notificaciones` — badge de notificaciones ✅
- `GET /api/facturas/{id}` — detalle de factura desde historial ✅

### 6.4 Lo que Freddy debe corregir en su código

1. **`login.js`:** Cambiar `/api/auth/login` → `/api/auth/iniciar-sesion`
2. **`registro.js`:** Cambiar `/api/auth/register-cliente` → `/api/auth/registro`
3. **`dashboard.js`:** Cambiar `/api/solicitar-viaje` → `/api/traslado/solicitar`
4. **Manejo de AuthResponse:** El endpoint de login devuelve `{username, role, accesToken, refreshToken, message}` — SIN campo `success`. Freddy debe ajustar `fetchAPI` para el endpoint de auth, o Eliuber debe envolver en `{success, data, message}`.

### 6.5 Pantallas que Freddy aún no tiene

- Dashboard/Panel del **chofer** (acepta viajes, cambia estado, marca llegada)
- Dashboard/Panel del **administrador**
- Pantalla de **registro de vehículo** (chofer)
- Pantalla de **perfil editable** del cliente
- Pantalla de **tarifa preview** antes de confirmar solicitud

---

## 7. Manual de Integración para el Frontend

### 7.1 Configuración Base

El backend corre en `http://localhost:8080`. Freddy ya tiene esto configurado en `api.js`:
```javascript
const API_BASE_URL = '/api';
```
Funciona porque el HTML está servido por el mismo servidor Spring Boot (mismo origen).

### 7.2 Cómo Funciona el JWT

```javascript
// Después del login, guardar en localStorage:
localStorage.setItem('xpressUsuario', JSON.stringify({
    username: response.accesToken,  // campo 'accesToken' (un solo 's')
    role: response.role,
    token: response.accesToken,     // para que fetchAPI lo incluya en Authorization
    refreshToken: response.refreshToken
}));
```

El `fetchAPI` de `api.js` ya lee `usuario.token` y agrega `Authorization: Bearer <token>` automáticamente.

### 7.3 Flujo Completo de Login

```javascript
// CORRECCIÓN NECESARIA en login.js — cambiar la URL:
const response = await fetch('/api/auth/iniciar-sesion', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ correo: 'carlosr', password: 'password' })
});
const data = await response.json();
// data = { username, role, accesToken, refreshToken, message }
// IMPORTANTE: NO hay campo 'success' — manejar directamente
localStorage.setItem('xpressUsuario', JSON.stringify({
    token: data.accesToken,
    refreshToken: data.refreshToken,
    role: data.role,
    username: data.username
}));
```

### 7.4 Flujo Completo de Solicitar Viaje (Dashboard)

```javascript
// PASO 1: Calcular tarifa preview (muestra el costo antes de confirmar)
const tarifaResp = await fetchAPI('/traslados/calcular-tarifa', {
    method: 'POST',
    body: JSON.stringify({
        idZoneOrigin: parseInt(origenId),
        idZoneDestiny: parseInt(destinoId),
        passengerCount: parseInt(pasajeros)
    })
});
const tarifa = tarifaResp.data;
console.log(`Costo estimado: $${tarifa.costoFinalUsd} USD`);
// Mostrar al usuario y pedir confirmación

// PASO 2: Solicitar el viaje (CORRECCIÓN en dashboard.js — cambiar URL)
const viajeResp = await fetchAPI('/traslado/solicitar', {  // SINGULAR
    method: 'POST',
    body: JSON.stringify({
        idZonaOrigen: parseInt(origenId),
        idZonaDestino: parseInt(destinoId),
        cantidadPasajeros: parseInt(pasajeros),
        codigoCupon: null  // o el código si el usuario tiene uno
    })
});
```

### 7.5 Flujo Completo de Registro de Cliente

```javascript
// CORRECCIÓN en registro.js — cambiar la URL:
const resp = await fetchAPI('/auth/registro', {
    method: 'POST',
    body: JSON.stringify({
        nombre: 'Laura',
        apellido: 'Pérez',
        cedula: 'V-12345678',
        telefono: '0414-1234567',
        correo: 'laura@mail.com',
        password: 'password123',
        rol: 'cliente',
        isStudent: true   // campo que activa el descuento estudiantil
    })
});
// resp devuelve AuthResponse — sin 'success' — manejar igual que login
```

### 7.6 Recarga de Saldo (ya funciona)

```javascript
// cliente-recharge.js ya usa los endpoints correctos:
// 1. GET /api/tasa-bcv/vigente → obtiene tasa para convertir VES→USD
// 2. GET /api/bancos → lista bancos
// 3. POST /api/recargas → registra recarga

await fetchAPI('/recargas', {
    method: 'POST',
    body: JSON.stringify({
        montoUsd: 10.00,
        montoVes: 360.00,
        referencia: 'TRF-123456',
        idBanco: 3,
        idCliente: 5,
        idTasa: 2
    })
});
```

### 7.7 Cambio de Estado del Traslado (Panel del Chofer)

```javascript
// Avanzar el estado del traslado — chofer usa este endpoint:
await fetchAPI(`/chofer/traslados/${idTraslado}/estado`, {
    method: 'PUT',
    body: JSON.stringify({ status: 'en_camino' })
});
// Estados en orden: solicitado → aceptado → en_camino → chofer_llego → en_progreso → completado
```

### 7.8 Historial de Viajes del Cliente (ya funciona)

```javascript
// cliente-record.js ya funciona — llama:
const resp = await fetchAPI('/reportes/historial-traslados');
const misViajes = resp.data.filter(v => v.customerId === usuario.id);
```

### 7.9 Tarifa Preview antes de Confirmar (NUEVO — disponible)

```javascript
const preview = await fetchAPI('/traslados/calcular-tarifa', {
    method: 'POST',
    body: JSON.stringify({
        idZoneOrigin: zonaOrigenId,
        idZoneDestiny: zonaDestinoId,
        passengerCount: 1
    })
});
// preview.data contiene:
// costoFinalUsd, costoFinalVes, distanciaKm, primerViajeGratis, descuentoEstudiantil
```

---

## 8. Inconsistencias y Problemas Detectados

### 🔴 CRÍTICOS (bloquean el flujo principal)

| # | Problema | Dónde | Impacto |
|---|---|---|---|
| C1 | `login.js` llama `/api/auth/login` — endpoint NO existe | `frontend-freddy/js/login.js` | Login completamente roto |
| C2 | `registro.js` llama `/api/auth/register-cliente` — endpoint NO existe | `frontend-freddy/js/registro.js` | Registro completamente roto |
| C3 | `dashboard.js` llama `/api/solicitar-viaje` — endpoint NO existe | `frontend-freddy/js/dashboard.js` | Solicitar viaje completamente roto |
| C4 | `AuthResponse` no tiene campo `success` — `fetchAPI` lanza error aunque el login sea exitoso | `AuthController.java` / `api.js` | Login falla incluso con URLs correctas |

### 🟡 IMPORTANTES (no bloquean de inmediato pero causarán problemas)

| # | Problema | Dónde | Impacto |
|---|---|---|---|
| I1 | Typo en `AuthResponse`: `accesToken` (debería ser `accessToken`) | `AuthResponse.java` | Freddy debe usar el campo mal escrito |
| I2 | `POST /api/tasa-bcv` sin `@PreAuthorize` | `ExchangeRateController` | Cualquier usuario puede registrar tasas BCV |
| I3 | `PUT /api/users/{id}` sin validación de identidad | `UserController` | Usuario A puede editar perfil de usuario B |
| I4 | Endpoints de reportes sin `@PreAuthorize(admin)` | `ReportController` | Clientes pueden ver reportes financieros |
| I5 | Endpoints de pagos sin `@PreAuthorize` | `PaymentController` | Sin control de acceso por rol |
| I6 | URL duplicada para cambio de estado: `/api/viajes/{id}/estado` vs `/api/chofer/traslados/{id}/estado` | TripStatusController vs DriverController | Confusión para el frontend |
| I7 | Inconsistencia singular/plural: `/api/traslado` (solicitar) vs `/api/traslados` (calcular-tarifa) | TripController vs FareController | Freddy debe recordar cuál es cuál |
| I8 | `CORS allowedOrigins` solo para `localhost:8080` — miembros del equipo en otros hosts se bloquearán | `SecurityConfig` | Puede fallar en otros entornos |
| I9 | `cliente-record.js` y `notifications.js` filtran client-side sobre reportes globales — exponimiento de datos | `frontend-freddy` | Cliente ve datos de todos los usuarios antes del filtro |

### 🔵 MENORES

| # | Problema | Dónde |
|---|---|---|
| M1 | `DriverRegistrationController` y `VehicleController`/`PsychEvaluationController` duplican funcionalidad | Ambos autores |
| M2 | `TripStatusController` y `DriverController.updateTripStatus` duplican funcionalidad | Ambos autores |
| M3 | `@CrossOrigin(origins = "*")` en controllers individuales puede conflictuar con el CORS de Spring Security | Varios controllers de Johanna |
| M4 | CLAUDE.md menciona URLs en inglés (`/api/zones`, `/api/exchange-rate/current`) pero el código real usa español (`/api/zonas`, `/api/tasa-bcv/vigente`) | CLAUDE.md desactualizado |

---

## 9. Pendientes Técnicos por Persona

### Johanna — INMEDIATO (antes del merge a develop)

| Prioridad | Tarea |
|---|---|
| 🔴 ALTA | Hacer commit de todos los archivos modificados/creados en `integration/backend` |
| 🔴 ALTA | Verificar con Freddy que corrija las 3 URLs (login, registro, solicitar-viaje) |
| 🟡 MEDIA | Agregar `@PreAuthorize("hasRole('administrador') or hasRole('personal_admin')")` a `POST /api/tasa-bcv` |
| 🟡 MEDIA | Agregar `@PreAuthorize` a los 7 endpoints de reportes |
| 🟡 MEDIA | Agregar validación de identidad en `PUT /api/users/{id}` |

### Eliuber — Antes del merge a develop

| Prioridad | Tarea |
|---|---|
| 🔴 ALTA | Envolver respuesta de `AuthController` en `{success: true, data: {...}, message: "..."}` — Freddy's `fetchAPI` lo requiere |
| 🔴 ALTA | Estandarizar respuestas de `CustomerController` y `DriverController` a `{success, data, message}` |
| 🟡 MEDIA | Corregir typo `accesToken` → `accessToken` en `AuthResponse.java` (y actualizar frontend) |
| 🟡 MEDIA | Agregar `@PreAuthorize` a `VehicleController` endpoints de admin |

### Freddy — Inmediato (puede hacerlo solo)

| Prioridad | Tarea |
|---|---|
| 🔴 ALTA | Corregir `login.js`: `/api/auth/login` → `/api/auth/iniciar-sesion` |
| 🔴 ALTA | Corregir `registro.js`: `/api/auth/register-cliente` → `/api/auth/registro` |
| 🔴 ALTA | Corregir `dashboard.js`: `/api/solicitar-viaje` → `/api/traslado/solicitar` |
| 🔴 ALTA | Ajustar manejo del login para que maneje `AuthResponse` sin campo `success` |
| 🟡 MEDIA | Crear pantalla de panel para el chofer |
| 🟡 MEDIA | Agregar paso de "preview de tarifa" antes de confirmar solicitud de viaje |
| 🟡 MEDIA | Reemplazar filtrado client-side en `cliente-record.js` por `GET /api/cliente/traslados` de Eliuber |

---

## 10. Usuarios de Prueba

Estos usuarios están en `datos_prueba.sql` y están disponibles en la BD `decarrerita`:

| Username | Password | Rol | Estado | Notas |
|---|---|---|---|---|
| `carlosr` | `password` | Chofer | Habilitado ✅, disponible ✅, vehículo activo ✅ | Listo para recibir solicitudes |
| `laurap` | `password` | Cliente | Saldo $20 USD ✅ | `es_estudiante = true`, `primer_viaje_usado = false` (primer viaje gratis disponible) |

### Credenciales para prueba de admin
> Si no hay usuario admin en `datos_prueba.sql`, crear uno directamente en MySQL:
```sql
INSERT INTO usuario (username, password, nombre, apellido, cedula, telefono, rol)
VALUES ('admin', '$2a$10$...', 'Admin', 'Sistema', 'V-00000001', '0000-0000000', 'administrador');
INSERT INTO personal_admin (id_usuario, cargo) VALUES (LAST_INSERT_ID(), 'Administrador General');
```
> El hash de `password` con BCrypt strength 10 para la contraseña `password` es:
> `$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi`

---

## Pasos para Merge a Develop

1. **Johanna:** Commit de todos los cambios de esta sesión en `integration/backend`
2. **Freddy:** Corrección de las 3 URLs en su rama `frontend-freddy`
3. **Eliuber:** Estandarización del formato de respuesta en `AuthController` (mínimo indispensable)
4. **Johanna + Eliuber:** Merge de `integration/backend` → `develop`
5. **Freddy:** Merge de `frontend-freddy` → `develop`
6. **Todo el equipo:** Prueba de integración completa en `develop` con los usuarios de prueba
7. **Freddy/Manuel/Ángel:** Desarrollo de pantallas pendientes (panel chofer, admin, perfil)

---

*Informe generado con revisión exhaustiva del código fuente en `integration/backend` el 25/06/2026.*  
*Estado del build al momento del informe: `BUILD SUCCESS` — 126 archivos Java, 0 errores de compilación.*
