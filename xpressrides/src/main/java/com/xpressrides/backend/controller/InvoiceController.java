/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Facturación
 *  Descripción: Controlador REST para facturación — expone el
 *               endpoint de detalle de factura por id de traslado
 *  Versión:     1.0.0
 *  Fecha:       24/06/2026
 * ============================================================
 */
package com.xpressrides.backend.controller;

import com.xpressrides.backend.dto.InvoiceResponseDTO;
import com.xpressrides.backend.service.InvoiceService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api")
public class InvoiceController {

    private final InvoiceService invoiceService;

    public InvoiceController(InvoiceService invoiceService) {
        this.invoiceService = invoiceService;
    }

    // GET /api/facturas/{trasladoId} — detalle de factura para el frontend
    @PreAuthorize("hasAnyRole('cliente', 'administrador', 'personal_admin')")
    @GetMapping("/facturas/{trasladoId}")
    public ResponseEntity<Map<String, Object>> getInvoice(
            @PathVariable Integer trasladoId) {
        Map<String, Object> response = new HashMap<>();
        try {
            InvoiceResponseDTO dto = invoiceService.getInvoiceByTripId(trasladoId);
            response.put("success", true);
            response.put("data", dto);
            response.put("message", "OK");
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            response.put("success", false);
            response.put("data", null);
            response.put("message", e.getMessage());
            return ResponseEntity.status(404).body(response);
        }
    }
}
