# CLAUDE.md — XpressRides (Decarrerita)
## Contexto completo del proyecto para Claude Code

---

## 0. REGLAS INNEGOCIABLES DE OPERACIÓN (LEER PRIMERO)

Estas reglas son obligatorias en CADA sesión, sin excepción:

1. **Trabaja SIEMPRE directamente en la rama actual.** NUNCA crees worktrees, NUNCA uses `git worktree`, NUNCA cambies de rama sin autorización expresa.
2. **NUNCA hagas commits.** El commit lo hace Johanna manualmente, siempre.
3. **NUNCA agregues la línea "Co-Authored-By: Claude"** en ningún commit ni archivo.
4. **NUNCA ejecutes acciones destructivas o de Git** (delete, reset, checkout, merge, push) sin pedir autorización explícita primero.
5. **Antes de editar cualquier archivo**, muestra el plan completo de cambios y espera aprobación.
6. **Guía siempre paso a paso.** Johanna aprende rápido pero necesita instrucciones explícitas, sin asumir conocimiento previo de Git, Maven o Spring Boot. Explica cada término técnico nuevo.

---

## 1. IDENTIDAD DEL PROYECTO

- **Nombre comercial:** XpressRides
- **Nombre interno (BD y código):** decarrerita
- **Institución:** Universidad Nacional Experimental de Guayana (UNEG)
- **Materia:** Sistemas de Base de Datos I
- **Profesora:** María Raquel Herrera E.
- **Entrega final:** 5 de julio de 2026
- **Descripción:** Sistema web de transporte urbano de pasajeros para Ciudad Guayana, Venezuela. Digitaliza la operación completa de la empresa Decarrerita: registro y habilitación de choferes, gestión de clientes y saldos, solicitud y asignación de traslados, control financiero 70/30 y reportes operativos.

---

## 2. EQUIPO Y ROLES

| Integrante | Rol | Rama Git | Nivel técnico |
|---|---|---|---|
| **Johanna Guédez** | Coordinadora del proyecto + Backend Lead | `feature/backend-johanna` | Intermedio — aprende rápido, requiere guía paso a paso |
| **Eliuber González** | Backend — Autenticación | `feature/backend-eliuber` | Intermedio |
| **Freddy Salazar** | Frontend Lead + único Git experimentado | `frontend-freddy` | Intermedio frontend, avanzado Git |
| **Manuel Jaimes** | Frontend + Documentación | `feature/frontend-manuel` | Básico |
| **Ángel Martínez** | Frontend + Documentación | `feature/frontend-angel` | Básico |

---

## 3. STACK TECNOLÓGICO

### Backend
- **Lenguaje:** Java 17
- **Framework:** Spring Boot 3.5.x
- **ORM:** Spring Data JPA (Hibernate)
- **Base de datos:** MySQL 8.0
- **Package raíz:** `com.xpressrides.backend`
- **Estructura de paquetes:**
  - `controller/` — endpoints REST
  - `service/` — lógica de negocio
  - `repository/` — acceso a datos (Spring Data JPA)
  - `model/` — modelos JPA (NO llamarlos "entity")
  - `dto/` — objetos de transferencia de datos
  - `security/` — autenticación JWT (lo maneja Eliuber)

### Frontend
- **Tecnologías:** HTML5, CSS3, JavaScript vanilla
- **Mapas:** Leaflet.js
- **Ubicación:** `src/main/resources/static/`
  - `static/views/` — vistas HTML
  - `static/css/` — estilos (archivo unificado: `estilos.css`)
  - `static/js/` — scripts
  - `static/img/` — imágenes

### Identidad visual
- Naranja XpressRides: `#C55A11`
- Azul profundo: `#1F4E79`
- Blanco fondo: `#FFFFFF`
- Gris claro: `#F5F5F5`
- Verde confirmación: `#1E6B3C`
- Rojo alerta: `#C00000`
- Tipografía: Inter

---

## 4. ESTADO ACTUAL DEL ENTORNO

