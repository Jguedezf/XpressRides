package com.xpressrides.backend.service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import com.xpressrides.backend.dto.PsychEvaluationStatus;
import com.xpressrides.backend.dto.VehicleInspectionStatus;
import com.xpressrides.backend.dto.response.DriverStatusResponse;
import com.xpressrides.backend.exception.BadRequestException;
import com.xpressrides.backend.exception.ResourceNotFoundException;
import com.xpressrides.backend.model.Customer;
import com.xpressrides.backend.model.Driver;
import com.xpressrides.backend.model.Notification;
import com.xpressrides.backend.model.EmergencyContact;
import com.xpressrides.backend.model.PsychologicalEvaluation;
import com.xpressrides.backend.model.Trip;
import com.xpressrides.backend.model.User;
import com.xpressrides.backend.model.Vehicle;
import com.xpressrides.backend.model.VehicleInspection;
import com.xpressrides.backend.repository.DriverRepository;
import com.xpressrides.backend.repository.EmergencyContactRepository;
import com.xpressrides.backend.repository.NotificationRepository;
import com.xpressrides.backend.repository.PsychologicalEvaluationRepository;
import com.xpressrides.backend.repository.TripRepository;
import com.xpressrides.backend.repository.VehicleInspectionRepository;
import com.xpressrides.backend.repository.VehicleRepository;

@Service
public class DriverService {
    private final DriverRepository driverRepository;
    private final PsychologicalEvaluationRepository psychEvalRepository;
    private final VehicleRepository vehicleRepository;
    private final VehicleInspectionRepository vehicleInspectionRepository;
    private final TripRepository tripRepository;
    private final EmergencyContactRepository emergencyContactRepository;
    private final NotificationRepository notificationRepository;
    private final com.xpressrides.backend.repository.UserRepository userRepository;
    private final com.xpressrides.backend.repository.CustomerRepository customerRepository;

    public DriverService(DriverRepository driverRepository,
            PsychologicalEvaluationRepository psychEvalRepository,
            VehicleRepository vehicleRepository,
            VehicleInspectionRepository vehicleInspectionRepository,
            TripRepository tripRepository,
            EmergencyContactRepository emergencyContactRepository,
            NotificationRepository notificationRepository,
            com.xpressrides.backend.repository.UserRepository userRepository,
            com.xpressrides.backend.repository.CustomerRepository customerRepository) {
        this.driverRepository            = driverRepository;
        this.psychEvalRepository         = psychEvalRepository;
        this.vehicleRepository           = vehicleRepository;
        this.vehicleInspectionRepository = vehicleInspectionRepository;
        this.tripRepository              = tripRepository;
        this.emergencyContactRepository  = emergencyContactRepository;
        this.notificationRepository      = notificationRepository;
        this.userRepository              = userRepository;
        this.customerRepository          = customerRepository;
    }

    public void toggleAvailability(String username, boolean available) {
        Driver driver = driverRepository.findByUsername_Username(username)
            .orElseThrow(() -> new ResourceNotFoundException("Chofer no encontrado"));
        driver.setAvailable(available);
        driverRepository.save(driver);
    }

    public void toggleEnabled(Integer driverId, boolean enabled) {
        Driver driver = driverRepository.findById(driverId)
            .orElseThrow(() -> new ResourceNotFoundException("Chofer no encontrado"));
        driver.setEnabled(enabled);
        driverRepository.save(driver);
    }

    public DriverStatusResponse getStatus(String username) {
        Driver driver = driverRepository.findByUsername_Username(username)
            .orElseThrow(() -> new ResourceNotFoundException("Chofer no encontrado"));

        DriverStatusResponse response = new DriverStatusResponse();
        response.setDriverId(driver.getId());
        response.setEnabled(driver.isEnabled());
        response.setAvailable(driver.isAvailable());

        PsychologicalEvaluation lastEval = psychEvalRepository
            .findFirstByDriver_IdOrderByEvaluationDateDesc(driver.getId()).orElse(null);
        response.setPsychEvaluation(buildPsychStatus(lastEval));

        Vehicle vehicle = vehicleRepository.findByDriver_IdAndInUseTrue(driver.getId()).orElse(null);
        VehicleInspection lastInsp = null;
        if (vehicle != null) {
            lastInsp = vehicleInspectionRepository
                .findFirstByVehicle_IdOrderByInspectionDateDesc(vehicle.getId()).orElse(null);
        }
        response.setVehicleInspection(buildInspectionStatus(lastInsp));

        boolean qualified = driver.isEnabled() && driver.isAvailable()
            && response.getPsychEvaluation() != null && response.getPsychEvaluation().isValid()
            && response.getVehicleInspection() != null && response.getVehicleInspection().isValid();
        response.setQualified(qualified);

        return response;
    }

