/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Traslados — Cálculo de Tarifa
 *  Descripción: Endpoint de preview de tarifa. Calcula el costo
 *               del viaje sin crear el traslado ni modificar saldo.
 *               Usado por el frontend antes de que el cliente
 *               confirme el viaje (paso 2 del flujo de solicitud).
 *  Versión:     1.0.0
 *  Fecha:       25/06/2026
 * ============================================================
 */
package com.xpressrides.backend.controller;

import com.xpressrides.backend.dto.request.FareRequest;
import com.xpressrides.backend.dto.response.FareResponse;
import com.xpressrides.backend.service.FareService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/traslados")
public class FareController {

    private final FareService fareService;

    public FareController(FareService fareService) {
        this.fareService = fareService;
    }

    // POST /api/traslados/calcular-tarifa — preview de tarifa antes de confirmar el viaje
    @PreAuthorize("hasRole('cliente')")
    @PostMapping("/calcular-tarifa")
    public ResponseEntity<Map<String, Object>> calculateFare(
            @Valid @RequestBody FareRequest request,
            Authentication authentication) {

        Map<String, Object> response = new HashMap<>();
        try {
            FareResponse fare = fareService.calculateFare(request, authentication.getName());
            response.put("success", true);
            response.put("data", fare);
            response.put("message", "Cálculo de tarifa dinámico procesado exitosamente");
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            response.put("success", false);
            response.put("data", null);
            response.put("message", e.getMessage());
            return ResponseEntity.status(400).body(response);
        }
    }
}
