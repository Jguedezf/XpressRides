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

    public DriverService(DriverRepository driverRepository,
            PsychologicalEvaluationRepository psychEvalRepository,
            VehicleRepository vehicleRepository,
            VehicleInspectionRepository vehicleInspectionRepository,
            TripRepository tripRepository,
            EmergencyContactRepository emergencyContactRepository,
            NotificationRepository notificationRepository) {
        this.driverRepository            = driverRepository;
        this.psychEvalRepository         = psychEvalRepository;
        this.vehicleRepository           = vehicleRepository;
        this.vehicleInspectionRepository = vehicleInspectionRepository;
        this.tripRepository              = tripRepository;
        this.emergencyContactRepository  = emergencyContactRepository;
        this.notificationRepository      = notificationRepository;
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

        Vehicle vehicle = vehicleRepository.findByDriver_Id(driver.getId()).orElse(null);
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

    public List<Trip> getCancelledTrips(String username) {
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
    }

    public Map<String, Object> getProfile(String username) {
        Driver driver = driverRepository.findByUsername_Username(username)
            .orElseThrow(() -> new ResourceNotFoundException("Chofer no encontrado"));
        User user = driver.getUsername();
        List<EmergencyContact> contacts = emergencyContactRepository.findByDriver_Id(driver.getId());

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
        profile.put("contactosEmergencia", contactList);
        return profile;
    }

    @Transactional(readOnly = true)
    public Map<String, Object> getActiveTrip(String username) {
        List<String> activeStatuses = List.of("solicitado", "aceptado", "chofer_llego", "en_progreso");
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
        data.put("origen", trip.getOriginZone().getName());
        data.put("destino", trip.getDestinationZone().getName());
        data.put("costoUsd", trip.getCustomerCostUsd());
        data.put("distanciaKm", trip.getDistanceKm());
        data.put("nroPasajeros", trip.getPassengerCount());
        data.put("fechaSolicitud", trip.getRequestDate());

        return data;
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
}
