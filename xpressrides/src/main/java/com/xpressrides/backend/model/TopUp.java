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
 *  Versión:     1.2.0
 *  Fecha:       24/06/2026
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
public class TopUp {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @NotNull
    @Column(name = "id_cliente", nullable = false)
    private Integer customerId;

    // Nullable: recargas directas en USD no requieren banco venezolano
    @Column(name = "id_banco")
    private Integer bankId;

    @NotNull
    @Column(name = "id_tasa", nullable = false)
    private Integer exchangeRateId;

    @NotNull
    @DecimalMin(value = "0.01", message = "El monto debe ser mayor a cero")
    @Column(name = "monto_usd", nullable = false, precision = 10, scale = 2)
    private BigDecimal amountUsd;

    @NotNull
    @DecimalMin(value = "0.01", message = "El monto en VES debe ser mayor a cero")
    @Column(name = "monto_ves", nullable = false, precision = 18, scale = 2)
    private BigDecimal amountVes;

    @NotNull
    @Column(name = "referencia", nullable = false, unique = true, length = 50)
    private String reference;

    @Column(name = "fecha_hora", nullable = false, updatable = false)
    private LocalDateTime dateTime;

    // "VES" o "USD" — el servicio asigna "VES" por defecto si no se envía
    @Column(name = "moneda_pago", nullable = false, length = 3)
    private String paymentCurrency;

    @Column(name = "igtf_porcentaje", precision = 5, scale = 2)
    private BigDecimal igtfPercentage;

    @Column(name = "igtf_monto_usd", precision = 10, scale = 2)
    private BigDecimal igtfAmountUsd;
}
