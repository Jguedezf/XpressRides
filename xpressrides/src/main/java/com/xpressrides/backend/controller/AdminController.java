package com.xpressrides.backend.controller;

import com.xpressrides.backend.dto.request.AdminPersonnelRequest;
import com.xpressrides.backend.dto.request.EvaluarChoferRequest;
import com.xpressrides.backend.model.User;
import com.xpressrides.backend.service.AdminService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.DeleteMapping;
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
            @Valid @RequestBody EvaluarChoferRequest body,
            org.springframework.security.core.Authentication authentication) {
        Map<String, Object> response = new HashMap<>();
        try {
            BigDecimal notaPsicologica = body.getNotaPsicologica();
            BigDecimal notaVehicular   = body.getNotaVehicular();
            String obsPsicologica      = body.getObsPsicologica();
            String obsVehicular        = body.getObsVehicular();
            String adminUsername = authentication.getName();
            adminService.evaluarChofer(id, notaPsicologica, notaVehicular, obsPsicologica, obsVehicular, adminUsername);
            response.put("success", true);
            response.put("message", "Chofer evaluado correctamente");
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            response.put("success", false);
            response.put("message", e.getMessage());
            return ResponseEntity.badRequest().body(response);
        }
    }

    // POST /api/admin/personal-admin — alta de personal administrativo desde el panel.
    // Solo 'administrador' (no 'personal_admin') puede crear más personal_admin.
    @PreAuthorize("hasRole('administrador')")
    @PostMapping("/personal-admin")
    public ResponseEntity<Map<String, Object>> crearPersonalAdmin(
            @Valid @RequestBody AdminPersonnelRequest request, Authentication authentication) {
        Map<String, Object> response = new HashMap<>();
        try {
            User user = adminService.crearPersonalAdmin(request, authentication.getName());
            Map<String, Object> data = new HashMap<>();
            data.put("id", user.getId());
            data.put("username", user.getUsername());
            data.put("nombre", user.getName());
            data.put("apellido", user.getLastName());
            response.put("success", true);
            response.put("data", data);
            response.put("message", "Personal administrativo creado correctamente");
            return ResponseEntity.status(201).body(response);
        } catch (Exception e) {
            response.put("success", false);
            response.put("data", null);
            response.put("message", e.getMessage());
            return ResponseEntity.status(400).body(response);
        }
    }

    // GET /api/admin/personal-admin — lista el personal administrativo
    @PreAuthorize("hasRole('administrador') or hasRole('personal_admin')")
    @GetMapping("/personal-admin")
    public ResponseEntity<Map<String, Object>> getAllAdmins() {
        Map<String, Object> response = new HashMap<>();
        try {
            response.put("success", true);
            response.put("data", adminService.getAllAdmins());
            response.put("message", "Personal obtenido correctamente");
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            response.put("success", false);
            response.put("data", null);
            response.put("message", e.getMessage());
            return ResponseEntity.status(500).body(response);
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

    @PreAuthorize("hasRole('administrador') or hasRole('personal_admin')")
    @PutMapping("/usuarios/{id}")
    public ResponseEntity<Map<String, Object>> updateUserAdmin(
            @PathVariable Integer id,
            @RequestBody com.xpressrides.backend.dto.request.UserUpdateRequest request,
            Authentication authentication) {
        Map<String, Object> response = new HashMap<>();
        try {
            adminService.updateUserAdmin(id, request, authentication.getName());
            response.put("success", true);
            response.put("message", "Usuario actualizado correctamente");
            return ResponseEntity.ok(response);
        } catch (org.springframework.security.access.AccessDeniedException e) {
            response.put("success", false);
            response.put("message", e.getMessage());
            return ResponseEntity.status(403).body(response);
        } catch (Exception e) {
            response.put("success", false);
            response.put("message", e.getMessage());
            return ResponseEntity.status(400).body(response);
        }
    }

    @PreAuthorize("hasRole('administrador') or hasRole('personal_admin')")
    @DeleteMapping("/usuarios/{id}")
    public ResponseEntity<Map<String, Object>> deleteUserAdmin(
            @PathVariable Integer id,
            Authentication authentication) {
        Map<String, Object> response = new HashMap<>();
        try {
            adminService.deleteUserAdmin(id, authentication.getName());
            response.put("success", true);
            response.put("message", "Usuario eliminado correctamente");
            return ResponseEntity.ok(response);
        } catch (org.springframework.security.access.AccessDeniedException e) {
            response.put("success", false);
            response.put("message", e.getMessage());
            return ResponseEntity.status(403).body(response);
        } catch (Exception e) {
            response.put("success", false);
            response.put("message", e.getMessage());
            return ResponseEntity.status(400).body(response);
        }
    }
}
