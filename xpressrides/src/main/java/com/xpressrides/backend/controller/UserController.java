/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Usuarios
 *  Descripción: Controlador REST para gestión de usuarios —
 *               expone endpoint PUT para actualizar perfil
 *  Versión:     1.0.0
 *  Fecha:       25/06/2026
 * ============================================================
 */
package com.xpressrides.backend.controller;

import com.xpressrides.backend.dto.request.UserUpdateRequest;
import com.xpressrides.backend.model.User;
import com.xpressrides.backend.service.UserService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/users")
public class UserController {

    private final UserService userService;

    public UserController(UserService userService) {
        this.userService = userService;
    }

    // PUT /api/users/{id} — actualiza los datos del perfil de un usuario (solo admin)
    @PreAuthorize("hasRole('administrador')")
    @PutMapping("/{id}")
    public ResponseEntity<Map<String, Object>> updateUser(
            @PathVariable Integer id,
            @RequestBody UserUpdateRequest request) {

        Map<String, Object> response = new HashMap<>();
        try {
            User updated = userService.updateUser(id, request);
            response.put("success", true);
            response.put("data", updated);
            response.put("message", "Usuario actualizado correctamente");
            return ResponseEntity.ok(response);
        } catch (RuntimeException e) {
            response.put("success", false);
            response.put("data", null);
            response.put("message", e.getMessage());
            return ResponseEntity.status(404).body(response);
        }
    }
}
