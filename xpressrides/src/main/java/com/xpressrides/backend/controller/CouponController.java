/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Cupones
 *  Descripción: Endpoints para gestión de cupones por el admin.
 *               Creación y asignación a clientes específicos.
 *  Versión:     1.0.0
 *  Fecha:       25/06/2026
 * ============================================================
 */
package com.xpressrides.backend.controller;

import com.xpressrides.backend.dto.request.CouponRequest;
import com.xpressrides.backend.model.Coupon;
import com.xpressrides.backend.model.CustomerCoupon;
import com.xpressrides.backend.service.CouponService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/cupones")
public class CouponController {

    private final CouponService couponService;

    public CouponController(CouponService couponService) {
        this.couponService = couponService;
    }

    // POST /api/cupones — admin crea un nuevo cupón de descuento
    @PreAuthorize("hasRole('administrador') or hasRole('personal_admin')")
    @PostMapping
    public ResponseEntity<Map<String, Object>> createCoupon(
            @Valid @RequestBody CouponRequest request) {

        Map<String, Object> response = new HashMap<>();
        try {
            Coupon coupon = couponService.createCoupon(request);
            response.put("success", true);
            response.put("data", coupon);
            response.put("message", "Cupón '" + coupon.getCode() + "' creado correctamente");
            return ResponseEntity.status(201).body(response);
        } catch (Exception e) {
            response.put("success", false);
            response.put("data", null);
            response.put("message", e.getMessage());
            return ResponseEntity.status(400).body(response);
        }
    }

    // POST /api/cupones/{id}/asignar/{clienteId} — admin asigna cupón a un cliente
    @PreAuthorize("hasRole('administrador') or hasRole('personal_admin')")
    @PostMapping("/{id}/asignar/{clienteId}")
    public ResponseEntity<Map<String, Object>> assignToClient(
            @PathVariable Integer id,
            @PathVariable Integer clienteId) {

        Map<String, Object> response = new HashMap<>();
        try {
            CustomerCoupon assignment = couponService.assignToClient(id, clienteId);
            response.put("success", true);
            response.put("data", assignment);
            response.put("message", "Cupón asignado correctamente al cliente ID: " + clienteId);
            return ResponseEntity.status(201).body(response);
        } catch (Exception e) {
            response.put("success", false);
            response.put("data", null);
            response.put("message", e.getMessage());
            return ResponseEntity.status(400).body(response);
        }
    }
}