    public List<Trip> getTrips(String username, LocalDate desde, LocalDate hasta) {
        if (desde != null && hasta != null) {
            return tripRepository
                .findByDriver_Username_UsernameAndRequestDateBetweenOrderByRequestDateDesc(
                    username, desde.atStartOfDay(), hasta.atTime(23, 59, 59));
        }
        return tripRepository.findByDriver_Username_UsernameOrderByRequestDateDesc(username);
    }

    public List<Trip> getCancelledTrips(String username, LocalDate desde, LocalDate hasta) {
        if (desde != null && hasta != null) {
            return tripRepository
                .findByDriver_Username_UsernameAndStatusAndRequestDateBetweenOrderByRequestDateDesc(
                    username, "cancelado", desde.atStartOfDay(), hasta.atTime(23, 59, 59));
        }
        return tripRepository.findByDriver_Username_UsernameAndStatusOrderByRequestDateDesc(
                username, "cancelado");
    }

    public Trip getTripDetail(String username, Integer tripId) {
        return tripRepository.findByIdAndDriver_Username_Username(tripId, username)
            .orElseThrow(() -> new ResourceNotFoundException("Traslado no encontrado"));
    }

    @Transactional
    public void updateTripStatus(String username, Integer tripId, String newStatus) {
        Trip trip = tripRepository.findByIdAndDriver_Username_Username(tripId, username)
            .orElseThrow(() -> new ResourceNotFoundException("Traslado no encontrado"));

        String current = trip.getStatus();

        boolean validTransition = switch (current) {
            case "solicitado"   -> "aceptado".equals(newStatus);
            case "aceptado"     -> "en_camino".equals(newStatus);
            case "en_camino"    -> "chofer_llego".equals(newStatus);
            case "chofer_llego" -> "en_progreso".equals(newStatus);
            case "en_progreso"  -> "completado".equals(newStatus);
            default -> false;
        };

        if (!validTransition) {
            throw new BadRequestException("Transición de estado inválida: " + current + " → " + newStatus);
        }

        trip.setStatus(newStatus);

        if ("aceptado".equals(newStatus))    trip.setAcceptanceDate(LocalDateTime.now());
        if ("en_progreso".equals(newStatus)) trip.setStartDate(LocalDateTime.now());
        if ("completado".equals(newStatus)) {
            LocalDateTime now = LocalDateTime.now();
            trip.setEndDate(now);
            if (trip.getStartDate() != null) {
                long minutes = java.time.Duration.between(trip.getStartDate(), now).toMinutes();
                trip.setDurationMinutes((int) minutes);
            }
            
            Driver driver = trip.getDriver();
            if (driver != null) {
                if (trip.getDriverAmountUsd() != null) {
                    driver.setBalance(driver.getBalance().add(trip.getDriverAmountUsd()));
                }
                driver.setAvailable(true);
                driverRepository.save(driver);
            }
        }

        tripRepository.save(trip);
    }

    @Transactional
    public void cancelTrip(String username, Integer tripId, String motivo) {
        Trip trip = tripRepository.findByIdAndDriver_Username_Username(tripId, username)
            .orElseThrow(() -> new ResourceNotFoundException("Traslado no encontrado"));

        if ("completado".equals(trip.getStatus()) || "cancelado".equals(trip.getStatus())) {
            throw new BadRequestException("No se puede cancelar un viaje " + trip.getStatus());
        }

        trip.setStatus("cancelado");
        trip.setCancelledBy("chofer");
        trip.setCancellationReason(motivo);
        tripRepository.save(trip);

        // Refund the customer
        if (trip.getCustomerCostUsd() != null) {
            Customer customer = trip.getCustomer();
            customer.setBalance(customer.getBalance().add(trip.getCustomerCostUsd()));
            customerRepository.save(customer);
        }

        driverRepository.findByUsername_Username(username).ifPresent(driver -> {
            driver.setAvailable(true);
            driverRepository.save(driver);
        });

        Notification notif = new Notification();
        notif.setUser(trip.getCustomer().getUserId());
        notif.setTrip(trip);
        notif.setType("viaje_cancelado");
        notif.setMessage("Tu chofer canceló el viaje. Por favor solicita un nuevo traslado.");
        notif.setRead(false);
        notif.setDateTime(LocalDateTime.now());
        notificationRepository.save(notif);

        Notification notifChofer = new Notification();
        notifChofer.setUser(trip.getDriver().getUsername());
        notifChofer.setTrip(trip);
        notifChofer.setType("viaje_cancelado");
        notifChofer.setMessage("Has cancelado el viaje exitosamente.");
        notifChofer.setRead(false);
        notifChofer.setDateTime(LocalDateTime.now());
        notificationRepository.save(notifChofer);
    }