- ✅ MySQL Server 8.0 instalado y corriendo
- ✅ MySQL Workbench configurado y conectado a la BD `decarrerita`
- ✅ Spring Boot conectado exitosamente a MySQL
- ✅ Base de datos `decarrerita` creada y cargada con `decarrerita.sql`
- ✅ `datos_prueba.sql` v1.2.0 ejecutado, verificado y subido a `feature/backend-johanna`
- ✅ Repositorio en GitHub con rama `develop` activa

### Usuarios de prueba disponibles
| Usuario | Contraseña | Rol | Estado |
|---|---|---|---|
| `carlosr` | `password` | Chofer | Habilitado, disponible, vehículo activo |
| `laurap` | `password` | Cliente | $20 USD saldo, estudiante, primer viaje gratuito |

---

## 5. BASE DE DATOS — ESTRUCTURA COMPLETA

### Tablas (18 en total)

| Tabla | Descripción |
|---|---|
| `usuario` | Tabla base con credenciales y datos comunes de todos los roles |
| `cliente` | Extiende usuario: saldo_usd, es_estudiante, primer_viaje_usado |
| `chofer` | Extiende usuario: id_banco, numero_cuenta, saldo_acumulado_usd, habilitado, disponible |
| `personal_admin` | Extiende usuario: cargo |
| `banco` | Catálogo de bancos venezolanos |
| `zona` | 54 zonas reales de Ciudad Guayana con coordenadas GPS (latitud, longitud) |
| `contacto_emergencia` | Mínimo 2 por chofer: nombre, teléfono, parentesco |
| `vehiculo` | Vehículo del chofer: placa, marca, modelo, año, color, activo |
| `evaluacion_psicologica` | Calificación mínima aprobatoria: 73/100. Columna generada: `aprobado` |
| `revision_vehiculo` | Calificación mínima: 65/100. Vigencia 1 año. Columnas generadas: `apto`, `proxima_revision` |
| `recarga_saldo` | Recargas de clientes: monto_usd, monto_ves, referencia, banco, tasa BCV usada |
| `traslado` | Registro central del viaje con todos los campos financieros y estados |
| `pago_chofer` | Transferencias bancarias realizadas al chofer por la empresa |
| `cupon` | Cupones de descuento: código, tipo, descuento_usd, distancia_max_km |
| `cupon_cliente` | Relación entre cliente y cupón, con campo `usado` |
| `tasa_bcv` | Historial de tasas BCV: fecha_vigencia, tasa_ves |
| `factura` | Factura fiscal generada por traslado con IGTF |
| `notificacion` | Notificaciones del sistema al usuario |

### Objetos especiales de la BD
- **Función:** `fn_distancia_km(lat1, lon1, lat2, lon2)` — fórmula Haversine implementada en MySQL
- **Stored Procedure:** `sp_solicitar_traslado` — flujo completo del viaje en transacción atómica
- **Trigger:** `trg_traslado_eventos` — registra eventos del ciclo de vida del traslado
- **Vistas SQL** que ya tienen modelo y endpoint de reporte:
  - Historial de traslados → modelo `HistorialTraslados`
  - Ganancias de la empresa → modelo `GananciasEmpresa`
  - Pagos por chofer → modelo `PagosPorChofer`
  - Pendientes de pago → modelo `PendientesPagoChofer`
  - Traslados cancelados → modelo `TrasladosCancelados`
  - Facturas emitidas → modelo `FacturasEmitidas`
  - Notificaciones pendientes → modelo `NotificacionesPendientes`

### Columnas generadas automáticamente por MySQL
- `evaluacion_psicologica.aprobado` → `calificacion >= 73`
- `revision_vehiculo.apto` → `calificacion >= 65`
- `revision_vehiculo.proxima_revision` → `fecha_revision + 1 año`

---

## 6. REGLAS DE NEGOCIO CRÍTICAS

