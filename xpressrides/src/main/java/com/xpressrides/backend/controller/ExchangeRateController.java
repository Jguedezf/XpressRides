/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Tasa BCV
 *  Descripción: Controlador REST para la tasa BCV —
 *               consulta de tasa vigente y registro de nueva tasa.
 *               El registro solo lo hace personal_admin.
 *  Versión:     1.1.0
 *  Fecha:       24/06/2026
 * ============================================================
 */
package com.xpressrides.backend.controller;

import com.xpressrides.backend.model.ExchangeRate;
import com.xpressrides.backend.service.ExchangeRateService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.springframework.security.access.prepost.PreAuthorize;

@RestController
@RequestMapping("/api")
@CrossOrigin(origins = "*")
public class ExchangeRateController {

    private final ExchangeRateService exchangeRateService;

    // Inyección de dependencias por constructor
    public ExchangeRateController(ExchangeRateService exchangeRateService) {
        this.exchangeRateService = exchangeRateService;
    }

    // GET /api/exchange-rate/current — retorna la tasa BCV del día
    // Si hoy es feriado o fin de semana, retorna la del último día hábil
    @GetMapping("/tasa-bcv/vigente")
    public ResponseEntity<Map<String, Object>> getCurrentRate() {
        Optional<ExchangeRate> rate = exchangeRateService.getCurrentRate();
        Map<String, Object> response = new HashMap<>();
        if (rate.isPresent()) {
            response.put("success", true);
            response.put("data", rate.get());
            response.put("message", "OK");
            return ResponseEntity.ok(response);
        } else {
            response.put("success", false);
            response.put("data", null);
            response.put("message", "No hay tasa BCV registrada.");
            return ResponseEntity.status(404).body(response);
        }
    }

    // GET /api/exchange-rate/history — retorna todas las tasas registradas
    @GetMapping("/tasa-bcv/historial")
    public ResponseEntity<Map<String, Object>> getHistory() {
        List<ExchangeRate> history = exchangeRateService.getHistory();
        Map<String, Object> response = new HashMap<>();
        response.put("success", true);
        response.put("data", history);
        response.put("message", "OK");
        return ResponseEntity.ok(response);
    }

    // POST /api/exchange-rate — registra una nueva tasa BCV
    @PreAuthorize("hasAnyRole('administrador', 'personal_admin')")
    @PostMapping("/tasa-bcv")
    public ResponseEntity<Map<String, Object>> registerRate(
            @Valid @RequestBody ExchangeRate exchangeRate) {
        Map<String, Object> response = new HashMap<>();
        try {
            ExchangeRate nueva = exchangeRateService.registerRate(exchangeRate);
            response.put("success", true);
            response.put("data", nueva);
            response.put("message", "Tasa BCV registrada correctamente.");
            return ResponseEntity.status(201).body(response);
        } catch (Exception e) {
            response.put("success", false);
            response.put("data", null);
            response.put("message", "Error al registrar la tasa: " + e.getMessage());
            return ResponseEntity.status(400).body(response);
        }
    }

    // GET /api/tasa-bcv/convertir?monto=&moneda=
    @GetMapping("/tasa-bcv/convertir")
    public ResponseEntity<Map<String, Object>> convertCurrency(
            @RequestParam double monto,
            @RequestParam String moneda) {
        
        Optional<ExchangeRate> rateOpt = exchangeRateService.getCurrentRate();
        Map<String, Object> response = new HashMap<>();
        if (rateOpt.isEmpty()) {
            response.put("success", false);
            response.put("message", "No hay tasa BCV vigente");
            return ResponseEntity.status(404).body(response);
        }
        
        double tasa = rateOpt.get().getRateVes().doubleValue();
        double ves = monto * tasa;
        
        response.put("success", true);
        response.put("ves", ves);
        response.put("message", "Conversión exitosa");
        return ResponseEntity.ok(response);
    }
}
