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
 *  Versión:     1.0.0
 *  Fecha:       22/06/2026  19:00
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
public class TasaBcv {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    // Fecha de vigencia — única por día (UNIQUE en BD)
    @NotNull
    @Column(name = "fecha_vigencia", nullable = false, unique = true)
    private LocalDate fechaVigencia;

    // Tasa en bolívares por dólar — debe ser positiva
    @NotNull
    @DecimalMin(value = "0.01", message = "La tasa debe ser mayor a cero")
    @Column(name = "tasa_ves", nullable = false, precision = 14, scale = 4)
    private BigDecimal tasaVes;

    // FK al usuario personal_admin que registró la tasa
    @NotNull
    @Column(name = "registrado_por", nullable = false)
    private Integer registradoPor;

    @Column(name = "creado_en", nullable = false, updatable = false,
            insertable = true)
    @org.hibernate.annotations.CreationTimestamp
    private LocalDateTime creadoEn;
}