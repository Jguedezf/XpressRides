package com.xpressrides.backend.service;

import java.math.BigDecimal;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.xpressrides.backend.dto.request.CustomerProfileRequest;
import com.xpressrides.backend.dto.request.RatingRequest;
import com.xpressrides.backend.dto.response.CustomerProfileResponse;
import com.xpressrides.backend.exception.BadRequestException;
import com.xpressrides.backend.exception.ResourceNotFoundException;
import com.xpressrides.backend.model.Customer;
import com.xpressrides.backend.model.CustomerCoupon;
import com.xpressrides.backend.model.Driver;
import com.xpressrides.backend.model.Notification;
import com.xpressrides.backend.model.Trip;
import com.xpressrides.backend.model.User;
import com.xpressrides.backend.model.TopUp;
import com.xpressrides.backend.model.Vehicle;
import com.xpressrides.backend.repository.CustomerCouponRepository;
import com.xpressrides.backend.repository.CustomerRepository;
import com.xpressrides.backend.repository.DriverRepository;
import com.xpressrides.backend.repository.NotificationRepository;
import com.xpressrides.backend.repository.TopUpRepository;
import com.xpressrides.backend.repository.TripRepository;
import com.xpressrides.backend.repository.UserRepository;

@Service
public class CustomerService {

    private final CustomerRepository customerRepository;
    private final UserRepository userRepository;
    private final TripRepository tripRepository;
    private final CustomerCouponRepository customerCouponRepository;
    private final TopUpRepository topUpRepository;
    private final DriverRepository driverRepository;
    private final NotificationRepository notificationRepository;

    // Ventana de tiempo (en minutos) tras el registro durante la cual un cliente
    // puede agregar el código de quien lo refirió si no lo hizo antes. Vive en
    // application.properties (no hardcodeada) para poder acortarla el día de la
    // defensa y demostrar el vencimiento del plazo sin esperar 24h reales.
    private final long ventanaMinutosReferido;

    public CustomerService(CustomerRepository customerRepository,
                           UserRepository userRepository,
                           TripRepository tripRepository,
                           CustomerCouponRepository customerCouponRepository,
                           TopUpRepository topUpRepository,
                           DriverRepository driverRepository,
                           NotificationRepository notificationRepository,
                           @Value("${referidos.ventana-minutos:1440}") long ventanaMinutosReferido) {
        this.customerRepository      = customerRepository;
        this.userRepository          = userRepository;
        this.tripRepository          = tripRepository;
        this.customerCouponRepository = customerCouponRepository;
        this.topUpRepository         = topUpRepository;
        this.driverRepository        = driverRepository;
        this.notificationRepository  = notificationRepository;
        this.ventanaMinutosReferido  = ventanaMinutosReferido;
    }

    public CustomerProfileResponse getProfile(String username) {
        Customer customer = customerRepository.findByUserId_Username(username)
            .orElseThrow(() -> new ResourceNotFoundException("Cliente no encontrado"));
        return mapToProfileResponse(customer);
    }

    @Transactional
    public CustomerProfileResponse updateProfile(String username, CustomerProfileRequest request) {
        Customer customer = customerRepository.findByUserId_Username(username)
            .orElseThrow(() -> new ResourceNotFoundException("Cliente no encontrado"));
        User user = customer.getUserId();

        if (request.getName() != null) user.setName(request.getName());
        if (request.getLastName() != null) user.setLastName(request.getLastName());
        if (request.getEmail() != null) user.setEmail(request.getEmail());
        if (request.getPhone() != null) user.setPhone(request.getPhone());
        if (request.getIsStudent() != null) customer.setStudent(request.getIsStudent());

        userRepository.save(user);
        customerRepository.save(customer);
        return mapToProfileResponse(customer);
    }

    public org.springframework.data.domain.Page<Trip> getTrips(String username, org.springframework.data.domain.Pageable pageable) {
        Customer customer = customerRepository.findByUserId_Username(username)
            .orElseThrow(() -> new ResourceNotFoundException("Cliente no encontrado"));
        return tripRepository.findByCustomer_IdOrderByRequestDateDesc(customer.getId(), pageable);
    }

