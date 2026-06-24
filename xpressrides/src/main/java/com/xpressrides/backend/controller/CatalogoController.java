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
 *  Versión:     1.1.0
 *  Fecha:       24/06/2026  11:00
 * ============================================================
 */
package com.xpressrides.backend.controller;

import com.xpressrides.backend.model.Banco;
import com.xpressrides.backend.model.Zona;
import com.xpressrides.backend.service.CatalogoService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api")
@CrossOrigin(origins = "*")
public class CatalogoController {

    private final CatalogoService catalogoService;

    // Inyección de dependencias por constructor
    public CatalogoController(CatalogoService catalogoService) {
        this.catalogoService = catalogoService;
    }

    // GET /api/zones — retorna todas las zonas activas
    @GetMapping("/zones")
    public ResponseEntity<Map<String, Object>> listarZonas() {
        List<Zona> zonas = catalogoService.listarZonasActivas();
        Map<String, Object> response = new HashMap<>();
        response.put("success", true);
        response.put("data", zonas);
        response.put("message", "OK");
        return ResponseEntity.ok(response);
    }

    // GET /api/zones/all — retorna todas las zonas sin filtro (admin)
    @GetMapping("/zones/all")
    public ResponseEntity<Map<String, Object>> listarTodasLasZonas() {
        List<Zona> zonas = catalogoService.listarTodasLasZonas();
        Map<String, Object> response = new HashMap<>();
        response.put("success", true);
        response.put("data", zonas);
        response.put("message", "OK");
        return ResponseEntity.ok(response);
    }

    // GET /api/banks — retorna todos los bancos activos
    @GetMapping("/banks")
    public ResponseEntity<Map<String, Object>> listarBancos() {
        List<Banco> bancos = catalogoService.listarBancosActivos();
        Map<String, Object> response = new HashMap<>();
        response.put("success", true);
        response.put("data", bancos);
        response.put("message", "OK");
        return ResponseEntity.ok(response);
    }

    // GET /api/banks/all — retorna todos los bancos sin filtro (admin)
    @GetMapping("/banks/all")
    public ResponseEntity<Map<String, Object>> listarTodosLosBancos() {
        List<Banco> bancos = catalogoService.listarTodosLosBancos();
        Map<String, Object> response = new HashMap<>();
        response.put("success", true);
        response.put("data", bancos);
        response.put("message", "OK");
        return ResponseEntity.ok(response);
    }
}