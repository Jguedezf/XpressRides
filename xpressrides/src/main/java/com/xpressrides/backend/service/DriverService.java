package com.xpressrides.backend.service;

import java.time.LocalDate;
import java.util.List;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.xpressrides.backend.dto.PsychEvaluationStatus;
import com.xpressrides.backend.dto.VehicleInspectionStatus;
import com.xpressrides.backend.dto.response.DriverStatusResponse;
import com.xpressrides.backend.exception.BadRequestException;
import com.xpressrides.backend.exception.ResourceNotFoundException;
import com.xpressrides.backend.model.Driver;
import com.xpressrides.backend.model.PsychologicalEvaluation;
import com.xpressrides.backend.model.Trip;
import com.xpressrides.backend.model.Vehicle;
import com.xpressrides.backend.model.VehicleInspection;
import com.xpressrides.backend.repository.DriverRepository;
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

    public DriverService(DriverRepository driverRepository,
            PsychologicalEvaluationRepository psychEvalRepository,
            VehicleRepository vehicleRepository,
            VehicleInspectionRepository vehicleInspectionRepository,
            TripRepository tripRepository) {
        this.driverRepository = driverRepository;
        this.psychEvalRepository = psychEvalRepository;
        this.vehicleRepository = vehicleRepository;
        this.vehicleInspectionRepository = vehicleInspectionRepository;
        this.tripRepository = tripRepository;
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
                .findFirstByVehicleIdOrderByInspectionDateDesc(vehicle.getId()).orElse(null);
        }
        response.setVehicleInspection(buildInspectionStatus(lastInsp));

        boolean qualified = driver.isEnabled() && driver.isAvailable()
            && response.getPsychEvaluation() != null && response.getPsychEvaluation().isValid()
            && response.getVehicleInspection() != null && response.getVehicleInspection().isValid();
        response.setQualified(qualified);

        return response;
    }

    public List<Trip> getTrips(String username) {
        return tripRepository.findByDriver_Username_UsernameOrderByRequestDateDesc(username);
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
            case "solicitado" -> "aceptado".equals(newStatus);
            case "aceptado" -> "en_camino".equals(newStatus);
            case "en_camino" -> "en_progreso".equals(newStatus);
            case "en_progreso" -> "completado".equals(newStatus);
            default -> false;
        };

        if (!validTransition) {
            throw new BadRequestException("Transición de estado inválida: " + current + " → " + newStatus);
        }

        trip.setStatus(newStatus);
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
