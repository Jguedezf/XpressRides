/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Facturación
 *  Descripción: Entidad que representa la tabla 'factura' —
 *               factura fiscal generada automáticamente por el
 *               trigger al completarse un traslado
 *  Versión:     1.0.0
 *  Fecha:       24/06/2026
 * ============================================================
 */
package com.xpressrides.backend.model;

import jakarta.persistence.*;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@Entity
@Table(name = "factura")
public class Invoice {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(name = "id_traslado", nullable = false, unique = true)
    private Integer tripId;

    @Column(name = "nro_documento", nullable = false, unique = true, length = 20)
    private String documentNumber;

    @Column(name = "nro_control", nullable = false, unique = true, length = 20)
    private String controlNumber;

    @Column(name = "serie", nullable = false, length = 5)
    private String series;

    @Column(name = "fecha_emision", nullable = false)
    private LocalDateTime issueDateTime;

    @Column(name = "razon_social", nullable = false, length = 120)
    private String clientName;

    @Column(name = "rif_cedula", nullable = false, length = 15)
    private String clientTaxId;

    @Column(name = "direccion_fiscal", nullable = false, length = 200)
    private String clientAddress;

    @Column(name = "igtf_porcentaje", nullable = false, precision = 5, scale = 2)
    private BigDecimal igtfPercentage;

    @Column(name = "igtf_monto_usd", nullable = false, precision = 10, scale = 2)
    private BigDecimal igtfAmountUsd;
}
