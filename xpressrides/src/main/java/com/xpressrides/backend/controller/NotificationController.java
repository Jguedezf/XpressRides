package com.xpressrides.backend.controller;

import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

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
}
