package com.xpressrides.backend.controller;

import java.util.HashMap;
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

import com.xpressrides.backend.dto.request.CustomerProfileRequest;
import com.xpressrides.backend.dto.request.RatingRequest;
import com.xpressrides.backend.dto.request.ReferralCodeRequest;
import com.xpressrides.backend.dto.response.CustomerProfileResponse;
import com.xpressrides.backend.service.CustomerService;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/cliente")
public class CustomerController {

    private final CustomerService customerService;

    public CustomerController(CustomerService customerService) {
        this.customerService = customerService;
    }

    @PreAuthorize("hasRole('cliente')")
    @GetMapping("/perfil")
    public ResponseEntity<CustomerProfileResponse> getProfile(Authentication authentication) {
        return ResponseEntity.ok(customerService.getProfile(authentication.getName()));
    }

    @PreAuthorize("hasRole('cliente')")
    @PutMapping("/perfil")
    public ResponseEntity<CustomerProfileResponse> updateProfile(
            @Valid @RequestBody CustomerProfileRequest request,
            Authentication authentication) {
        return ResponseEntity.ok(customerService.updateProfile(authentication.getName(), request));
    }

    // PUT /api/cliente/perfil/referido — agrega tardíamente el código de quien lo refirió.
    // Se responde en formato {success, data, message} en vez de dejar que
    // GlobalExceptionHandler maneje la excepción: ese handler serializa el mensaje bajo
    // la clave "error", pero fetchAPI() en el frontend solo lee "message" — para que el
    // usuario vea el motivo exacto (código inválido, ya tiene uno, plazo vencido), este
    // endpoint captura la excepción y arma la respuesta él mismo, igual que
    // DriverController.rejectTrip.
    @PreAuthorize("hasRole('cliente')")
    @PutMapping("/perfil/referido")
    public ResponseEntity<Map<String, Object>> addReferralCode(
            @Valid @RequestBody ReferralCodeRequest request,
            Authentication authentication) {
        Map<String, Object> response = new HashMap<>();
        try {
            customerService.addReferralCode(authentication.getName(), request.getCodigoReferido());
            response.put("success", true);
            response.put("data", null);
            response.put("message", "Código de referido asignado correctamente.");
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            response.put("success", false);
            response.put("data", null);
            response.put("message", e.getMessage());
            return ResponseEntity.status(400).body(response);
        }
    }

    @PreAuthorize("hasRole('cliente')")
    @GetMapping("/traslados")
    public ResponseEntity<?> getTrips(Authentication authentication, org.springframework.data.domain.Pageable pageable) {
        return ResponseEntity.ok(customerService.getTrips(authentication.getName(), pageable));
    }

    @PreAuthorize("hasRole('cliente')")
    @GetMapping("/traslados/{id}")
    public ResponseEntity<?> getTripDetail(@PathVariable Integer id, Authentication authentication) {
        return ResponseEntity.ok(customerService.getTripDetail(authentication.getName(), id));
    }

    @PreAuthorize("hasRole('cliente')")
    @PutMapping("/traslados/{id}/calificar")
    public ResponseEntity<Map<String, String>> rateTrip(
            @PathVariable Integer id,
            @Valid @RequestBody RatingRequest request,
            Authentication authentication) {
        customerService.rateTrip(authentication.getName(), id, request);
        return ResponseEntity.ok(Map.of("message", "Calificación guardada"));
    }

    @PreAuthorize("hasRole('cliente')")
    @PutMapping("/traslados/{id}/cancelar")
    public ResponseEntity<Map<String, String>> cancelTrip(
            @PathVariable Integer id,
            @RequestBody Map<String, String> body,
            Authentication authentication) {
        String motivo = body.getOrDefault("motivo", "Cancelado por el cliente");
        customerService.cancelTrip(authentication.getName(), id, motivo);
        return ResponseEntity.ok(Map.of("message", "Viaje cancelado"));
    }

    @PreAuthorize("hasRole('cliente')")
    @GetMapping("/recargas")
    public ResponseEntity<?> getTopUps(Authentication authentication) {
        return ResponseEntity.ok(customerService.getTopUps(authentication.getName()));
    }

    @PreAuthorize("hasRole('cliente')")
    @GetMapping("/resenas")
    public ResponseEntity<?> getReviews(Authentication authentication) {
        return ResponseEntity.ok(customerService.getReviews(authentication.getName()));
    }

    @PreAuthorize("hasRole('cliente')")
    @GetMapping("/cupones")
    public ResponseEntity<?> getCoupons(Authentication authentication) {
        return ResponseEntity.ok(customerService.getCoupons(authentication.getName()));
    }

    // GET /api/cliente/viaje-activo — datos del viaje en curso con chofer y vehículo
    @PreAuthorize("hasRole('cliente')")
    @GetMapping("/viaje-activo")
    public ResponseEntity<?> getActiveTrip(Authentication authentication) {
        HashMap<String, Object> response = new HashMap<>();
        try {
            Map<String, Object> data = customerService.getActiveTrip(authentication.getName());
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
}
