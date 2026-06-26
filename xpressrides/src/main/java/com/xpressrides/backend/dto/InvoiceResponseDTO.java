/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Facturación
 *  Descripción: DTO de respuesta para el endpoint de detalle de
 *               factura — contrato exacto con el frontend según
 *               sección 7.5 del MANUAL_FRONTEND.md
 *  Versión:     1.0.0
 *  Fecha:       24/06/2026
 * ============================================================
 */
package com.xpressrides.backend.dto;

import lombok.Data;
import java.math.BigDecimal;

@Data
public class InvoiceResponseDTO {
    private Integer    facturaId;
    private String     numeroDocumento;
    private String     control;
    private String     serie;
    private String     fechaEmision;
    private String     horaEmision;
    private String     clienteNombre;
    private String     clienteCedula;
    private String     clienteDireccion;
    private String     choferNombre;
    private String     zonaOrigen;
    private String     zonaDestino;
    private BigDecimal distanciaKm;
    private BigDecimal descuentoUsd;
    private BigDecimal descuentoVes;
    private BigDecimal costoUsd;
    private BigDecimal tasaVes;
    private BigDecimal montoIgtfUsd;
    private BigDecimal totalUsd;
    private BigDecimal totalVes;
}
