/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Reportes — Vistas SQL
 *  Descripción: Mapeo de la vista 'v_pendientes_pago_chofer' —
 *               choferes con saldo pendiente de pago
 *  Versión:     1.1.0
 *  Fecha:       24/06/2026
 * ============================================================
 */
package com.xpressrides.backend.model;

import jakarta.persistence.*;
import lombok.Data;
import org.hibernate.annotations.Immutable;
import java.math.BigDecimal;

@Data
@Entity
@Immutable
@Table(name = "v_pendientes_pago_chofer")
public class PendingDriverPayment {

    @Id
    @Column(name = "id_chofer")
    private Integer driverId;

    @Column(name = "chofer")
    private String driverName;

    @Column(name = "saldo_acumulado_usd")
    private BigDecimal accumulatedBalanceUsd;

    @Column(name = "viajes_pendientes")
    private Integer pendingTrips;

    @Column(name = "total_pendiente_usd")
    private BigDecimal pendingTotalUsd;
}
