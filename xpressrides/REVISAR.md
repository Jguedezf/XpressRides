# REVISAR

Transcripción del documento **"Informe Técnico Backend v3 — XpressRides (Decarrerita)"**.

> Auditoría: 25 de junio de 2026
> BUILD SUCCESS · 126 archivos Java · 0 errores
> UNEG · Sistemas de Base de Datos I · Entrega: 5 de julio de 2026

## Resumen Ejecutivo

Backend en estado avanzado y funcional.

La rama `integration/backend` compila limpio: BUILD SUCCESS con 126 archivos Java y 0 errores. El merge de Johanna y Eliuber fue exitoso.

---

## Base de Datos

### Tablas (18)

- usuario
- cliente
- chofer
- personal_admin
- banco
- zona
- contacto_emergencia
- vehiculo
- evaluacion_psicologica
- revision_vehiculo
- tasa_bcv
- traslado
- pago_chofer
- cupon
- cupon_cliente
- recarga_saldo
- factura
- notificacion

### Características destacadas

- Distribución financiera 70/30 entre chofer y empresa.
- Facturación con IGTF del 3%.
- Historial de tasas BCV.
- Cupones y descuentos.
- Notificaciones.
- Evaluaciones psicológicas e inspecciones vehiculares.

---

## Vistas SQL (7)

- historial_traslados
- ganancias_empresa
- pagos_por_chofer
- pendientes_pago_chofer
- traslados_cancelados
- facturas_emitidas
- notificaciones_pendientes

Observación:

- Todos los modelos son `@Immutable`.
- Solo lectura.
- Requieren JWT.
- Actualmente cualquier usuario autenticado puede consultarlos.

---

## Servicios Java

Incluye:

- AuthService
- CustomerService
- DriverService
- VehicleService
- PsychEvaluationService
- TripService
- TripStatusService
- CatalogService
- ExchangeRateService
- PaymentService
- ReportService
- InvoiceService
- FareService
- CouponService
- UserService
- DriverRegistrationService
- NotificationService
- EmergencyContactService
- CustomUserDetailsService

---

## Estado del Frontend (Freddy)

### Implementado

- api.js centralizado con fetchAPI.
- Manejo JWT.
- Sin simulaciones ni setTimeout.

### Problemas detectados

- login.js usa URL incorrecta.
- registro.js usa URL incorrecta.
- dashboard.js usa endpoint incorrecto para solicitar viaje.
- user-profile.js aún no conectado al backend.
- cliente-record.js y notifications.js filtran información del lado cliente.

### Pantallas pendientes

- Dashboard de chofer.
- Dashboard administrador.
- Registro de vehículo.
- Perfil editable del cliente.
- Preview de tarifa.

---

## Manual de Integración

### Login

Endpoint correcto:

`/api/auth/iniciar-sesion`

Respuesta:

- username
- role
- accesToken
- refreshToken
- message

Observación:

`accesToken` contiene un error tipográfico en el backend.

---

## Solicitud de Viaje

### Preview

`POST /api/traslados/calcular-tarifa`

### Crear viaje

`POST /api/traslado/solicitar`

---

## Flujo de Recarga

1. Obtener tasa BCV.
2. Obtener bancos.
3. Registrar recarga.

Endpoints:

- `/api/tasa-bcv/vigente`
- `/api/bancos`
- `/api/recargas`

---

## Estados del Traslado

Secuencia válida:

1. solicitado
2. aceptado
3. en_camino
4. chofer_llego
5. en_progreso
6. completado

---

## Problemas Críticos

### C1

login.js usa:

`/api/auth/login`

Debe usar:

`/api/auth/iniciar-sesion`

### C2

registro.js usa:

`/api/auth/register-cliente`

Debe usar:

`/api/auth/registro`

### C3

dashboard.js usa:

`/api/solicitar-viaje`

Debe usar:

`/api/traslado/solicitar`

### C4

AuthResponse no contiene campo `success`.

---

## Problemas Importantes

- Typo: accesToken.
- POST tasa BCV sin control de roles.
- PUT users sin validación de identidad.
- Reportes sin autorización por rol.
- Pagos sin autorización por rol.
- Endpoints duplicados para cambio de estado.
- Inconsistencia singular/plural traslado/traslados.
- Configuración CORS limitada.
- Filtrado client-side de datos globales.

---

## Usuarios de Prueba

### Chofer

Usuario: carlosr

Contraseña: password

### Cliente

Usuario: laurap

Contraseña: password

Saldo inicial: 20 USD

---

## Arquitectura SQL

### Función

`fn_distancia_km`

Implementa Haversine.

### Trigger

`trg_traslado_eventos`

Registra cambios de estado.

### Stored Procedure

`sp_solicitar_traslado`

Realiza:

1. Obtención tasa BCV.
2. Cálculo distancia.
3. Tarifa dinámica.
4. Primer viaje gratis.
5. Descuento estudiantil.
6. Aplicación de cupones.
7. Validación de saldo.
8. Descuento saldo.
9. Asignación de chofer.
10. Creación traslado.
11. Generación factura.
12. Distribución financiera.

---

## Tarifas

Variables:

- Tarifa base.
- Distancia.
- Recargo nocturno.
- Recargo fin de semana.
- Hora pico.
- Cupón.
- Descuento estudiantil.
- Primer viaje gratis.

---

## Habilitación Automática de Choferes

Condiciones:

- Inspección vehicular aprobada.
- Evaluación psicológica aprobada.

Si ambas se cumplen:

`driver.enabled = true`

---

## Distribución Financiera

### Reparto

- 70% chofer.
- 30% empresa.

### IGTF

- 3% sobre monto USD.

---

## Pendientes por Persona

### Johanna

- Commit de cambios.
- Agregar PreAuthorize.
- Validar identidad de usuarios.

### Eliuber

- Estandarizar respuestas.
- Corregir accesToken.
- Mejorar autorización.

### Freddy

- Corregir URLs críticas.
- Ajustar login.
- Crear panel chofer.
- Agregar preview de tarifa.
- Sustituir filtrado client-side.

---

## Flujo de Rechazo de Viajes

Implementado:

- Contador de rechazos.
- Reasignación automática.
- Cancelación tras 3 rechazos.
- Notificación al cliente.

Endpoint:

`PUT /api/chofer/traslados/{id}/rechazar`

---

## Panel Administrativo

Endpoints:

- GET /api/admin/choferes
- GET /api/admin/clientes
- GET /api/admin/traslados/activos

Protegidos para:

- administrador
- personal_admin

---

## Estado General

- 18 tablas.
- 7 vistas.
- 18 controladores.
- 45+ endpoints.
- 20+ servicios.
- 126 archivos Java.
- 1 stored procedure.
- 1 función.
- 1 trigger.
- 0 errores de compilación.

El backend se considera avanzado y cercano a integración completa. Las correcciones críticas identificadas deben resolverse antes del merge final a `develop` y de la entrega de la materia.
