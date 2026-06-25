package com.xpressrides.backend.controller;

import java.util.HashMap;
import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.xpressrides.backend.dto.request.ChangePasswordRequest;
import com.xpressrides.backend.dto.request.ClienteRegisterRequest;
import com.xpressrides.backend.dto.request.LoginRequest;
import com.xpressrides.backend.dto.request.RefreshTokenRequest;
import com.xpressrides.backend.dto.request.RegisterRequest;
import com.xpressrides.backend.dto.response.AuthResponse;
import com.xpressrides.backend.model.User;
import com.xpressrides.backend.repository.CustomerRepository;
import com.xpressrides.backend.repository.DriverRepository;
import com.xpressrides.backend.repository.UserRepository;
import com.xpressrides.backend.segurity.TokenBlacklistService;
import com.xpressrides.backend.service.AuthService;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthService authService;
    private final TokenBlacklistService tokenBlacklistService;
    private final UserRepository userRepository;
    private final CustomerRepository customerRepository;
    private final DriverRepository driverRepository;

    public AuthController(AuthService authService,
                          TokenBlacklistService tokenBlacklistService,
                          UserRepository userRepository,
                          CustomerRepository customerRepository,
                          DriverRepository driverRepository) {
        this.authService = authService;
        this.tokenBlacklistService = tokenBlacklistService;
        this.userRepository = userRepository;
        this.customerRepository = customerRepository;
        this.driverRepository = driverRepository;
    }

    // POST /api/auth/registro — registro completo (formato Eliuber, inglés)
    @PostMapping("/registro")
    public ResponseEntity<Map<String, Object>> register(@Valid @RequestBody RegisterRequest request) {
        Map<String, Object> response = new HashMap<>();
        try {
            AuthResponse auth = authService.register(request);
            User user = userRepository.findByUsername(request.getUsername()).orElseThrow();
            response.put("success", true);
            response.put("data", buildUserData(user, auth));
            response.put("message", "Registro exitoso");
            return ResponseEntity.status(201).body(response);
        } catch (Exception e) {
            response.put("success", false);
            response.put("data", null);
            response.put("message", e.getMessage());
            return ResponseEntity.status(400).body(response);
        }
    }

    // POST /api/auth/register-cliente — registro de cliente desde el frontend de Freddy
    // Acepta campos en español: nombre, apellido, cedula, telefono, password, esEstudiante
    // El username se genera automáticamente desde la cédula
    @PostMapping("/register-cliente")
    public ResponseEntity<Map<String, Object>> registerCliente(
            @Valid @RequestBody ClienteRegisterRequest request) {
        Map<String, Object> response = new HashMap<>();
        try {
            // Convertir al RegisterRequest estándar que espera AuthService
            RegisterRequest registerRequest = new RegisterRequest();
            registerRequest.setName(request.getNombre());
            registerRequest.setLastName(request.getApellido());
            registerRequest.setCi(request.getCedula());
            registerRequest.setPhone(request.getTelefono());
            registerRequest.setPassword(request.getPassword());
            registerRequest.setRole("cliente");
            registerRequest.setIsStudent(Boolean.TRUE.equals(request.getEsEstudiante()));
            // username = cédula (identificador único en Venezuela)
            registerRequest.setUsername(request.getCedula());
            // email generado como placeholder — no se usa para verificación
            registerRequest.setEmail(request.getCedula() + "@xpressrides.local");

            AuthResponse auth = authService.register(registerRequest);
            User user = userRepository.findByUsername(request.getCedula()).orElseThrow();
            response.put("success", true);
            response.put("data", buildUserData(user, auth));
            response.put("message", "Registro exitoso");
            return ResponseEntity.status(201).body(response);
        } catch (Exception e) {
            response.put("success", false);
            response.put("data", null);
            response.put("message", e.getMessage());
            return ResponseEntity.status(400).body(response);
        }
    }

    // POST /api/auth/iniciar-sesion — login estándar
    // POST /api/auth/login         — alias para compatibilidad con el frontend de Freddy
    @PostMapping({"/iniciar-sesion", "/login"})
    public ResponseEntity<Map<String, Object>> login(@Valid @RequestBody LoginRequest request) {
        Map<String, Object> response = new HashMap<>();
        try {
            AuthResponse auth = authService.login(request);
            User user = userRepository.findByUsername(request.getUsername()).orElseThrow();
            response.put("success", true);
            response.put("data", buildUserData(user, auth));
            response.put("message", "Inicio de sesión exitoso");
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            response.put("success", false);
            response.put("data", null);
            response.put("message", "Credenciales incorrectas");
            return ResponseEntity.status(401).body(response);
        }
    }

    @PostMapping("/refrescar")
    public ResponseEntity<Map<String, Object>> refresh(@Valid @RequestBody RefreshTokenRequest request) {
        Map<String, Object> response = new HashMap<>();
        try {
            AuthResponse auth = authService.refresh(request);
            response.put("success", true);
            response.put("data", Map.of(
                "token", auth.getAccesToken(),
                "refreshToken", auth.getRefreshToken()
            ));
            response.put("message", "Token renovado exitosamente");
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            response.put("success", false);
            response.put("data", null);
            response.put("message", e.getMessage());
            return ResponseEntity.status(401).body(response);
        }
    }

    @PostMapping("/cambiar-contrasena")
    public ResponseEntity<Map<String, Object>> changePassword(
            @Valid @RequestBody ChangePasswordRequest request) {
        Map<String, Object> response = new HashMap<>();
        try {
            authService.changePassword(request);
            response.put("success", true);
            response.put("data", null);
            response.put("message", "Contraseña cambiada correctamente");
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            response.put("success", false);
            response.put("data", null);
            response.put("message", e.getMessage());
            return ResponseEntity.status(400).body(response);
        }
    }

    @PostMapping("/cerrar-sesion")
    public ResponseEntity<Map<String, Object>> logout(HttpServletRequest request) {
        String authHeader = request.getHeader("Authorization");
        if (authHeader != null && authHeader.startsWith("Bearer ")) {
            tokenBlacklistService.revoke(authHeader.substring(7));
        }
        Map<String, Object> response = new HashMap<>();
        response.put("success", true);
        response.put("data", null);
        response.put("message", "Sesión cerrada exitosamente");
        return ResponseEntity.ok(response);
    }

    // Construye el objeto data que el frontend almacena en localStorage
    private Map<String, Object> buildUserData(User user, AuthResponse auth) {
        Map<String, Object> data = new HashMap<>();
        data.put("id", user.getId());
        data.put("username", user.getUsername());
        data.put("nombre", user.getName());
        data.put("apellido", user.getLastName());
        data.put("rol", user.getRole());
        data.put("token", auth.getAccesToken());
        data.put("refreshToken", auth.getRefreshToken());

        switch (user.getRole()) {
            case "cliente" -> customerRepository.findByUserId_Username(user.getUsername())
                .ifPresent(customer -> {
                    data.put("saldoUsd", customer.getBalance());
                    data.put("esEstudiante", customer.isStudent());
                });
            case "chofer" -> driverRepository.findByUsername_Username(user.getUsername())
                .ifPresent(driver -> {
                    data.put("habilitado", driver.isEnabled());
                    data.put("disponible", driver.isAvailable());
                });
        }
        return data;
    }
}
