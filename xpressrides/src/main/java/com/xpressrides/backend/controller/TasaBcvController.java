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
 *  Fecha:       24/06/2026  11:00
 * ============================================================
 */
package com.xpressrides.backend.controller;

import com.xpressrides.backend.model.TasaBcv;
import com.xpressrides.backend.service.TasaBcvService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

@RestController
@RequestMapping("/api")
@CrossOrigin(origins = "*")
public class TasaBcvController {

    private final TasaBcvService tasaBcvService;

    // Inyección de dependencias por constructor
    public TasaBcvController(TasaBcvService tasaBcvService) {
        this.tasaBcvService = tasaBcvService;
    }

    // GET /api/exchange-rate/current — retorna la tasa BCV del día
    // Si hoy es feriado o fin de semana, retorna la del último día hábil
    @GetMapping("/exchange-rate/current")
    public ResponseEntity<Map<String, Object>> obtenerTasaVigente() {
        Optional<TasaBcv> tasa = tasaBcvService.obtenerTasaVigente();
        Map<String, Object> response = new HashMap<>();
        if (tasa.isPresent()) {
            response.put("success", true);
            response.put("data", tasa.get());
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
    @GetMapping("/exchange-rate/history")
    public ResponseEntity<Map<String, Object>> listarHistorial() {
        List<TasaBcv> historial = tasaBcvService.listarHistorial();
        Map<String, Object> response = new HashMap<>();
        response.put("success", true);
        response.put("data", historial);
        response.put("message", "OK");
        return ResponseEntity.ok(response);
    }

    // POST /api/exchange-rate — registra una nueva tasa BCV
    // Solo personal_admin puede usar este endpoint
    // La seguridad por rol la agrega Eliuber cuando tenga el login listo
    @PostMapping("/exchange-rate")
    public ResponseEntity<Map<String, Object>> registrarTasa(@Valid @RequestBody TasaBcv tasa) {
        Map<String, Object> response = new HashMap<>();
        try {
            TasaBcv nueva = tasaBcvService.registrarTasa(tasa);
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
}