### Habilitación del chofer (dos etapas)
1. El chofer crea su cuenta y registra datos, vehículo y contactos de emergencia → queda como `habilitado = 0`
2. El personal administrativo registra la evaluación psicológica (mín. 73) y la revisión vehicular (mín. 65) → si ambas aprueban, `habilitado = 1`

### Algoritmo Híbrido Dinámico de tarifas
```
Costo Final (USD) = [Tarifa Base + (Distancia_km × $0.45)] × Factor_Hora_Pico + Recargo_Horario
```
- **Tarifa base:** $1.00 USD (banderazo)
- **Costo por km:** $0.45 USD (distancia calculada con Haversine)
- **Recargo horario:** $1.50 USD si es nocturno (7PM–5AM) o fin de semana (no acumulable)
- **Factor hora pico:** ×1.20 (7–9AM), ×1.15 (11:30AM–1PM), ×1.25 (5–7PM), ×1.00 resto
- **Descuento universitario:** ×0.70 si el cliente es estudiante Y el destino es sede universitaria
- **Primer viaje:** $0.00 para el cliente; la empresa subsidia el 70% al chofer
- **Cupones:** descuento en USD hasta llegar a $0.00

### Distribución financiera (regla 70/30)
- **Chofer recibe:** 70% de la tarifa base (antes de descuentos al cliente)
- **Empresa retiene:** 30% de la tarifa base
- Los descuentos al cliente los absorbe la empresa, nunca el chofer

### Tasa BCV
- Se almacena en USD, se muestra en VES
- Consulta siempre la tasa más reciente disponible (cubre fines de semana y feriados):
```sql
SELECT tasa_ves FROM tasa_bcv WHERE fecha_vigencia <= CURDATE() ORDER BY fecha_vigencia DESC LIMIT 1;
```

### Asignación de chofer por proximidad
1. Busca choferes habilitados, disponibles y con vehículo apto en radio de 5 km del origen
2. Si no hay, amplía a 10 km, luego 15 km
3. Selecciona aleatoriamente del pool encontrado
4. El chofer tiene 30 segundos para aceptar; si no responde o rechaza, se selecciona otro
5. Tras 3 rechazos consecutivos: se notifica al cliente que no hay servicio disponible

---

## 7. CONVENCIONES DE CÓDIGO (OBLIGATORIAS)

1. **Código en inglés** — nombres de clases, métodos, variables, endpoints (URLs)
2. **Modelos y entidades de negocio en español** — nombres de clases modelo que representan tablas pueden mantenerse en español (`Chofer`, `Zona`, `Traslado`) porque corresponden al dominio del negocio documentado en español
3. **Comentarios en español** — todos los comentarios explicativos
4. **Endpoints/URLs en inglés, kebab-case** — ejemplo: `/api/zones`, `/api/driver-payments`
5. **Paquete `model`** (NO `entity`)
6. **Inyección de dependencias por constructor** (como en los controllers existentes)
7. **Respuesta JSON unificada** con `HashMap<String, Object>`:
```json
{ "success": true, "data": { }, "message": "OK" }
```
8. **Manejo de errores:** try/catch que devuelve `success: false` + mensaje, con código HTTP apropiado (400, 404). Nunca exponer stack traces.
9. **Javadoc/comentario en el encabezado** de cada endpoint indicando método y ruta

---

## 8. ENDPOINTS REALES IMPLEMENTADOS (Johanna) — URLs EN INGLÉS

> **NOTA:** Las URLs fueron migradas de español a inglés el 24/06/2026 para alinearse con la convención del proyecto. Esta tabla refleja el estado OFICIAL y definitivo.

### CatalogoController — `@RequestMapping("/api")`
| Método | URL inglés | Descripción |
|---|---|---|
| GET | `/api/zones` | Zonas activas |
| GET | `/api/zones/all` | Todas las zonas sin filtro (admin) |
| GET | `/api/banks` | Bancos activos |
| GET | `/api/banks/all` | Todos los bancos sin filtro (admin) |