    public Map<String, Object> getProfile(String username) {
        Driver driver = driverRepository.findByUsername_Username(username)
            .orElseThrow(() -> new ResourceNotFoundException("Chofer no encontrado"));
        User user = driver.getUsername();
        List<EmergencyContact> contacts = emergencyContactRepository.findByDriver_Id(driver.getId());
        List<Vehicle> vehicles = vehicleRepository.findByDriver_Id(driver.getId());

        PsychologicalEvaluation lastEval = psychEvalRepository
            .findFirstByDriver_IdOrderByEvaluationDateDesc(driver.getId()).orElse(null);

        List<Map<String, Object>> contactList = contacts.stream().map(c -> {
            Map<String, Object> cm = new HashMap<>();
            cm.put("nombre", c.getName());
            cm.put("telefono", c.getPhone());
            cm.put("parentesco", c.getRelationship());
            return cm;
        }).collect(Collectors.toList());

        Map<String, Object> profile = new HashMap<>();
        profile.put("id", driver.getId());
        profile.put("nombre", user.getName());
        profile.put("apellido", user.getLastName());
        profile.put("cedula", user.getCi());
        profile.put("username", user.getUsername());
        profile.put("email", user.getEmail());
        profile.put("telefono", user.getPhone());
        profile.put("banco", driver.getBank() != null ? driver.getBank().getName() : null);
        profile.put("numeroCuenta", driver.getAccountNumber());
        profile.put("saldoAcumuladoUsd", driver.getBalance());
        profile.put("habilitado", driver.isEnabled());
        profile.put("disponible", driver.isAvailable());
        Double avgRating = tripRepository.findAverageRatingByDriverId(driver.getId());
        profile.put("calificacion", avgRating != null ? avgRating : 0.0);
        
        profile.put("contactosEmergencia", contactList);
        
        List<Map<String, Object>> vehicleList = vehicles.stream().map(v -> {
            Map<String, Object> vehData = new HashMap<>();
            vehData.put("id", v.getId());
            vehData.put("placa", v.getPlate());
            vehData.put("marca", v.getBrand());
            vehData.put("modelo", v.getModel());
            vehData.put("anioFabricacion", v.getYear());
            vehData.put("color", v.getColor());
            vehData.put("activo", v.getActive());
            vehData.put("enUso", v.getInUse());

            VehicleInspection vehLastInsp = vehicleInspectionRepository
                .findFirstByVehicle_IdOrderByInspectionDateDesc(v.getId()).orElse(null);
            if (vehLastInsp != null) {
                Map<String, Object> vehInspData = new HashMap<>();
                vehInspData.put("calificacion", vehLastInsp.getScore());
                vehInspData.put("fecha", vehLastInsp.getInspectionDate());
                vehInspData.put("observacion", vehLastInsp.getObservation());
                vehData.put("ultimaRevision", vehInspData);
            }
            return vehData;
        }).collect(Collectors.toList());
        profile.put("vehiculos", vehicleList);

        if (lastEval != null) {
            Map<String, Object> evalData = new HashMap<>();
            evalData.put("calificacion", lastEval.getScore());
            evalData.put("fecha", lastEval.getEvaluationDate());
            evalData.put("observacion", lastEval.getObservation());
            profile.put("evaluacionPsicologica", evalData);
        }

        return profile;
    }

    public List<Map<String, Object>> getReviews(String username) {
        Driver driver = driverRepository.findByUsername_Username(username)
            .orElseThrow(() -> new ResourceNotFoundException("Chofer no encontrado"));
            
        List<Trip> trips = tripRepository.findByDriver_Username_UsernameOrderByRequestDateDesc(username);
        return trips.stream()
            .filter(t -> t.getStarRating() != null)
            .map(t -> {
                Map<String, Object> map = new java.util.HashMap<>();
                map.put("tripId", t.getId());
                map.put("starRating", t.getStarRating());
                map.put("comment", t.getCustomerComment());
                map.put("date", t.getRequestDate());
                
                String customerName = "Desconocido";
                if (t.getCustomer() != null && t.getCustomer().getUserId() != null) {
                    User customerUser = t.getCustomer().getUserId();
                    String name = customerUser.getName();
                    String lastName = customerUser.getLastName();
                    if (name != null && !name.trim().isEmpty()) {
                        customerName = (lastName != null && !lastName.trim().isEmpty()) ? name + " " + lastName : name;
                    }
                }
                map.put("customerName", customerName);
                return map;
            })
            .collect(java.util.stream.Collectors.toList());
    }

