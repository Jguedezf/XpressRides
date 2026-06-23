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
 *  Versión:     1.0.0
 *  Fecha:       23/06/2026  HH:MM
 * ============================================================
 */
package com.xpressrides.backend.model;

import jakarta.persistence.*;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@Entity
@Table(name = "pago_chofer")
public class PagoChofer {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    // FK al chofer que recibe el pago
    @NotNull
    @Column(name = "id_chofer", nullable = false)
    private Integer idChofer;

    // FK al personal admin que registra el pago
    @NotNull
    @Column(name = "id_admin", nullable = false)
    private Integer idAdmin;

    // FK al banco donde se realizó la transferencia
    @NotNull
    @Column(name = "id_banco", nullable = false)
    private Integer idBanco;

    // Monto pagado en dólares
    @NotNull
    @DecimalMin(value = "0.01", message = "El monto debe ser mayor a cero")
    @Column(name = "monto_usd", nullable = false, precision = 10, scale = 2)
    private BigDecimal montoUsd;

    // Monto equivalente en bolívares
    @NotNull
    @DecimalMin(value = "0.01", message = "El monto en VES debe ser mayor a cero")
    @Column(name = "monto_ves", nullable = false, precision = 18, scale = 2)
    private BigDecimal montoVes;

    // Número de referencia bancaria — único por transacción
    @NotNull
    @Column(name = "referencia", nullable = false, unique = true, length = 50)
    private String referencia;

    // Fecha y hora del pago — se llena automáticamente
    @Column(name = "fecha_hora", nullable = false,
            updatable = false, insertable = true)
    @org.hibernate.annotations.CreationTimestamp
    private LocalDateTime fechaHora;
}