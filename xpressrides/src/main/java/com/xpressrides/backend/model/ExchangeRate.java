/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Tasa BCV
 *  Descripción: Entidad que representa la tabla 'tasa_bcv' —
 *               tasa de cambio oficial BCV publicada en días
 *               hábiles bancarios (lunes a viernes no feriados)
 *  Versión:     1.1.0
 *  Fecha:       24/06/2026
 * ============================================================
 */
package com.xpressrides.backend.model;

import jakarta.persistence.*;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Data
@Entity
@Table(name = "tasa_bcv")
public class ExchangeRate {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @NotNull
    @Column(name = "fecha_vigencia", nullable = false, unique = true)
    private LocalDate effectiveDate;

    @NotNull
    @DecimalMin(value = "0.01", message = "La tasa debe ser mayor a cero")
    @Column(name = "tasa_ves", nullable = false, precision = 14, scale = 4)
    private BigDecimal rateVes;

    @NotNull
    @Column(name = "registrado_por", nullable = false)
    private Integer registeredBy;

    @Column(name = "creado_en", nullable = false, updatable = false)
    private LocalDateTime createdAt;
}
