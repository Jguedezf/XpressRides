/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Pagos y Facturación
 *  Descripción: Entidad que representa la tabla 'recarga_saldo' —
 *               registro de recargas de saldo realizadas por clientes
 *               mediante transferencia bancaria en bolívares o dólares
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
@Table(name = "recarga_saldo")
public class RecargaSaldo {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    // FK al cliente que realizó la recarga
    @NotNull
    @Column(name = "id_cliente", nullable = false)
    private Integer idCliente;

    // FK al banco desde donde se realizó la transferencia
    @NotNull
    @Column(name = "id_banco", nullable = false)
    private Integer idBanco;

    // FK a la tasa BCV vigente al momento de la recarga
    @NotNull
    @Column(name = "id_tasa", nullable = false)
    private Integer idTasa;

    // Monto recargado en dólares
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

    // Fecha y hora de la recarga — se llena automáticamente
    @Column(name = "fecha_hora", nullable = false,
            updatable = false, insertable = true)
    @org.hibernate.annotations.CreationTimestamp
    private LocalDateTime fechaHora;
}