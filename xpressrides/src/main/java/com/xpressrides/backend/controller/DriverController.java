package com.xpressrides.backend.controller;

import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.xpressrides.backend.dto.request.AvailabilityRequest;
import com.xpressrides.backend.dto.request.EnableRequest;
import com.xpressrides.backend.dto.request.TripStatusRequest;
import com.xpressrides.backend.dto.response.DriverStatusResponse;
import com.xpressrides.backend.service.DriverService;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/chofer")
public class DriverController {
    private final DriverService driverService;

    public DriverController(DriverService driverService) {
        this.driverService = driverService;
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
    @GetMapping("/traslados")
    public ResponseEntity<?> getTrips(Authentication authentication) {
        return ResponseEntity.ok(driverService.getTrips(authentication.getName()));
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
}
