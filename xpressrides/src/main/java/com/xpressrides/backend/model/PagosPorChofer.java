/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Reportes — Vistas SQL
 *  Descripción: Mapeo de la vista 'v_pagos_por_chofer' —
 *               historial de pagos realizados a los choferes
 *  Versión:     1.0.0
 *  Fecha:       22/06/2026  HH:MM
 * ============================================================
 */
package com.xpressrides.backend.model;

import jakarta.persistence.*;
import lombok.Data;
import org.hibernate.annotations.Immutable;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@Entity
@Immutable
@Table(name = "v_pagos_por_chofer")
public class PagosPorChofer {

    @Id
    @Column(name = "id")
    private Integer id;

    @Column(name = "chofer")
    private String chofer;

    @Column(name = "banco")
    private String banco;

    @Column(name = "monto_usd")
    private BigDecimal montoUsd;

    @Column(name = "monto_ves")
    private BigDecimal montoVes;

    @Column(name = "referencia")
    private String referencia;

    @Column(name = "fecha_hora")
    private LocalDateTime fechaHora;
}