    public Trip getTripDetail(String username, Integer tripId) {
        Customer customer = customerRepository.findByUserId_Username(username)
            .orElseThrow(() -> new ResourceNotFoundException("Cliente no encontrado"));
        return tripRepository.findByIdAndCustomer_Id(tripId, customer.getId())
            .orElseThrow(() -> new ResourceNotFoundException("Traslado no encontrado"));
    }

    @Transactional
    public void rateTrip(String username, Integer tripId, RatingRequest request) {
        Customer customer = customerRepository.findByUserId_Username(username)
            .orElseThrow(() -> new ResourceNotFoundException("Cliente no encontrado"));
        Trip trip = tripRepository.findByIdAndCustomer_Id(tripId, customer.getId())
            .orElseThrow(() -> new ResourceNotFoundException("Traslado no encontrado"));

        if (!"completado".equals(trip.getStatus())) {
            throw new BadRequestException("Solo se puede calificar un viaje completado");
        }
        if (trip.getStarRating() != null) {
            throw new BadRequestException("Este viaje ya fue calificado");
        }

        trip.setStarRating(request.getStarRating());
        trip.setCustomerComment(request.getCustomerComment());
        tripRepository.save(trip);
    }

    @Transactional
    public void cancelTrip(String username, Integer tripId, String reason) {
        Customer customer = customerRepository.findByUserId_Username(username)
            .orElseThrow(() -> new ResourceNotFoundException("Cliente no encontrado"));
        Trip trip = tripRepository.findByIdAndCustomer_Id(tripId, customer.getId())
            .orElseThrow(() -> new ResourceNotFoundException("Traslado no encontrado"));

        if (!"solicitado".equals(trip.getStatus()) && !"aceptado".equals(trip.getStatus())) {
            throw new BadRequestException("Solo se puede cancelar un viaje solicitado o aceptado");
        }

        trip.setStatus("cancelado");
        trip.setCancelledBy("cliente");
        trip.setCancellationReason(reason);
        tripRepository.save(trip);

        // Refund the customer
        if (trip.getCustomerCostUsd() != null) {
            customer.setBalance(customer.getBalance().add(trip.getCustomerCostUsd()));
            customerRepository.save(customer);
        }

        if (trip.getDriver() != null) {
            Driver driver = trip.getDriver();
            driver.setAvailable(true);
            driverRepository.save(driver);

            Notification notif = new Notification();
            notif.setUser(driver.getUsername());
            notif.setTrip(trip);
            notif.setType("viaje_cancelado");
            notif.setMessage("El cliente canceló el viaje. Estás disponible para nuevos traslados.");
            notif.setRead(false);
            notif.setDateTime(LocalDateTime.now());
            notificationRepository.save(notif);
        }

        Notification notifCliente = new Notification();
        notifCliente.setUser(customer.getUserId());
        notifCliente.setTrip(trip);
        notifCliente.setType("viaje_cancelado");
        notifCliente.setMessage("Has cancelado el viaje exitosamente.");
        notifCliente.setRead(false);
        notifCliente.setDateTime(LocalDateTime.now());
        notificationRepository.save(notifCliente);
    }

