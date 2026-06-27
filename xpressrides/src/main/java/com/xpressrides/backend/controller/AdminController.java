package com.xpressrides.backend.controller;

import com.xpressrides.backend.service.AdminService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.math.BigDecimal;
import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/admin")
public class AdminController {

    private final AdminService adminService;

    public AdminController(AdminService adminService) {
        this.adminService = adminService;
    }

    // GET /api/admin/perfil — datos personales del admin o personal_admin autenticado
    @PreAuthorize("hasRole('administrador') or hasRole('personal_admin')")
    @GetMapping("/perfil")
    public ResponseEntity<Map<String, Object>> getProfile(Authentication authentication) {
        Map<String, Object> response = new HashMap<>();
        try {
            response.put("success", true);
            response.put("data", adminService.getProfile(authentication.getName()));
            response.put("message", "OK");
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            response.put("success", false);
            response.put("data", null);
            response.put("message", e.getMessage());
            return ResponseEntity.status(500).body(response);
        }
    }

    // GET /api/admin/choferes — lista todos los choferes con su estado operativo
    @PreAuthorize("hasRole('administrador') or hasRole('personal_admin')")
    @GetMapping("/choferes")
    public ResponseEntity<Map<String, Object>> getAllDrivers() {
        Map<String, Object> response = new HashMap<>();
        try {
            response.put("success", true);
            response.put("data", adminService.getAllDrivers());
            response.put("message", "Choferes obtenidos correctamente");
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            response.put("success", false);
            response.put("data", null);
            response.put("message", e.getMessage());
            return ResponseEntity.status(500).body(response);
        }
    }

    // GET /api/admin/clientes — lista todos los clientes con su estado financiero
    @PreAuthorize("hasRole('administrador') or hasRole('personal_admin')")
    @GetMapping("/clientes")
    public ResponseEntity<Map<String, Object>> getAllCustomers() {
        Map<String, Object> response = new HashMap<>();
        try {
            response.put("success", true);
            response.put("data", adminService.getAllCustomers());
            response.put("message", "Clientes obtenidos correctamente");
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            response.put("success", false);
            response.put("data", null);
            response.put("message", e.getMessage());
            return ResponseEntity.status(500).body(response);
        }
    }

    // POST /api/admin/choferes/{id}/evaluar — registra psicológica + vehicular en un solo paso
    @PreAuthorize("hasRole('administrador') or hasRole('personal_admin')")
    @PostMapping("/choferes/{id}/evaluar")
    public ResponseEntity<Map<String, Object>> evaluarChofer(
            @PathVariable Integer id,
            @RequestBody Map<String, Object> body) {
        Map<String, Object> response = new HashMap<>();
        try {
            BigDecimal notaPsicologica = new BigDecimal(body.get("notaPsicologica").toString());
            BigDecimal notaVehicular   = new BigDecimal(body.get("notaVehicular").toString());
            adminService.evaluarChofer(id, notaPsicologica, notaVehicular);
            response.put("success", true);
            response.put("message", "Chofer evaluado correctamente");
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            response.put("success", false);
            response.put("message", e.getMessage());
            return ResponseEntity.badRequest().body(response);
        }
    }

    // GET /api/admin/traslados/activos — traslados en curso en este momento
    @PreAuthorize("hasRole('administrador') or hasRole('personal_admin')")
    @GetMapping("/traslados/activos")
    public ResponseEntity<Map<String, Object>> getActiveTrips() {
        Map<String, Object> response = new HashMap<>();
        try {
            response.put("success", true);
            response.put("data", adminService.getActiveTrips());
            response.put("message", "Traslados activos obtenidos correctamente");
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            response.put("success", false);
            response.put("data", null);
            response.put("message", e.getMessage());
            return ResponseEntity.status(500).body(response);
        }
    }
}