    @Transactional(readOnly = true)
    public Map<String, Object> getActiveTrip(String username) {
        List<String> activeStatuses = List.of("solicitado", "aceptado", "en_camino", "chofer_llego", "en_progreso");
        Optional<Trip> tripOpt = tripRepository
            .findFirstByDriver_Username_UsernameAndStatusInOrderByRequestDateDesc(
                username, activeStatuses);

        if (tripOpt.isEmpty()) return null;

        Trip trip = tripOpt.get();
        Customer customer = trip.getCustomer();
        User clientUser = customer.getUserId();

        Map<String, Object> clienteData = new HashMap<>();
        clienteData.put("nombre", clientUser.getName() + " " + clientUser.getLastName());
        clienteData.put("telefono", clientUser.getPhone());

        Map<String, Object> data = new HashMap<>();
        data.put("idTraslado", trip.getId());
        data.put("estado", trip.getStatus());
        data.put("cliente", clienteData);
        data.put("origen", trip.getOriginZone() != null ? trip.getOriginZone().getName() : trip.getOriginAddress());
        data.put("destino", trip.getDestinationZone() != null ? trip.getDestinationZone().getName() : trip.getDestinationAddress());
        data.put("origenLat", trip.getOriginLat());
        data.put("origenLng", trip.getOriginLng());
        data.put("destinoLat", trip.getDestinationLat());
        data.put("destinoLng", trip.getDestinationLng());
        data.put("costoUsd", trip.getCustomerCostUsd());
        data.put("distanciaKm", trip.getDistanceKm());
        data.put("nroPasajeros", trip.getPassengerCount());
        data.put("fechaSolicitud", trip.getRequestDate());
        data.put("fechaAsignacionActual", trip.getCurrentAssignmentDate());

        return data;
    }

    // Empuja el estado del viaje activo del chofer por Server-Sent Events en vez
    // de que el frontend haga polling — reemplaza el setInterval de chofer-viaje.js.
    public SseEmitter streamActiveTrip(String username) {
        return TripStreamHelper.stream(() -> getActiveTrip(username));
    }

    private PsychEvaluationStatus buildPsychStatus(PsychologicalEvaluation eval) {
        PsychEvaluationStatus status = new PsychEvaluationStatus();
        if (eval == null) {
            status.setApproved(false);
            status.setValid(false);
            return status;
        }
        status.setApproved(eval.isApproved());
        status.setEvaluationDate(eval.getEvaluationDate());
        status.setValid(eval.isApproved()
            && eval.getEvaluationDate().plusYears(1).isAfter(LocalDate.now()));
        return status;
    }

    private VehicleInspectionStatus buildInspectionStatus(VehicleInspection inspection) {
        VehicleInspectionStatus status = new VehicleInspectionStatus();
        if (inspection == null) {
            status.setFitForUse(false);
            status.setValid(false);
            return status;
        }
        status.setFitForUse(inspection.isFitForUse());
        status.setNextInspectionDate(inspection.getNextInspectionDate());
        status.setValid(inspection.isFitForUse()
            && inspection.getNextInspectionDate() != null
            && !inspection.getNextInspectionDate().isBefore(LocalDate.now()));
        return status;
    }

    @Transactional
    public void requestWithdrawal(String username) {
        Driver driver = driverRepository.findByUsername_Username(username)
            .orElseThrow(() -> new ResourceNotFoundException("Chofer no encontrado"));
        if (driver.getBalance().compareTo(java.math.BigDecimal.ZERO) <= 0) {
            throw new BadRequestException("No tienes saldo pendiente para retirar.");
        }
        
        List<User> admins = userRepository.findByActiveTrueAndRole("personal_admin");
        
        String mensaje = "El chofer " + driver.getUsername().getName() + " " + driver.getUsername().getLastName() 
                + " ha solicitado el pago de su deuda de $" + driver.getBalance() + ".";
                
        for (User admin : admins) {
            Notification notification = new Notification();
            notification.setDateTime(LocalDateTime.now());
            notification.setType("RETIRO");
            notification.setMessage(mensaje);
            notification.setRead(false);
            notification.setUser(admin);
            notificationRepository.save(notification);
        }
    }

    @Transactional
    public void updateLocation(String username, Double lat, Double lng) {
        if (lat == null || lng == null) {
            throw new BadRequestException("Las coordenadas están fuera de Ciudad Guayana.");
        }
        if (Double.isNaN(lat) || Double.isNaN(lng)) {
            throw new BadRequestException("Las coordenadas no pueden ser valores no numéricos (NaN).");
        }
        if (lat <= 7.8 || lat >= 8.7 || lng <= -63.2 || lng >= -62.1) {
            throw new BadRequestException("Las coordenadas están fuera de Ciudad Guayana.");
        }
        Driver driver = driverRepository.findByUsername_Username(username)
            .orElseThrow(() -> new ResourceNotFoundException("Chofer no encontrado"));
        driver.setLatActual(java.math.BigDecimal.valueOf(lat));
        driver.setLngActual(java.math.BigDecimal.valueOf(lng));
        driver.setUbicacionActualizadaEn(LocalDateTime.now());
        driverRepository.save(driver);
    }
}
