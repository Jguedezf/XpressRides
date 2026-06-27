/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Habilitación de Choferes
 *  Descripción: Controlador REST para el proceso de habilitación —
 *               registro de vehículo, evaluación psicológica y
 *               revisión vehicular por personal administrativo
 *  Versión:     1.0.0
 *  Fecha:       24/06/2026
 * ============================================================
 */
package com.xpressrides.backend.controller;

import com.xpressrides.backend.model.*;
import com.xpressrides.backend.service.DriverRegistrationService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api")
@CrossOrigin(origins = "*")
public class DriverRegistrationController {

    private final DriverRegistrationService driverRegistrationService;

    // Inyección de dependencias por constructor
    public DriverRegistrationController(DriverRegistrationService driverRegistrationService) {
        this.driverRegistrationService = driverRegistrationService;
    }

    // POST /api/drivers/{id}/vehicle — personal admin registra vehículo de un chofer
    @PreAuthorize("hasRole('personal_admin') or hasRole('administrador')")
    @PostMapping("/choferes/{id}/vehiculo")
    public ResponseEntity<Map<String, Object>> registerVehicle(
            @PathVariable Integer id,
            @Valid @RequestBody Vehicle vehicle) {
        Map<String, Object> response = new HashMap<>();
        try {
            Vehicle saved = driverRegistrationService.registerVehicle(id, vehicle);
            response.put("success", true);
            response.put("data", saved);
            response.put("message", "Vehículo registrado correctamente.");
            return ResponseEntity.status(201).body(response);
        } catch (Exception e) {
            response.put("success", false);
            response.put("data", null);
            response.put("message", e.getMessage());
            return ResponseEntity.status(400).body(response);
        }
    }

    // POST /api/drivers/{id}/psych-eval — personal admin registra evaluación psicológica
    @PreAuthorize("hasRole('personal_admin') or hasRole('administrador')")
    @PostMapping("/choferes/{id}/evaluacion-psicologica")
    public ResponseEntity<Map<String, Object>> registerPsychEval(
            @PathVariable Integer id,
            @Valid @RequestBody PsychologicalEvaluation eval) {
        Map<String, Object> response = new HashMap<>();
        try {
            eval.getDriver().setId(id);
            PsychologicalEvaluation saved = driverRegistrationService.registerPsychologicalEvaluation(eval);
            response.put("success", true);
            response.put("data", saved);
            response.put("message", saved.isApproved()
                    ? "Evaluación registrada. Calificación aprobatoria."
                    : "Evaluación registrada. Calificación no aprobatoria (mínimo 73).");
            return ResponseEntity.status(201).body(response);
        } catch (Exception e) {
            response.put("success", false);
            response.put("data", null);
            response.put("message", e.getMessage());
            return ResponseEntity.status(400).body(response);
        }
    }

    // POST /api/vehicles/{id}/inspection — personal admin registra revisión vehicular
    @PreAuthorize("hasRole('personal_admin') or hasRole('administrador')")
    @PostMapping("/vehiculos/{id}/revision")
    public ResponseEntity<Map<String, Object>> registerVehicleInspection(
            @PathVariable Integer id,
            @Valid @RequestBody VehicleInspection inspection) {
        Map<String, Object> response = new HashMap<>();
        try {
            inspection.getVehicle().setId(id);
            VehicleInspection saved = driverRegistrationService.registerVehicleInspection(inspection);
            response.put("success", true);
            response.put("data", saved);
            response.put("message", saved.isFitForUse()
                    ? "Revisión registrada. Vehículo apto."
                    : "Revisión registrada. Vehículo no apto (mínimo 65).");
            return ResponseEntity.status(201).body(response);
        } catch (Exception e) {
            response.put("success", false);
            response.put("data", null);
            response.put("message", e.getMessage());
            return ResponseEntity.status(400).body(response);
        }
    }
}
