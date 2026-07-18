package com.xpressrides.backend.service;

import java.time.LocalDateTime;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.xpressrides.backend.dto.request.PsychEvaluationRequest;
import com.xpressrides.backend.dto.response.PsychEvaluationResponse;
import com.xpressrides.backend.exception.ResourceNotFoundException;
import com.xpressrides.backend.model.AdminPersonnel;
import com.xpressrides.backend.model.Driver;
import com.xpressrides.backend.model.PsychologicalEvaluation;
import com.xpressrides.backend.repository.AdminPersonnelRepository;
import com.xpressrides.backend.repository.DriverRepository;
import com.xpressrides.backend.repository.PsychologicalEvaluationRepository;
import com.xpressrides.backend.repository.VehicleRepository;
import com.xpressrides.backend.repository.VehicleInspectionRepository;
import com.xpressrides.backend.model.Vehicle;
import com.xpressrides.backend.model.VehicleInspection;

import jakarta.persistence.EntityManager;

import java.util.Optional;

@Service
public class PsychEvaluationService {

    private final DriverRepository driverRepository;
    private final AdminPersonnelRepository adminPersonnelRepository;
    private final PsychologicalEvaluationRepository psychEvalRepository;
    private final EntityManager entityManager;
    private final VehicleRepository vehicleRepository;
    private final VehicleInspectionRepository vehicleInspectionRepository;

    public PsychEvaluationService(DriverRepository driverRepository,
                                  AdminPersonnelRepository adminPersonnelRepository,
                                  PsychologicalEvaluationRepository psychEvalRepository,
                                  EntityManager entityManager,
                                  VehicleRepository vehicleRepository,
                                  VehicleInspectionRepository vehicleInspectionRepository) {
        this.driverRepository = driverRepository;
        this.adminPersonnelRepository = adminPersonnelRepository;
        this.psychEvalRepository = psychEvalRepository;
        this.entityManager = entityManager;
        this.vehicleRepository = vehicleRepository;
        this.vehicleInspectionRepository = vehicleInspectionRepository;
    }

    @Transactional
    public PsychEvaluationResponse create(PsychEvaluationRequest request) {
        Driver driver = driverRepository.findById(request.getDriverId())
            .orElseThrow(() -> new ResourceNotFoundException("Chofer no encontrado"));
        AdminPersonnel admin = adminPersonnelRepository.findById(request.getAdminId())
            .orElseThrow(() -> new ResourceNotFoundException("Admin no encontrado"));

        PsychologicalEvaluation eval = new PsychologicalEvaluation();
        eval.setDriver(driver);
        eval.setAdmin(admin);
        eval.setScore(request.getScore());
        eval.setEvaluationDate(request.getEvaluationDate());
        eval.setObservation(request.getObservation());
        eval.setCreatedAt(LocalDateTime.now());

        eval = psychEvalRepository.save(eval);
        entityManager.refresh(eval);
        checkAndEnableDriver(eval.getDriver().getId());

        PsychEvaluationResponse response = new PsychEvaluationResponse();
        response.setId(eval.getId());
        response.setDriverId(eval.getDriver().getId());
        response.setAdminId(eval.getAdmin().getId());
        response.setScore(eval.getScore());
        response.setEvaluationDate(eval.getEvaluationDate());
        response.setObservation(eval.getObservation());
        response.setApproved(eval.isApproved());
        return response;
    }

    private void checkAndEnableDriver(Integer driverId) {
        Driver driver = driverRepository.findById(driverId).orElseThrow();

        boolean hasApprovedEval = psychEvalRepository.existsByDriver_IdAndApprovedTrue(driverId);
        if (!hasApprovedEval) return;

        Optional<Vehicle> vehicle = vehicleRepository.findByDriver_IdAndInUseTrue(driverId);
        if (vehicle.isEmpty()) return;

        Optional<VehicleInspection> latestInspection =
                vehicleInspectionRepository.findFirstByVehicle_IdOrderByInspectionDateDesc(vehicle.get().getId());

        if (latestInspection.isEmpty() || !latestInspection.get().isFitForUse()) return;

        driver.setEnabled(true);
        driverRepository.save(driver);
    }
}
