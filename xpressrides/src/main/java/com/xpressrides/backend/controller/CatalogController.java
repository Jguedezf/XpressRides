/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Catálogos Base
 *  Descripción: Controlador REST para catálogos geográficos
 *               y bancarios — expone endpoints GET al frontend
 *  Versión:     1.2.0
 *  Fecha:       24/06/2026
 * ============================================================
 */
package com.xpressrides.backend.controller;

import com.xpressrides.backend.dto.request.BankRequest;
import com.xpressrides.backend.exception.ResourceNotFoundException;
import com.xpressrides.backend.model.Bank;
import com.xpressrides.backend.model.Zone;
import com.xpressrides.backend.service.CatalogService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api")
public class CatalogController {

    private final CatalogService catalogService;

    // Inyección de dependencias por constructor
    public CatalogController(CatalogService catalogService) {
        this.catalogService = catalogService;
    }

    // GET /api/zonas — retorna todas las zonas activas
    @GetMapping("/zonas")
    public ResponseEntity<Map<String, Object>> listarZonas() {
        List<Zone> zones = catalogService.listarZonasActivas();
        Map<String, Object> response = new HashMap<>();
        response.put("success", true);
        response.put("data", zones);
        response.put("message", "OK");
        return ResponseEntity.ok(response);
    }

    // GET /api/zonas/todas — retorna todas las zonas sin filtro (admin)
    @GetMapping("/zonas/todas")
    public ResponseEntity<Map<String, Object>> listarTodasLasZonas() {
        List<Zone> zones = catalogService.listarTodasLasZonas();
        Map<String, Object> response = new HashMap<>();
        response.put("success", true);
        response.put("data", zones);
        response.put("message", "OK");
        return ResponseEntity.ok(response);
    }

    // GET /api/bancos — retorna todos los bancos activos
    @GetMapping("/bancos")
    public ResponseEntity<Map<String, Object>> listarBancos() {
        List<Bank> banks = catalogService.listarBancosActivos();
        Map<String, Object> response = new HashMap<>();
        response.put("success", true);
        response.put("data", banks);
        response.put("message", "OK");
        return ResponseEntity.ok(response);
    }

    // GET /api/bancos/todos — retorna todos los bancos sin filtro (admin)
    @GetMapping("/bancos/todos")
    public ResponseEntity<Map<String, Object>> listarTodosLosBancos() {
        List<Bank> banks = catalogService.listarTodosLosBancos();
        Map<String, Object> response = new HashMap<>();
        response.put("success", true);
        response.put("data", banks);
        response.put("message", "OK");
        return ResponseEntity.ok(response);
    }

    // POST /api/bancos — personal_admin ingresa un banco nuevo
    @PreAuthorize("hasRole('administrador') or hasRole('personal_admin')")
    @PostMapping("/bancos")
    public ResponseEntity<Map<String, Object>> crearBanco(@Valid @RequestBody BankRequest request) {
        Map<String, Object> response = new HashMap<>();
        try {
            Bank bank = catalogService.crearBanco(request);
            response.put("success", true);
            response.put("data", bank);
            response.put("message", "Banco creado correctamente.");
            return ResponseEntity.status(201).body(response);
        } catch (Exception e) {
            response.put("success", false);
            response.put("data", null);
            response.put("message", e.getMessage());
            return ResponseEntity.status(400).body(response);
        }
    }

    // PUT /api/bancos/{id} — personal_admin edita un banco existente
    @PreAuthorize("hasRole('administrador') or hasRole('personal_admin')")
    @PutMapping("/bancos/{id}")
    public ResponseEntity<Map<String, Object>> actualizarBanco(
            @PathVariable Integer id,
            @Valid @RequestBody BankRequest request) {
        Map<String, Object> response = new HashMap<>();
        try {
            Bank bank = catalogService.actualizarBanco(id, request);
            response.put("success", true);
            response.put("data", bank);
            response.put("message", "Banco actualizado correctamente.");
            return ResponseEntity.ok(response);
        } catch (ResourceNotFoundException e) {
            response.put("success", false);
            response.put("data", null);
            response.put("message", e.getMessage());
            return ResponseEntity.status(404).body(response);
        } catch (Exception e) {
            response.put("success", false);
            response.put("data", null);
            response.put("message", e.getMessage());
            return ResponseEntity.status(400).body(response);
        }
    }

    // PATCH /api/bancos/{id}/desactivar — personal_admin desactiva un banco (soft delete)
    @PreAuthorize("hasRole('administrador') or hasRole('personal_admin')")
    @PatchMapping("/bancos/{id}/desactivar")
    public ResponseEntity<Map<String, Object>> desactivarBanco(@PathVariable Integer id) {
        Map<String, Object> response = new HashMap<>();
        try {
            Bank bank = catalogService.desactivarBanco(id);
            response.put("success", true);
            response.put("data", bank);
            response.put("message", "Banco desactivado correctamente.");
            return ResponseEntity.ok(response);
        } catch (ResourceNotFoundException e) {
            response.put("success", false);
            response.put("data", null);
            response.put("message", e.getMessage());
            return ResponseEntity.status(404).body(response);
        } catch (Exception e) {
            response.put("success", false);
            response.put("data", null);
            response.put("message", e.getMessage());
            return ResponseEntity.status(400).body(response);
        }
    }
}
