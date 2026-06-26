# Listado y Descripción de Archivos - Proyecto XpressRides

Este documento detalla la estructura del proyecto **XpressRides**, describiendo de forma breve la función de cada archivo clave (Java, HTML, JS, CSS y configuraciones).

## 1. Frontend (Archivos Estáticos y Vistas)
Ubicación: `src/main/resources/static/`

### Vistas (HTML)
* **login.html:** Pantalla de inicio de sesión para los usuarios.
* **registro.html:** Formulario adaptativo de registro para clientes y choferes.
* **cliente-dashboard.html:** Panel central del usuario (incluye selección de zonas de origen/destino y mapa).
* **cliente-recharge.html:** Formulario para registrar recargas de saldo (transferencias/pago móvil).
* **cliente-recharge-history.html:** Pantalla para visualizar el historial de recargas.
* **cliente-record.html:** Vista del historial de traslados o viajes realizados por el cliente.
* **user-profile.html:** Pantalla de perfil principal del usuario.
* **user-personal-data.html:** Formulario para editar o ver datos personales del usuario.
* **user-support.html:** Sección de soporte técnico o ayuda para el usuario.
* **user-logout.html:** Vista o plantilla de confirmación de cierre de sesión.

### Lógica de Interfaz (JavaScript)
* **api.js:** Archivo centralizado para manejar las peticiones `fetch()` al backend y la inyección del token de seguridad (JWT).
* **login.js / registro.js:** Scripts que manejan las validaciones visuales y el envío de datos de inicio de sesión y creación de cuenta.
* **dashboard.js:** Controla la interactividad del panel principal (cálculo de distancias, interacción con mapas y solicitud de viaje).
* **cliente-recharge.js / cliente-recharge-history.js:** Lógica para enviar los datos de recargas y renderizar el historial financiero en tablas.
* **cliente-record.js:** Consume la API para obtener y mostrar en pantalla el historial de viajes del cliente.
* **notifications.js:** Script encargado de consultar, actualizar y mostrar las notificaciones no leídas en el sistema (campanita).
* **user-profile.js / user-personal-data.js:** Scripts para consultar y actualizar la información del perfil del usuario logueado.
* **user-support.js:** Lógica de la pantalla de atención y soporte técnico.

### Estilos (CSS)
* **estilos.css:** Archivo unificado de diseño (paleta de colores naranja/azul, tipografía "Inter", estilos de tarjetas y botones) basándose en el Manual de Diseño del equipo.

---

## 2. Backend (Lógica y Base de Datos)
Ubicación: `src/main/java/com/xpressrides/backend/`

### Modelos / Entidades (`model/`)
*Representan la estructura de las tablas de la base de datos en código Java.*
* **User.java / Customer.java / Driver.java / AdminPersonnel.java:** Entidades y datos específicos para cada rol del sistema.
* **Vehicle.java / VehicleInspection.java:** Información de los vehículos registrados y sus resultados de inspección técnica.
* **Trip.java / TripHistory.java / CancelledTrip.java:** Gestión principal de la tabla de traslados, su histórico y los motivos de cancelación.
* **Invoice.java / IssuedInvoice.java:** Datos para la creación de facturas y comprobantes fiscales (IGTF, IVA, etc.).
* **Coupon.java / CustomerCoupon.java:** Manejo de cupones de descuento y promociones de usuarios.
* **TopUp.java / DriverPayment.java / CompanyEarnings.java / PendingDriverPayment.java:** Gestión financiera (recargas de clientes, pagos a choferes y comisiones acumuladas por la empresa).
* **ExchangeRate.java:** Registro de la tasa de cambio oficial vigente (BCV).
* **Zone.java:** Catálogo de zonas geográficas (barrios/sectores) operadas en Ciudad Guayana.
* **Notification.java / PendingNotification.java:** Manejo y persistencia de las alertas y notificaciones.
* **Bank.java / EmergencyContact.java / PsychologicalEvaluation.java:** Datos complementarios de la base de datos (bancos disponibles, contactos y pruebas psicológicas).

