/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Pagos y Facturación
 *  Descripción: Controlador REST para pagos — expone endpoints
 *               para recargas de clientes y pagos a choferes
 *  Versión:     1.1.0
 *  Fecha:       24/06/2026
 * ============================================================
 */
package com.xpressrides.backend.controller;

import com.xpressrides.backend.model.DriverPayment;
import com.xpressrides.backend.model.TopUp;
import com.xpressrides.backend.service.PaymentService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api")
@CrossOrigin(origins = "*")
public class PaymentController {

    private final PaymentService paymentService;

    // Inyección de dependencias por constructor
    public PaymentController(PaymentService paymentService) {
        this.paymentService = paymentService;
    }

    // POST /api/top-ups — cliente recarga su saldo
    @PreAuthorize("hasRole('cliente')")
    @PostMapping("/recargas")
    public ResponseEntity<Map<String, Object>> registerTopUp(
            @Valid @RequestBody TopUp topUp) {
        Map<String, Object> response = new HashMap<>();
        try {
            TopUp nueva = paymentService.registerTopUp(topUp);
            response.put("success", true);
            response.put("data", nueva);
            response.put("message", "Recarga registrada correctamente.");
            return ResponseEntity.status(201).body(response);
        } catch (Exception e) {
            response.put("success", false);
            response.put("data", null);
            response.put("message", "Error al registrar recarga: " + e.getMessage());
            return ResponseEntity.status(400).body(response);
        }
    }

    // GET /api/top-ups/client/{id} — historial de recargas de un cliente (uso admin)
    @PreAuthorize("hasAnyRole('administrador', 'personal_admin')")
    @GetMapping("/recargas/cliente/{id}")
    public ResponseEntity<Map<String, Object>> getTopUpHistory(
            @PathVariable Integer id) {
        List<TopUp> recargas = paymentService.getTopUpHistory(id);
        Map<String, Object> response = new HashMap<>();
        response.put("success", true);
        response.put("data", recargas);
        response.put("message", "OK");
        return ResponseEntity.ok(response);
    }

    // POST /api/driver-payments — personal admin registra pago a chofer
    @PreAuthorize("hasRole('personal_admin')")
    @PostMapping("/pagos-chofer")
    public ResponseEntity<Map<String, Object>> registerDriverPayment(
            @Valid @RequestBody DriverPayment payment) {
        Map<String, Object> response = new HashMap<>();
        try {
            DriverPayment nuevo = paymentService.registerDriverPayment(payment);
            response.put("success", true);
            response.put("data", nuevo);
            response.put("message", "Pago al chofer registrado correctamente.");
            return ResponseEntity.status(201).body(response);
        } catch (Exception e) {
            response.put("success", false);
            response.put("data", null);
            response.put("message", "Error al registrar pago: " + e.getMessage());
            return ResponseEntity.status(400).body(response);
        }
    }

    // GET /api/driver-payments/driver/{id} — historial de pagos de un chofer
    @PreAuthorize("hasAnyRole('administrador', 'personal_admin')")
    @GetMapping("/pagos-chofer/chofer/{id}")
    public ResponseEntity<Map<String, Object>> getDriverPaymentHistory(
            @PathVariable Integer id) {
        List<DriverPayment> pagos = paymentService.getDriverPaymentHistory(id);
        Map<String, Object> response = new HashMap<>();
        response.put("success", true);
        response.put("data", pagos);
        response.put("message", "OK");
        return ResponseEntity.ok(response);
    }
}
