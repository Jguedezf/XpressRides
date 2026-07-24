/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Cupones
 *  Descripción: DTO de entrada para que el admin cree un cupón
 *  Versión:     1.0.0
 *  Fecha:       25/06/2026
 * ============================================================
 */
package com.xpressrides.backend.dto.request;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import lombok.Data;

import java.math.BigDecimal;

@Data
public class CouponRequest {

    @NotBlank(message = "El código del cupón es obligatorio")
    private String code;

    @NotBlank(message = "El tipo de cupón es obligatorio")
    @Pattern(
        regexp = "bienvenida|estudiante|promocional|referido",
        message = "Tipo inválido. Valores permitidos: bienvenida, estudiante, promocional, referido"
    )
    private String type;

    @NotNull(message = "El descuento en USD es obligatorio")
    @DecimalMin(value = "0.01", message = "El descuento debe ser mayor a cero")
    private BigDecimal discountUsd;

    // Opcional — null significa sin límite de distancia
    private Integer maxDistanceKm;
}
