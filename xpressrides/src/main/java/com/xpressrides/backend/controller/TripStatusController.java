/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Traslados
 *  Descripción: Controlador REST para actualización de estado del
 *               traslado — usado por el chofer para avanzar el
 *               ciclo de vida del viaje desde su panel
 *  Versión:     1.0.0
 *  Fecha:       24/06/2026
 * ============================================================
 */
package com.xpressrides.backend.controller;

import com.xpressrides.backend.dto.TripStatusUpdateDTO;
import com.xpressrides.backend.service.TripStatusService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api")
@CrossOrigin(origins = "*")
public class TripStatusController {

    private final TripStatusService tripStatusService;

    public TripStatusController(TripStatusService tripStatusService) {
        this.tripStatusService = tripStatusService;
    }

    // PATCH /api/viajes/{id}/estado — chofer actualiza el estado del traslado
    @PatchMapping("/viajes/{id}/estado")
    public ResponseEntity<Map<String, Object>> updateTripStatus(
            @PathVariable Integer id,
            @RequestBody TripStatusUpdateDTO dto) {
        Map<String, Object> response = new HashMap<>();
        try {
            Map<String, Object> result = tripStatusService.updateStatus(id, dto);
            response.put("success", true);
            response.put("data", result);
            response.put("message", "Estado actualizado correctamente");
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            response.put("success", false);
            response.put("data", null);
            response.put("message", e.getMessage());
            return ResponseEntity.status(400).body(response);
        }
    }
}