### Repositorios (`repository/`)
* ***Repository.java:** (Ej: `TripRepository.java`, `UserRepository.java`, etc.). Son Interfaces que extienden de Spring Data JPA. Proveen los métodos listos (`save`, `findById`, `findAll`) para manipular la base de datos sin necesidad de escribir el SQL a mano.

### Servicios (`service/`)
*Contienen la lógica de negocio y las validaciones del sistema.*
* **AuthService.java / CustomUserDetailsService.java:** Controlan la lógica de registro, validación de contraseñas y autenticación con Spring Security.
* **TripService.java / TripStatusService.java / TripRejectionService.java:** Controlan el núcleo de la aplicación (algoritmo de solicitud de viaje, cambio de estados en tiempo real y rechazos).
* **PaymentService.java / FareService.java / ExchangeRateService.java:** Realizan cálculos matemáticos de tarifas, recargos y saldos en base a la tasa de cambio.
* **InvoiceService.java:** Lógica de ensamblaje de la factura digital tras completarse un viaje.
* **UserService.java / CustomerService.java / DriverService.java / AdminService.java:** Centralizan las consultas y manejo de cada tipo de perfil.
* *(Los demás servicios, como `CatalogService` o `CouponService`, manejan la validación de sus respectivas entidades).*

### Controladores (`controller/`)
*Exponen los "Endpoints" (URLs de la API) que el Frontend consumirá.*
* **AuthController.java:** Endpoints públicos para iniciar sesión (`/login`) o registrarse.
* **TripController.java / TripStatusController.java:** Endpoints para que el cliente pida un viaje y el chofer lo acepte/actualice.
* **PaymentController.java / FareController.java:** Endpoints financieros para recargar o calcular tarifas previas.
* **InvoiceController.java:** Endpoint para descargar o visualizar la factura.
* **ReportController.java:** Endpoints que consultan las "Vistas" SQL para generar reportes estadísticos.
* *(El resto de controladores exponen el acceso general vía API al frontend).*

### DTOs (Data Transfer Objects) (`dto/` y `dto/request/`, `dto/response/`)
* **Archivos Request/Response:** (Ej: `LoginRequest.java`, `TripResponse.java`, `InvoiceResponseDTO.java`). Son "moldes" que aseguran que entre el backend y el frontend solo viaje la información estrictamente necesaria y segura (en JSON), sin exponer estructuras completas de la base de datos.

### Seguridad (`segurity/`)
* **JwtAuthenticationFilter.java / JwtService.java:** Archivos que interceptan la conexión para asegurar que el usuario envíe un token válido antes de permitir el paso.
* **SecurityConfig.java:** Configuración del servidor para habilitar CORS (conexión con el Frontend) y proteger las rutas sensibles.
* **TokenBlacklistService.java:** Lista de tokens invalidados (fundamental para procesos de Cierre de Sesión / Logout seguro).

### Manejo de Excepciones (`exception/`)
* **GlobalExceptionHandler.java / BadRequestException.java / ResourceNotFoundException.java:** Clases diseñadas para "atrapar" errores (como "Usuario no encontrado" o "Saldo Insuficiente") e impedir que el servidor colapse, devolviendo al cliente un mensaje JSON limpio y entendible.

---

## 3. Configuraciones y Base de Datos
* **application.properties** (`src/main/resources/`): Archivo de propiedades de Spring Boot donde se configuran los datos críticos (credenciales de la base de datos MySQL, puerto, y modo del ORM Hibernate).
* **decarrerita.sql / datos_prueba.sql** (`src/main/resources/`): Scripts nativos de MySQL. Contienen las instrucciones para crear las 18 tablas, la función `Haversine` para distancias, el procedimiento central (`sp_solicitar_traslado`), vistas para los reportes administrativos y los primeros registros ("semillas") para que el sistema empiece a probarse con datos reales.
* **pom.xml:** Archivo raíz del administrador de dependencias (Maven). Se encarga de descargar las librerías necesarias como Spring Web, Spring Security, MySQL Connector, JJWT (Token) y Lombok.
* **mvnw / mvnw.cmd:** "Wrappers" de Maven que garantizan que cualquier miembro del equipo pueda compilar y ejecutar el proyecto en Windows, Mac o Linux sin tener Maven preinstalado.
