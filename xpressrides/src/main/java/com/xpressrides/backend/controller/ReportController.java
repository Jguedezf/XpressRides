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
 *  Fecha:       24/06/2026
 * ============================================================
 */
package com.xpressrides.backend.controller;

import com.xpressrides.backend.model.*;
import com.xpressrides.backend.service.ReportService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/reportes")
@CrossOrigin(origins = "*")
@PreAuthorize("hasAnyRole('administrador', 'personal_admin')")
public class ReportController {

    private final ReportService reportService;

    // Inyección de dependencias por constructor
    public ReportController(ReportService reportService) {
        this.reportService = reportService;
    }

    // GET /api/reports/trip-history
    @GetMapping("/historial-traslados")
    public ResponseEntity<Map<String, Object>> getTripHistory() {
        List<TripHistory> data = reportService.getTripHistory();
        Map<String, Object> response = new HashMap<>();
        response.put("success", true);
        response.put("data", data);
        response.put("message", "OK");
        return ResponseEntity.ok(response);
    }

    // GET /api/reports/earnings
    @GetMapping("/ganancias")
    public ResponseEntity<Map<String, Object>> getCompanyEarnings() {
        List<CompanyEarnings> data = reportService.getCompanyEarnings();
        Map<String, Object> response = new HashMap<>();
        response.put("success", true);
        response.put("data", data);
        response.put("message", "OK");
        return ResponseEntity.ok(response);
    }

    // GET /api/reports/driver-payments
    @GetMapping("/pagos-chofer")
    public ResponseEntity<Map<String, Object>> getDriverPaymentReport() {
        List<DriverPaymentReport> data = reportService.getDriverPaymentReport();
        Map<String, Object> response = new HashMap<>();
        response.put("success", true);
        response.put("data", data);
        response.put("message", "OK");
        return ResponseEntity.ok(response);
    }

    // GET /api/reports/pending-payments
    @GetMapping("/pendientes-pago")
    public ResponseEntity<Map<String, Object>> getPendingDriverPayments() {
        List<PendingDriverPayment> data = reportService.getPendingDriverPayments();
        Map<String, Object> response = new HashMap<>();
        response.put("success", true);
        response.put("data", data);
        response.put("message", "OK");
        return ResponseEntity.ok(response);
    }

    // GET /api/reports/cancelled
    @GetMapping("/cancelados")
    public ResponseEntity<Map<String, Object>> getCancelledTrips() {
        List<CancelledTrip> data = reportService.getCancelledTrips();
        Map<String, Object> response = new HashMap<>();
        response.put("success", true);
        response.put("data", data);
        response.put("message", "OK");
        return ResponseEntity.ok(response);
    }

    // GET /api/reports/invoices
    @GetMapping("/facturas")
    public ResponseEntity<Map<String, Object>> getIssuedInvoices() {
        List<IssuedInvoice> data = reportService.getIssuedInvoices();
        Map<String, Object> response = new HashMap<>();
        response.put("success", true);
        response.put("data", data);
        response.put("message", "OK");
        return ResponseEntity.ok(response);
    }

    // GET /api/reports/notifications
    @GetMapping("/notificaciones")
    public ResponseEntity<Map<String, Object>> getPendingNotifications() {
        List<PendingNotification> data = reportService.getPendingNotifications();
        Map<String, Object> response = new HashMap<>();
        response.put("success", true);
        response.put("data", data);
        response.put("message", "OK");
        return ResponseEntity.ok(response);
    }
}