### TasaBcvController — `@RequestMapping("/api")`
| Método | URL inglés | Descripción |
|---|---|---|
| GET | `/api/exchange-rate/current` | Tasa BCV vigente (cubre feriados/fines de semana) |
| GET | `/api/exchange-rate/history` | Historial de tasas |
| POST | `/api/exchange-rate` | Registrar nueva tasa (admin) |

### PagoController — `@RequestMapping("/api")`
| Método | URL inglés | Descripción |
|---|---|---|
| POST | `/api/top-ups` | Cliente recarga su saldo |
| GET | `/api/top-ups/client/{id}` | Historial de recargas de un cliente |
| POST | `/api/driver-payments` | Admin registra pago a chofer |
| GET | `/api/driver-payments/driver/{id}` | Historial de pagos de un chofer |

### ReporteController — `@RequestMapping("/api/reports")`
| Método | URL inglés | Descripción |
|---|---|---|
| GET | `/api/reports/trip-history` | Historial de traslados |
| GET | `/api/reports/earnings` | Ganancias de la empresa |
| GET | `/api/reports/driver-payments` | Pagos por chofer |
| GET | `/api/reports/pending-payments` | Traslados pendientes de pago |
| GET | `/api/reports/cancelled` | Traslados cancelados |
| GET | `/api/reports/invoices` | Facturas emitidas |
| GET | `/api/reports/notifications` | Notificaciones pendientes |

---

## 9. ENDPOINTS DE ELIUBER (autenticación)

Ya implementados por Eliuber (paquete `security`, JWT):
- `POST /api/auth/login` — login con JWT
- `POST /api/auth/register/client` — registro de cliente
- `POST /api/auth/register/driver` — registro de chofer

Pendientes — Johanna apoya a Eliuber con estos dos (acordado por WhatsApp 24/06):
- Registro/carga de **vehículos** del chofer
- Registro de **evaluación psicológica** y **revisión vehicular** (admin)

Pendiente central:
- `POST /api/trip-request` — llama a `sp_solicitar_traslado` con `SimpleJdbcCall` o `@Query(nativeQuery=true)`

**JWT:** Eliuber maneja el token en el paquete `security`. Antes de construir endpoints de admin que verifiquen rol, Johanna debe revisar cómo está estructurado el token (qué campos lleva: idUsuario, rol, etc.).

---

## 10. FLUJO GIT DEL PROYECTO

```
master (producción final)
  └── develop (integración)
        ├── feature/backend-johanna   ← Johanna
        ├── feature/backend-eliuber   ← Eliuber
        ├── frontend-freddy           ← Freddy
        ├── feature/frontend-manuel   ← Manuel
        └── feature/frontend-angel    ← Ángel
```

**Reglas Git:**
- Nunca commit directo a `develop` ni a `master`
- Cada feature branch se une a `develop` solo cuando funciona en aislado
- Si Johanna o Eliuber cambian nombres de campos en el JSON de respuesta, avisar al grupo de WhatsApp
- **Recordatorio para todos:** revisar las ramas de los compañeros antes de construir integraciones, para detectar inconsistencias a tiempo

---

## 11. INSTRUCCIONES PARA CLAUDE CODE

1. Cumplir SIEMPRE las reglas innegociables de la Sección 0.
2. Guiar paso a paso. Explicar términos técnicos nuevos.
3. Antes de crear cualquier archivo, preguntar en qué paquete va y confirmar.
4. Respetar las convenciones de la Sección 7 en todo el código.
5. Seguir la estructura existente: mismo formato de controller, mismo manejo de respuesta `HashMap`, misma inyección por constructor, mismos comentarios en español.
6. Verificar que las importaciones sean correctas para Spring Boot 3.5 y Java 17.
7. Para `sp_solicitar_traslado`: el procedimiento ya existe en MySQL, solo invocarlo desde Java.
8. Mostrar siempre el plan y los cambios propuestos ANTES de tocar archivos, y esperar aprobación.
