/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Pagos y Facturación
 *  Descripción: Entidad que representa la tabla 'pago_chofer' —
 *               registro de pagos realizados por personal admin
 *               a los choferes por sus ganancias acumuladas
 *  Versión:     1.1.0
 *  Fecha:       24/06/2026
 * ============================================================
 */
package com.xpressrides.backend.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@Entity
@NoArgsConstructor
@AllArgsConstructor
@Table(name = "pago_chofer")
public class DriverPayment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne
    @JoinColumn(name = "id_chofer")
    private Driver driver;

    @ManyToOne
    @JoinColumn(name = "id_admin")
    private AdminPersonnel admin;

    @ManyToOne
    @JoinColumn(name = "id_banco")
    private Bank bank;

    @Column(name = "monto_usd", nullable = false, precision = 10, scale = 2)
    private BigDecimal amountUsd;

    @Column(name = "monto_ves", nullable = false, precision = 18, scale = 2)
    private BigDecimal amountVes;

    @Column(name = "referencia", nullable = false, unique = true, length = 50)
    private String reference;

    @Column(name = "fecha_hora", nullable = false, updatable = false)
    private LocalDateTime dateTime;
}