    public List<TopUp> getTopUps(String username) {
        Customer customer = customerRepository.findByUserId_Username(username)
            .orElseThrow(() -> new ResourceNotFoundException("Cliente no encontrado"));
        return topUpRepository.findByCustomerIdOrderByDateTimeDesc(customer.getId());
    }
    @Transactional
    public List<Map<String, Object>> getReviews(String username) {
        Customer customer = customerRepository.findByUserId_Username(username)
            .orElseThrow(() -> new ResourceNotFoundException("Cliente no encontrado"));
        
        List<Trip> trips = tripRepository.findByCustomer_IdOrderByRequestDateDesc(customer.getId());
        return trips.stream()
            .filter(t -> t.getStarRating() != null)
            .map(t -> {
                Map<String, Object> map = new java.util.HashMap<>();
                map.put("tripId", t.getId());
                map.put("starRating", t.getStarRating());
                map.put("comment", t.getCustomerComment());
                map.put("date", t.getRequestDate());
                
                String origin = t.getOriginZone() != null ? t.getOriginZone().getName() : "Origen";
                String dest = t.getDestinationZone() != null ? t.getDestinationZone().getName() : "Destino";
                map.put("route", origin + " → " + dest);

                String driverName = "Desconocido";
                String driverPhone = "—";
                Map<String, Object> vehicleInfo = new java.util.HashMap<>();
                Map<String, Object> driverDetails = new java.util.HashMap<>();
                
                if (t.getDriver() != null && t.getDriver().getUsername() != null) {
                    User driverUser = t.getDriver().getUsername();
                    String name = driverUser.getName();
                    String lastName = driverUser.getLastName();
                    if (name != null && !name.trim().isEmpty()) {
                        driverName = (lastName != null && !lastName.trim().isEmpty()) ? name + " " + lastName : name;
                    }
                    driverPhone = driverUser.getPhone();
                    
                    if (t.getDriver().getPsychologicalEvaluations() != null && !t.getDriver().getPsychologicalEvaluations().isEmpty()) {
                        driverDetails.put("psychEval", t.getDriver().getPsychologicalEvaluations().get(0).getScore() + "/100");
                    }
                }
                
                if (t.getVehicle() != null) {
                    vehicleInfo.put("brand", t.getVehicle().getBrand());
                    vehicleInfo.put("model", t.getVehicle().getModel());
                    vehicleInfo.put("plate", t.getVehicle().getPlate());
                    vehicleInfo.put("color", t.getVehicle().getColor());
                    if (t.getVehicle().getInspections() != null && !t.getVehicle().getInspections().isEmpty()) {
                        vehicleInfo.put("inspection", t.getVehicle().getInspections().get(0).getScore() + "/100");
                    }
                }

                map.put("driverName", driverName);
                map.put("driverPhone", driverPhone);
                map.put("vehicle", vehicleInfo);
                map.put("driverDetails", driverDetails);
                
                return map;
            })
            .collect(java.util.stream.Collectors.toList());
    }

    // PUT /api/cliente/perfil/referido — agrega tardíamente el código de quien
    // refirió a este cliente, dentro de la ventana de tiempo permitida.
    @Transactional
    public void addReferralCode(String username, String codigoReferidoIngresado) {
        Customer customer = customerRepository.findByUserId_Username(username)
            .orElseThrow(() -> new ResourceNotFoundException("Cliente no encontrado"));

        String codigo = codigoReferidoIngresado == null ? "" : codigoReferidoIngresado.trim().toUpperCase();

        Customer referente = customerRepository.findByCodigoReferido(codigo)
            .orElseThrow(() -> new BadRequestException("Código de referido inválido."));

        if (referente.getId().equals(customer.getId())) {
            throw new BadRequestException("No puedes usar tu propio código.");
        }

        // Se valida el motivo específico ANTES de intentar el UPDATE para poder
        // devolver un mensaje preciso ("ya tienes código" vs "venció el plazo").
        // El UPDATE condicionado de abajo sigue siendo la fuente de verdad real
        // (por si el estado cambió entre esta lectura y el intento).
        if (customer.getReferidoPor() != null) {
            throw new BadRequestException("Ya tienes un código de referido asignado.");
        }

        LocalDateTime limiteVentana = customer.getCreatedAt().plusMinutes(ventanaMinutosReferido);
        if (LocalDateTime.now().isAfter(limiteVentana)) {
            throw new BadRequestException("El plazo para agregar un código de referido ya venció.");
        }

        LocalDateTime corteMinimo = LocalDateTime.now().minusMinutes(ventanaMinutosReferido);
        int filasAfectadas = customerRepository.asignarReferidoPor(customer.getId(), referente, corteMinimo);
        if (filasAfectadas == 0) {
            throw new BadRequestException("No se pudo asignar el código de referido, intenta de nuevo.");
        }
    }

    public List<CustomerCoupon> getCoupons(String username) {
        Customer customer = customerRepository.findByUserId_Username(username)
            .orElseThrow(() -> new ResourceNotFoundException("Cliente no encontrado"));
        return customerCouponRepository.findByCustomer_IdAndUsedFalse(customer.getId());
    }

