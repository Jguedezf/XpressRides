package com.xpressrides.backend.controller;

import java.util.HashMap;
import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.xpressrides.backend.model.Incident;
import com.xpressrides.backend.service.NotificationService;

@RestController
@RequestMapping("/api/notificaciones")
@PreAuthorize("isAuthenticated()")
public class NotificationController {

    private final NotificationService notificationService;

    public NotificationController(NotificationService notificationService) {
        this.notificationService = notificationService;
    }

    @GetMapping
    public ResponseEntity<?> getNotifications(Authentication authentication) {
        return ResponseEntity.ok(notificationService.getNotifications(authentication.getName()));
    }

    @PutMapping("/{id}/leer")
    public ResponseEntity<Map<String, String>> markAsRead(
            @PathVariable Integer id,
            Authentication authentication) {
        notificationService.markAsRead(authentication.getName(), id);
        return ResponseEntity.ok(Map.of("message", "Notificación marcada como leída"));
    }

    @GetMapping("/no-leidas/count")
    public ResponseEntity<?> countUnread(Authentication authentication) {
        long count = notificationService.countUnread(authentication.getName());
        return ResponseEntity.ok(Map.of("noLeidas", count));
    }

    @PostMapping("/emergencia")
    public ResponseEntity<Map<String, String>> triggerEmergency(
            @RequestBody(required = false) Map<String, Object> body,
            Authentication authentication) {
        Integer tripId = null;
        if (body != null && body.containsKey("tripId") && body.get("tripId") != null) {
            try {
                tripId = Integer.parseInt(body.get("tripId").toString());
            } catch (NumberFormatException ignored) {}
        }
        notificationService.sendEmergencyAlert(authentication.getName(), tripId);
        return ResponseEntity.ok(Map.of("message", "Alerta de emergencia enviada a soporte."));
    }

    // GET /api/notificaciones/incidentes — admin lista los incidentes reportados por el botón de emergencia
    @PreAuthorize("hasRole('administrador') or hasRole('personal_admin')")
    @GetMapping("/incidentes")
    public ResponseEntity<Map<String, Object>> getIncidents() {
        Map<String, Object> response = new HashMap<>();
        response.put("success", true);
        response.put("data", notificationService.getIncidents());
        response.put("message", "OK");
        return ResponseEntity.ok(response);
    }

    // PATCH /api/notificaciones/incidentes/{id}/tomar — admin marca el incidente como en proceso
    @PreAuthorize("hasRole('administrador') or hasRole('personal_admin')")
    @PatchMapping("/incidentes/{id}/tomar")
    public ResponseEntity<Map<String, Object>> takeIncident(@PathVariable Integer id) {
        Map<String, Object> response = new HashMap<>();
        try {
            Map<String, Object> incident = notificationService.takeIncident(id);
            response.put("success", true);
            response.put("data", incident);
            response.put("message", "Incidente marcado como en proceso");
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            response.put("success", false);
            response.put("data", null);
            response.put("message", e.getMessage());
            return ResponseEntity.status(400).body(response);
        }
    }

    // PATCH /api/notificaciones/incidentes/{id}/cerrar — admin cierra el incidente con notas de resolución
    @PreAuthorize("hasRole('administrador') or hasRole('personal_admin')")
    @PatchMapping("/incidentes/{id}/cerrar")
    public ResponseEntity<Map<String, Object>> closeIncident(
            @PathVariable Integer id,
            @RequestBody(required = false) Map<String, String> body,
            Authentication authentication) {
        Map<String, Object> response = new HashMap<>();
        try {
            String adminUsername = authentication.getName();
            String notas = null;
            if (body != null && body.containsKey("notas") && body.get("notas") != null) {
                notas = body.get("notas").toString();
            }
            Map<String, Object> incident = notificationService.closeIncident(id, adminUsername, notas);
            response.put("success", true);
            response.put("data", incident);
            response.put("message", "Incidente cerrado");
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            response.put("success", false);
            response.put("data", null);
            response.put("message", e.getMessage());
            return ResponseEntity.status(400).body(response);
        }
    }
}
