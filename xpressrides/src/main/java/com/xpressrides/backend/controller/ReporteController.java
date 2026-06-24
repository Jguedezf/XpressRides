/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Reportes — Vistas SQL
 *  Descripción: Controlador REST para todos los reportes —
 *               expone 7 endpoints GET al panel administrativo
 *  Versión:     1.1.0
 *  Fecha:       24/06/2026  11:00
 * ============================================================
 */
package com.xpressrides.backend.controller;

import com.xpressrides.backend.model.*;
import com.xpressrides.backend.service.ReporteService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/reports")
@CrossOrigin(origins = "*")
public class ReporteController {

    private final ReporteService reporteService;

    // Inyección de dependencias por constructor
    public ReporteController(ReporteService reporteService) {
        this.reporteService = reporteService;
    }

    // GET /api/reports/trip-history
    @GetMapping("/trip-history")
    public ResponseEntity<Map<String, Object>> historialTraslados() {
        List<HistorialTraslados> data = reporteService.listarHistorialTraslados();
        Map<String, Object> response = new HashMap<>();
        response.put("success", true);
        response.put("data", data);
        response.put("message", "OK");
        return ResponseEntity.ok(response);
    }

    // GET /api/reports/earnings
    @GetMapping("/earnings")
    public ResponseEntity<Map<String, Object>> ganancias() {
        List<GananciasEmpresa> data = reporteService.listarGanancias();
        Map<String, Object> response = new HashMap<>();
        response.put("success", true);
        response.put("data", data);
        response.put("message", "OK");
        return ResponseEntity.ok(response);
    }

    // GET /api/reports/driver-payments
    @GetMapping("/driver-payments")
    public ResponseEntity<Map<String, Object>> pagosPorChofer() {
        List<PagosPorChofer> data = reporteService.listarPagosPorChofer();
        Map<String, Object> response = new HashMap<>();
        response.put("success", true);
        response.put("data", data);
        response.put("message", "OK");
        return ResponseEntity.ok(response);
    }

    // GET /api/reports/pending-payments
    @GetMapping("/pending-payments")
    public ResponseEntity<Map<String, Object>> pendientesPago() {
        List<PendientesPagoChofer> data = reporteService.listarPendientesPago();
        Map<String, Object> response = new HashMap<>();
        response.put("success", true);
        response.put("data", data);
        response.put("message", "OK");
        return ResponseEntity.ok(response);
    }

    // GET /api/reports/cancelled
    @GetMapping("/cancelled")
    public ResponseEntity<Map<String, Object>> cancelados() {
        List<TrasladosCancelados> data = reporteService.listarCancelados();
        Map<String, Object> response = new HashMap<>();
        response.put("success", true);
        response.put("data", data);
        response.put("message", "OK");
        return ResponseEntity.ok(response);
    }

    // GET /api/reports/invoices
    @GetMapping("/invoices")
    public ResponseEntity<Map<String, Object>> facturas() {
        List<FacturasEmitidas> data = reporteService.listarFacturas();
        Map<String, Object> response = new HashMap<>();
        response.put("success", true);
        response.put("data", data);
        response.put("message", "OK");
        return ResponseEntity.ok(response);
    }

    // GET /api/reports/notifications
    @GetMapping("/notifications")
    public ResponseEntity<Map<String, Object>> notificaciones() {
        List<NotificacionesPendientes> data = reporteService.listarNotificaciones();
        Map<String, Object> response = new HashMap<>();
        response.put("success", true);
        response.put("data", data);
        response.put("message", "OK");
        return ResponseEntity.ok(response);
    }
}