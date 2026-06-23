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
 *  Versión:     1.0.0
 *  Fecha:       22/06/2026  HH:MM
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
@RequestMapping("/api/reportes")
@CrossOrigin(origins = "*")
public class ReporteController {

    private final ReporteService reporteService;

    // Inyección de dependencias por constructor
    public ReporteController(ReporteService reporteService) {
        this.reporteService = reporteService;
    }

    // GET /api/reportes/historial-traslados
    @GetMapping("/historial-traslados")
    public ResponseEntity<Map<String, Object>> historialTraslados() {
        List<HistorialTraslados> data = reporteService.listarHistorialTraslados();
        Map<String, Object> response = new HashMap<>();
        response.put("success", true);
        response.put("data", data);
        response.put("message", "OK");
        return ResponseEntity.ok(response);
    }

    // GET /api/reportes/ganancias
    @GetMapping("/ganancias")
    public ResponseEntity<Map<String, Object>> ganancias() {
        List<GananciasEmpresa> data = reporteService.listarGanancias();
        Map<String, Object> response = new HashMap<>();
        response.put("success", true);
        response.put("data", data);
        response.put("message", "OK");
        return ResponseEntity.ok(response);
    }

    // GET /api/reportes/pagos-chofer
    @GetMapping("/pagos-chofer")
    public ResponseEntity<Map<String, Object>> pagosPorChofer() {
        List<PagosPorChofer> data = reporteService.listarPagosPorChofer();
        Map<String, Object> response = new HashMap<>();
        response.put("success", true);
        response.put("data", data);
        response.put("message", "OK");
        return ResponseEntity.ok(response);
    }

    // GET /api/reportes/pendientes-pago
    @GetMapping("/pendientes-pago")
    public ResponseEntity<Map<String, Object>> pendientesPago() {
        List<PendientesPagoChofer> data = reporteService.listarPendientesPago();
        Map<String, Object> response = new HashMap<>();
        response.put("success", true);
        response.put("data", data);
        response.put("message", "OK");
        return ResponseEntity.ok(response);
    }

    // GET /api/reportes/cancelados
    @GetMapping("/cancelados")
    public ResponseEntity<Map<String, Object>> cancelados() {
        List<TrasladosCancelados> data = reporteService.listarCancelados();
        Map<String, Object> response = new HashMap<>();
        response.put("success", true);
        response.put("data", data);
        response.put("message", "OK");
        return ResponseEntity.ok(response);
    }

    // GET /api/reportes/facturas
    @GetMapping("/facturas")
    public ResponseEntity<Map<String, Object>> facturas() {
        List<FacturasEmitidas> data = reporteService.listarFacturas();
        Map<String, Object> response = new HashMap<>();
        response.put("success", true);
        response.put("data", data);
        response.put("message", "OK");
        return ResponseEntity.ok(response);
    }

    // GET /api/reportes/notificaciones
    @GetMapping("/notificaciones")
    public ResponseEntity<Map<String, Object>> notificaciones() {
        List<NotificacionesPendientes> data = reporteService.listarNotificaciones();
        Map<String, Object> response = new HashMap<>();
        response.put("success", true);
        response.put("data", data);
        response.put("message", "OK");
        return ResponseEntity.ok(response);
    }
}