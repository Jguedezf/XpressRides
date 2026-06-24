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
 *  Fecha:       24/06/2026  11:00
 * ============================================================
 */
package com.xpressrides.backend.controller;

import com.xpressrides.backend.model.PagoChofer;
import com.xpressrides.backend.model.RecargaSaldo;
import com.xpressrides.backend.service.PagoService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api")
@CrossOrigin(origins = "*")
public class PagoController {

    private final PagoService pagoService;

    // Inyección de dependencias por constructor
    public PagoController(PagoService pagoService) {
        this.pagoService = pagoService;
    }

    // POST /api/top-ups — cliente recarga su saldo
    @PostMapping("/top-ups")
    public ResponseEntity<Map<String, Object>> registrarRecarga(
            @Valid @RequestBody RecargaSaldo recarga) {
        Map<String, Object> response = new HashMap<>();
        try {
            RecargaSaldo nueva = pagoService.registrarRecarga(recarga);
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

    // GET /api/top-ups/client/{id} — historial de recargas de un cliente
    @GetMapping("/top-ups/client/{id}")
    public ResponseEntity<Map<String, Object>> historialRecargas(
            @PathVariable Integer id) {
        List<RecargaSaldo> recargas = pagoService.historialRecargas(id);
        Map<String, Object> response = new HashMap<>();
        response.put("success", true);
        response.put("data", recargas);
        response.put("message", "OK");
        return ResponseEntity.ok(response);
    }

    // POST /api/driver-payments — personal admin registra pago a chofer
    @PostMapping("/driver-payments")
    public ResponseEntity<Map<String, Object>> registrarPagoChofer(
            @Valid @RequestBody PagoChofer pago) {
        Map<String, Object> response = new HashMap<>();
        try {
            PagoChofer nuevo = pagoService.registrarPagoChofer(pago);
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
    @GetMapping("/driver-payments/driver/{id}")
    public ResponseEntity<Map<String, Object>> historialPagosChofer(
            @PathVariable Integer id) {
        List<PagoChofer> pagos = pagoService.historialPagosChofer(id);
        Map<String, Object> response = new HashMap<>();
        response.put("success", true);
        response.put("data", pagos);
        response.put("message", "OK");
        return ResponseEntity.ok(response);
    }
}