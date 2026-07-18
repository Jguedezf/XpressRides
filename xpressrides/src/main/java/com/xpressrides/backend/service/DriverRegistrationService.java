/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Habilitación de Choferes
 *  Descripción: Lógica de negocio para el proceso de habilitación
 *               del chofer: registro de vehículo, evaluación
 *               psicológica y revisión vehicular. Activa
 *               chofer.habilitado cuando ambas evaluaciones aprueban.
 *  Versión:     1.0.0
 *  Fecha:       24/06/2026
 * ============================================================
 */
package com.xpressrides.backend.service;

import com.xpressrides.backend.exception.BadRequestException;
import com.xpressrides.backend.model.*;
import com.xpressrides.backend.repository.*;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Optional;

@Service
@Transactional
public class DriverRegistrationService {

    private final DriverRepository driverRepository;
    private final VehicleRepository vehicleRepository;
    private final PsychologicalEvaluationRepository psychEvalRepository;
    private final VehicleInspectionRepository vehicleInspectionRepository;
    private final EmergencyContactRepository emergencyContactRepository;

    // EntityManager para forzar re-lectura de columnas generadas por MySQL
    @PersistenceContext
    private EntityManager entityManager;

    // Inyección de dependencias por constructor
    public DriverRegistrationService(
            DriverRepository driverRepository,
            VehicleRepository vehicleRepository,
            PsychologicalEvaluationRepository psychEvalRepository,
            VehicleInspectionRepository vehicleInspectionRepository,
            EmergencyContactRepository emergencyContactRepository) {
        this.driverRepository = driverRepository;
        this.vehicleRepository = vehicleRepository;
        this.psychEvalRepository = psychEvalRepository;
        this.vehicleInspectionRepository = vehicleInspectionRepository;
        this.emergencyContactRepository = emergencyContactRepository;
    }

    // Registra el vehículo de un chofer — un chofer solo puede tener un vehículo
    public Vehicle registerVehicle(Integer driverId, Vehicle vehicle) {
        Driver driver = driverRepository.findById(driverId)
                .orElseThrow(() -> new RuntimeException("Chofer no encontrado con ID: " + driverId));

        // Valida que la placa no esté duplicada en el sistema
        if (vehicleRepository.existsByPlate(vehicle.getPlate())) {
            throw new RuntimeException("La placa " + vehicle.getPlate() + " ya está registrada.");
        }

        // Valida que el chofer no tenga ya un vehículo registrado
        if (vehicleRepository.findByDriver_Id(driverId).isPresent()) {
            throw new RuntimeException("El chofer ya tiene un vehículo registrado.");
        }

        vehicle.setDriver(driver);
        vehicle.setActive(true);
        return vehicleRepository.save(vehicle);
    }

    // Registra una evaluación psicológica y verifica habilitación del chofer
    // MySQL calcula 'aprobado' automáticamente: calificacion >= 73
    public PsychologicalEvaluation registerPsychologicalEvaluation(PsychologicalEvaluation eval) {
        Integer driverId = eval.getDriver().getId();
        driverRepository.findById(driverId)
                .orElseThrow(() -> new RuntimeException("Chofer no encontrado con ID: " + driverId));

        if (eval.getScore() == null || eval.getScore().compareTo(BigDecimal.valueOf(73)) < 0) {
            throw new BadRequestException(
                "La calificación mínima aprobatoria para la evaluación psicológica es 73. " +
                "Calificación recibida: " + eval.getScore());
        }

        int year = eval.getEvaluationDate().getYear();
        if (psychEvalRepository.existsByDriver_IdAndEvaluationDateBetween(
                driverId, LocalDate.of(year, 1, 1), LocalDate.of(year, 12, 31))) {
            throw new BadRequestException(
                "El chofer ya tiene una evaluación psicológica registrada en el año " + year);
        }

        PsychologicalEvaluation saved = psychEvalRepository.save(eval);

        // refresh fuerza re-lectura desde MySQL para obtener 'aprobado' calculado
        entityManager.flush();
        entityManager.refresh(saved);

        // Verifica si el chofer cumple ahora los requisitos de habilitación
        checkAndEnableDriver(driverId);

        return saved;
    }

    // Registra una revisión vehicular y verifica habilitación del chofer
    // MySQL calcula 'apto' (calificacion >= 65) y 'proxima_revision' automáticamente
    public VehicleInspection registerVehicleInspection(VehicleInspection inspection) {
        Vehicle vehicle = vehicleRepository.findById(inspection.getVehicle().getId())
                .orElseThrow(() -> new RuntimeException("Vehículo no encontrado."));

        if (inspection.getScore() == null || inspection.getScore().compareTo(BigDecimal.valueOf(65)) < 0) {
            throw new BadRequestException(
                "La calificación mínima aprobatoria para la revisión vehicular es 65. " +
                "Calificación recibida: " + inspection.getScore());
        }

        int year = inspection.getInspectionDate().getYear();
        if (vehicleInspectionRepository.existsByVehicle_IdAndInspectionDateBetween(
                inspection.getVehicle().getId(), LocalDate.of(year, 1, 1), LocalDate.of(year, 12, 31))) {
            throw new BadRequestException(
                "Este vehículo ya tiene una revisión registrada en el año " + year);
        }

        VehicleInspection saved = vehicleInspectionRepository.save(inspection);

        // refresh fuerza re-lectura desde MySQL para obtener 'apto' y 'proxima_revision' calculados
        entityManager.flush();
        entityManager.refresh(saved);

        // Verifica si el chofer del vehículo cumple ahora los requisitos de habilitación
        checkAndEnableDriver(vehicle.getDriver().getId());

        return saved;
    }

    // Verifica si el chofer cumple todos los requisitos para ser habilitado:
    // 1. Al menos una evaluación psicológica aprobada (calificacion >= 73)
    // 2. La revisión vehicular más reciente aprobada (calificacion >= 65)
    // 3. Exactamente 2 contactos de emergencia registrados
    // Si las tres condiciones se cumplen → chofer.habilitado = true
    private void checkAndEnableDriver(Integer driverId) {
        Driver driver = driverRepository.findById(driverId).orElseThrow();

        boolean hasApprovedEval = psychEvalRepository.existsByDriver_IdAndApprovedTrue(driverId);
        if (!hasApprovedEval) return;

        Optional<Vehicle> vehicle = vehicleRepository.findByDriver_Id(driverId);
        if (vehicle.isEmpty()) return;

        Optional<VehicleInspection> latestInspection =
                vehicleInspectionRepository.findFirstByVehicle_IdOrderByInspectionDateDesc(vehicle.get().getId());

        if (latestInspection.isEmpty() || !latestInspection.get().isFitForUse()) return;

        if (emergencyContactRepository.countByDriver_Id(driverId) != 2) return;

        // Todas las condiciones cumplen — activa al chofer
        driver.setEnabled(true);
        driverRepository.save(driver);
    }
}
