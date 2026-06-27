package com.xpressrides.backend.controller;

import java.time.LocalDate;
import java.util.Map;

import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.xpressrides.backend.dto.request.AvailabilityRequest;
import com.xpressrides.backend.dto.request.EnableRequest;
import com.xpressrides.backend.dto.request.TripStatusRequest;
import com.xpressrides.backend.dto.response.DriverStatusResponse;
import com.xpressrides.backend.service.DriverService;
import com.xpressrides.backend.service.TripRejectionService;

import jakarta.validation.Valid;
import java.util.HashMap;

@RestController
@RequestMapping("/api/chofer")
public class DriverController {
    private final DriverService driverService;
    private final TripRejectionService tripRejectionService;

    public DriverController(DriverService driverService,
                            TripRejectionService tripRejectionService) {
        this.driverService        = driverService;
        this.tripRejectionService = tripRejectionService;
    }

    @PreAuthorize("hasRole('chofer')")
    @PutMapping("/disponibilidad")
    public ResponseEntity<Map<String, String>> toggleAvailability(
            @Valid @RequestBody AvailabilityRequest request,
            Authentication authentication) {
        driverService.toggleAvailability(authentication.getName(), request.getAvailable());
        return ResponseEntity.ok(Map.of("message", "Disponibilidad actualizada"));
    }

    @PreAuthorize("hasRole('administrador') or hasRole('personal_admin')")
    @PutMapping("/habilitar/{driverId}")
    public ResponseEntity<Map<String, String>> toggleEnabled(
        @PathVariable Integer driverId,
        @Valid @RequestBody EnableRequest request) {
        driverService.toggleEnabled(driverId, request.getEnabled());
        return ResponseEntity.ok(Map.of("message", "Habilitación actualizada"));
    }

    @PreAuthorize("hasRole('chofer')")
    @GetMapping("/estado")
    public ResponseEntity<DriverStatusResponse> getStatus(Authentication authentication) {
        DriverStatusResponse response = driverService.getStatus(authentication.getName());
        return ResponseEntity.ok(response);
    }

    @PreAuthorize("hasRole('chofer')")
    @GetMapping("/perfil")
    public ResponseEntity<?> getProfile(Authentication authentication) {
        HashMap<String, Object> response = new HashMap<>();
        try {
            Map<String, Object> data = driverService.getProfile(authentication.getName());
            response.put("success", true);
            response.put("data", data);
            response.put("message", "OK");
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            response.put("success", false);
            response.put("data", null);
            response.put("message", e.getMessage());
            return ResponseEntity.badRequest().body(response);
        }
    }

    @PreAuthorize("hasRole('chofer')")
    @GetMapping("/traslados")
    public ResponseEntity<?> getTrips(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate desde,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate hasta,
            Authentication authentication) {
        return ResponseEntity.ok(driverService.getTrips(authentication.getName(), desde, hasta));
    }

    @PreAuthorize("hasRole('chofer')")
    @GetMapping("/traslados/cancelados")
    public ResponseEntity<?> getCancelledTrips(Authentication authentication) {
        return ResponseEntity.ok(driverService.getCancelledTrips(authentication.getName()));
    }

    @PreAuthorize("hasRole('chofer')")
    @GetMapping("/traslados/{id}")
    public ResponseEntity<?> getTripDetail(@PathVariable Integer id, Authentication authentication) {
        return ResponseEntity.ok(driverService.getTripDetail(authentication.getName(), id));
    }

    @PreAuthorize("hasRole('chofer')")
    @PutMapping("/traslados/{id}/estado")
    public ResponseEntity<Map<String, String>> updateTripStatus(
            @PathVariable Integer id,
            @Valid @RequestBody TripStatusRequest request,
            Authentication authentication) {
        driverService.updateTripStatus(authentication.getName(), id, request.getStatus());
        return ResponseEntity.ok(Map.of("message", "Estado actualizado a " + request.getStatus()));
    }

    @PreAuthorize("hasRole('chofer')")
    @PutMapping("/traslados/{id}/cancelar")
    public ResponseEntity<Map<String, String>> cancelTrip(
            @PathVariable Integer id,
            @RequestBody Map<String, String> body,
            Authentication authentication) {
        String motivo = body.getOrDefault("motivo", "Cancelado por el chofer");
        driverService.cancelTrip(authentication.getName(), id, motivo);
        return ResponseEntity.ok(Map.of("message", "Viaje cancelado"));
    }

    // GET /api/chofer/viaje-activo — viaje en curso del chofer (aceptado, chofer_llego, en_progreso)
    @PreAuthorize("hasRole('chofer')")
    @GetMapping("/viaje-activo")
    public ResponseEntity<?> getActiveTrip(Authentication authentication) {
        HashMap<String, Object> response = new HashMap<>();
        try {
            Map<String, Object> data = driverService.getActiveTrip(authentication.getName());
            response.put("success", true);
            response.put("data", data);
            response.put("message", data != null ? "Viaje activo encontrado" : "Sin viaje activo");
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            response.put("success", false);
            response.put("data", null);
            response.put("message", e.getMessage());
            return ResponseEntity.badRequest().body(response);
        }
    }

    // PUT /api/chofer/traslados/{id}/rechazar — chofer rechaza el viaje asignado
    @PreAuthorize("hasRole('chofer')")
    @PutMapping("/traslados/{id}/rechazar")
    public ResponseEntity<Map<String, Object>> rejectTrip(
            @PathVariable Integer id,
            Authentication authentication) {
        Map<String, Object> response = new HashMap<>();
        try {
            Map<String, Object> result = tripRejectionService.rejectTrip(authentication.getName(), id);
            response.put("success", true);
            response.put("data", result);
            response.put("message", "reasignado".equals(result.get("estado"))
                ? "Viaje reasignado a otro chofer"
                : "Viaje cancelado — no hay choferes disponibles");
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            response.put("success", false);
            response.put("data", null);
            response.put("message", e.getMessage());
            return ResponseEntity.status(400).body(response);
        }
    }
}
