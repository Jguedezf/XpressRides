package com.xpressrides.backend.service;

import java.time.LocalDateTime;

import org.springframework.stereotype.Service;

import com.xpressrides.backend.dto.VehicleInspectionDTO;
import com.xpressrides.backend.dto.request.InspectionRequest;
import com.xpressrides.backend.dto.request.VehicleRequest;
import com.xpressrides.backend.dto.response.InspectionResponse;
import com.xpressrides.backend.dto.response.VehicleResponse;
import com.xpressrides.backend.exception.BadRequestException;
import com.xpressrides.backend.exception.ResourceNotFoundException;
import com.xpressrides.backend.model.AdminPersonnel;
import com.xpressrides.backend.model.Driver;
import com.xpressrides.backend.model.Vehicle;
import com.xpressrides.backend.model.VehicleInspection;
import com.xpressrides.backend.repository.AdminPersonnelRepository;
import com.xpressrides.backend.repository.DriverRepository;
import com.xpressrides.backend.repository.PsychologicalEvaluationRepository;
import com.xpressrides.backend.repository.VehicleInspectionRepository;
import com.xpressrides.backend.repository.VehicleRepository;

import jakarta.persistence.EntityManager;

import java.util.Optional;

@Service
public class VehicleService {

    private VehicleRepository vehicleRepository;
    private DriverRepository driverRepository;
    private VehicleInspectionRepository vehicleInspectionRepository;
    private AdminPersonnelRepository adminPersonnelRepository;
    private final EntityManager entityManager;
    private PsychologicalEvaluationRepository psychEvalRepository;

    public VehicleService(VehicleRepository vehicleRepository, DriverRepository driverRepository,
            VehicleInspectionRepository vehicleInspectionRepository,
            AdminPersonnelRepository adminPersonnelRepository, EntityManager entityManager,
            PsychologicalEvaluationRepository psychEvalRepository) {
        this.vehicleRepository = vehicleRepository;
        this.driverRepository = driverRepository;
        this.vehicleInspectionRepository = vehicleInspectionRepository;
        this.adminPersonnelRepository = adminPersonnelRepository;
        this.entityManager = entityManager;
        this.psychEvalRepository = psychEvalRepository;
    }

    public VehicleResponse registerVehicle(VehicleRequest request){
      
        Driver driver = driverRepository.findById(request.getDriverId())
                .orElseThrow(() -> new ResourceNotFoundException("Chofer no encontrado"));

        Optional<Vehicle> existingVehicleOpt = vehicleRepository.findByDriver_Id(request.getDriverId());
        Vehicle vehicle;

        if (existingVehicleOpt.isPresent()) {
            vehicle = existingVehicleOpt.get();
            // Si la placa cambió, validamos que no esté duplicada con otro vehículo
            if (!vehicle.getPlate().equalsIgnoreCase(request.getPlate())) {
                if (vehicleRepository.existsByPlate(request.getPlate())) {
                    throw new BadRequestException("Esta placa ya esta registrada");
                }
            }
            vehicle.setPlate(request.getPlate());
            vehicle.setBrand(request.getBrand());
            vehicle.setModel(request.getModel());
            vehicle.setYear(request.getYear());
            vehicle.setColor(request.getColor());
        } else {
            if (vehicleRepository.existsByPlate(request.getPlate())) {
                throw new BadRequestException("Esta placa ya esta registrada");
            }
            vehicle = new Vehicle();
            vehicle.setDriver(driver);
            vehicle.setPlate(request.getPlate());
            vehicle.setBrand(request.getBrand());
            vehicle.setModel(request.getModel());
            vehicle.setYear(request.getYear());
            vehicle.setColor(request.getColor());
            vehicle.setActive(true);
            vehicle.setCreatedAt(LocalDateTime.now());
        }

        vehicle = vehicleRepository.save(vehicle);

        return mapToResponse(vehicle);
    }

    private VehicleResponse mapToResponse(Vehicle vehicle) {
        VehicleResponse response = new VehicleResponse();
        response.setId(vehicle.getId());
        response.setDriverId(vehicle.getDriver().getId());
        response.setPlate(vehicle.getPlate());
        response.setBrand(vehicle.getBrand());
        response.setModel(vehicle.getModel());
        response.setYear(vehicle.getYear());
        response.setColor(vehicle.getColor());
        response.setActive(vehicle.getActive());

         // Última inspección (ordenada por fecha descendente, top 1)
        VehicleInspection lastInsp = vehicleInspectionRepository.findFirstByVehicle_IdOrderByInspectionDateDesc(vehicle.getId()).orElse(null);
        if (lastInsp != null) {
            VehicleInspectionDTO dto = new VehicleInspectionDTO();
            dto.setId(lastInsp.getId());
            dto.setInspectionDate(lastInsp.getInspectionDate());
            dto.setScore(lastInsp.getScore());
            dto.setObservation(lastInsp.getObservation());
            dto.setFitForUse(lastInsp.isFitForUse());
            dto.setNextInspectionDate(lastInsp.getNextInspectionDate());
            response.setLastInspection(dto);
        }

        return response;
    }

    private void checkAndEnableDriver(Integer driverId) {
        Driver driver = driverRepository.findById(driverId).orElseThrow();

        boolean hasApprovedEval = psychEvalRepository.existsByDriver_IdAndApprovedTrue(driverId);
        if (!hasApprovedEval) return;

        Optional<Vehicle> vehicle = vehicleRepository.findByDriver_Id(driverId);
        if (vehicle.isEmpty()) return;

        Optional<VehicleInspection> latestInspection =
                vehicleInspectionRepository.findFirstByVehicle_IdOrderByInspectionDateDesc(vehicle.get().getId());

        if (latestInspection.isEmpty() || !latestInspection.get().isFitForUse()) return;

        driver.setEnabled(true);
        driverRepository.save(driver);
    }

    private VehicleInspectionDTO mapToInspectionDTO(VehicleInspection inspection) {
        VehicleInspectionDTO dto = new VehicleInspectionDTO();
        dto.setId(inspection.getId());
        dto.setInspectionDate(inspection.getInspectionDate());
        dto.setScore(inspection.getScore());
        dto.setObservation(inspection.getObservation());
        dto.setFitForUse(inspection.isFitForUse());
        dto.setNextInspectionDate(inspection.getNextInspectionDate());
        return dto;
    }

    public VehicleInspectionDTO createInspection(InspectionRequest request) {
        Vehicle vehicle = vehicleRepository.findById(request.getVehicleId())
            .orElseThrow(() -> new ResourceNotFoundException("Vehículo no encontrado"));
        AdminPersonnel admin = adminPersonnelRepository.findById(request.getAdminId())
            .orElseThrow(() -> new ResourceNotFoundException("Admin no encontrado"));

        VehicleInspection inspection = new VehicleInspection();
        inspection.setVehicle(vehicle);
        inspection.setAdmin(admin);
        inspection.setScore(request.getScore());
        inspection.setInspectionDate(request.getInspectionDate());
        inspection.setObservation(request.getObservation());
        inspection.setCreatedAt(LocalDateTime.now());

        inspection = vehicleInspectionRepository.save(inspection);
        entityManager.refresh(inspection);
        checkAndEnableDriver(vehicle.getDriver().getId());
        return mapToInspectionDTO(inspection);
    }
}