    @Transactional(readOnly = true)
    public Map<String, Object> getActiveTrip(String username) {
        Customer customer = customerRepository.findByUserId_Username(username)
            .orElseThrow(() -> new ResourceNotFoundException("Cliente no encontrado"));

        List<String> activeStatuses = List.of(
            "solicitado", "aceptado", "en_camino", "chofer_llego", "en_progreso"
        );
        Optional<Trip> tripOpt = tripRepository
            .findFirstByCustomer_IdAndStatusInOrderByRequestDateDesc(
                customer.getId(), activeStatuses);

        if (tripOpt.isEmpty()) {
            return null;
        }

        Trip trip = tripOpt.get();
        Driver driver = trip.getDriver();

        Map<String, Object> choferData = null;
        if (driver != null) {
            User driverUser = driver.getUsername();
            Vehicle vehicle = trip.getVehicle();
            choferData = new HashMap<>();
            choferData.put("nombre", driverUser.getName() + " " + driverUser.getLastName());
            choferData.put("telefono", driverUser.getPhone());
            choferData.put("vehiculo", vehicle.getBrand() + " " + vehicle.getModel() + " " + vehicle.getYear());
            choferData.put("placa", vehicle.getPlate());
            choferData.put("color", vehicle.getColor());
        }

        Map<String, Object> data = new HashMap<>();
        data.put("idTraslado", trip.getId());
        data.put("estado", trip.getStatus());
        data.put("origen", trip.getOriginZone().getName());
        data.put("destino", trip.getDestinationZone().getName());
        data.put("costoEstimadoUsd", trip.getCustomerCostUsd());
        data.put("costoEstimadoVes", trip.getCustomerCostVes());
        data.put("chofer", choferData);
        data.put("tiempoEstimadoLlegadaMinutos", trip.getEtaMinutes() != null ? trip.getEtaMinutes() : 8);
        data.put("fechaSolicitud", trip.getRequestDate());
        data.put("fechaAceptacion", trip.getAcceptanceDate());

        return data;
    }

    private CustomerProfileResponse mapToProfileResponse(Customer customer) {
        User user = customer.getUserId();
        CustomerProfileResponse response = new CustomerProfileResponse();
        response.setId(customer.getId());
        response.setCi(user.getCi());
        response.setName(user.getName());
        response.setLastName(user.getLastName());
        response.setUsername(user.getUsername());
        response.setEmail(user.getEmail());
        response.setPhone(user.getPhone());
        response.setBalance(customer.getBalance());
        response.setStudent(customer.isStudent());
        response.setFirstTripUsed(customer.isFirstTripUsed());

        response.setCodigoReferido(customer.getCodigoReferido());
        response.setCuponesDisponibles(
            (int) customerCouponRepository.countByCustomer_IdAndUsedFalse(customer.getId()));
        response.setHistorialCuponesUsados(
            customerCouponRepository.findByCustomer_IdAndUsedTrue(customer.getId())
                .stream()
                .map(cc -> {
                    Map<String, Object> item = new HashMap<>();
                    item.put("codigo", cc.getCoupon().getCode());
                    item.put("tipo", cc.getCoupon().getType());
                    item.put("montoUsd", cc.getCoupon().getDiscountUsd());
                    item.put("fechaUso", cc.getUsedDate());
                    return item;
                })
                .collect(java.util.stream.Collectors.toList())
        );

        // El frontend solo debe mostrar/ocultar el campo "agregar código" según este
        // flag ya calculado en el backend — no debe calcular fechas en JS (la hora
        // del navegador del usuario no es una fuente confiable para esta regla).
        boolean yaTieneReferido = customer.getReferidoPor() != null;
        LocalDateTime limiteVentana = customer.getCreatedAt().plusMinutes(ventanaMinutosReferido);
        boolean dentroDeVentana = LocalDateTime.now().isBefore(limiteVentana);
        boolean puedeAgregar = !yaTieneReferido && dentroDeVentana;
        response.setPuedeAgregarReferido(puedeAgregar);

        if (puedeAgregar) {
            long minutosRestantes = Duration.between(LocalDateTime.now(), limiteVentana).toMinutes();
            response.setHorasRestantesReferido(Math.round((minutosRestantes / 60.0) * 10) / 10.0);
        } else {
            response.setHorasRestantesReferido(null);
        }

        return response;
    }
}
