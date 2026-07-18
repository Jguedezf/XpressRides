package com.xpressrides.backend.service;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

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

import java.util.List;
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

    // Registra un vehículo nuevo del chofer — un chofer puede tener varios
    // (enunciado); cada llamada crea una fila nueva, nunca edita una existente.
    // Si es el primer vehículo del chofer, queda "en uso" automáticamente —
    // así el caso común (un solo vehículo) no exige ningún paso adicional.
    @Transactional
    public VehicleResponse registerVehicle(VehicleRequest request){

        Driver driver = driverRepository.findById(request.getDriverId())
                .orElseThrow(() -> new ResourceNotFoundException("Chofer no encontrado"));

        if (vehicleRepository.existsByPlate(request.getPlate())) {
            throw new BadRequestException("Esta placa ya esta registrada");
        }

        boolean esElPrimero = vehicleRepository.findByDriver_Id(request.getDriverId()).isEmpty();

        Vehicle vehicle = new Vehicle();
        vehicle.setDriver(driver);
        vehicle.setPlate(request.getPlate());
        vehicle.setBrand(request.getBrand());
        vehicle.setModel(request.getModel());
        vehicle.setYear(request.getYear());
        vehicle.setColor(request.getColor());
        vehicle.setActive(true);
        vehicle.setInUse(esElPrimero);
        vehicle.setCreatedAt(LocalDateTime.now());

        vehicle = vehicleRepository.save(vehicle);

        return mapToResponse(vehicle);
    }

    // Marca cuál de los vehículos del chofer está usando para traslados —
    // auto-toggle transaccional: apaga el que estaba en uso antes de encender
    // el nuevo, para que nunca choque contra el índice único
    // uq_vehiculo_en_uso_por_chofer. Rechaza si el vehículo no está apto
    // (revisión vencida o reprobada) — evita que el chofer quede "habilitado"
    // pero con un vehículo que sp_solicitar_traslado nunca va a poder asignar.
    @Transactional
    public VehicleResponse activarVehiculo(Integer vehicleId, Integer driverId) {
        Vehicle vehicle = vehicleRepository.findById(vehicleId)
            .orElseThrow(() -> new ResourceNotFoundException("Vehículo no encontrado"));

        if (!vehicle.getDriver().getId().equals(driverId)) {
            throw new ResourceNotFoundException("Vehículo no encontrado");
        }

        Optional<VehicleInspection> latestInspection =
            vehicleInspectionRepository.findFirstByVehicle_IdOrderByInspectionDateDesc(vehicleId);
        boolean apto = latestInspection.isPresent()
            && latestInspection.get().isFitForUse()
            && !latestInspection.get().getInspectionDate()
                .isBefore(LocalDate.now().minusYears(1));
        if (!apto) {
            throw new BadRequestException(
                "No se puede activar este vehículo: necesita una revisión vehicular vigente y aprobada (mínimo 65).");
        }

        // saveAndFlush (no solo save): el UPDATE que apaga el vehículo anterior
        // debe llegar a MySQL antes que el que enciende el nuevo — si Hibernate
        // los deja para el mismo flush de commit, el orden no está garantizado y
        // puede intentar poner dos en_uso=1 para el mismo chofer a la vez,
        // chocando contra uq_vehiculo_en_uso_por_chofer (hallazgo de prueba,
        // ver reporte de implementación).
        vehicleRepository.findByDriver_IdAndInUseTrue(driverId)
            .ifPresent(actual -> {
                actual.setInUse(false);
                vehicleRepository.saveAndFlush(actual);
            });

        vehicle.setInUse(true);
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
        response.setInUse(vehicle.getInUse());

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

        Optional<Vehicle> vehicle = vehicleRepository.findByDriver_IdAndInUseTrue(driverId);
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

    @Transactional
    public VehicleInspectionDTO createInspection(InspectionRequest request) {
        Vehicle vehicle = vehicleRepository.findById(request.getVehicleId())
            .orElseThrow(() -> new ResourceNotFoundException("Vehículo no encontrado"));
        AdminPersonnel admin = adminPersonnelRepository.findById(request.getAdminId())
            .orElseThrow(() -> new ResourceNotFoundException("Admin no encontrado"));

        // Mismas 2 validaciones que ya tenía DriverRegistrationService.registerVehicleInspection()
        // — no existían aquí (hallazgo de propuesta_vehiculos_limitados_y_hallazgo_rutas_duplicadas.md).
        if (request.getScore() == null || request.getScore().compareTo(BigDecimal.valueOf(65)) < 0) {
            throw new BadRequestException(
                "La calificación mínima aprobatoria para la revisión vehicular es 65. " +
                "Calificación recibida: " + request.getScore());
        }

        int year = request.getInspectionDate().getYear();
        if (vehicleInspectionRepository.existsByVehicle_IdAndInspectionDateBetween(
                request.getVehicleId(), LocalDate.of(year, 1, 1), LocalDate.of(year, 12, 31))) {
            throw new BadRequestException(
                "Este vehículo ya tiene una revisión registrada en el año " + year);
        }

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


