/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Traslados — Cálculo de Tarifa
 *  Descripción: DTO de salida con el desglose completo de tarifa
 *               según el Algoritmo Híbrido Dinámico. Las claves JSON
 *               siguen el contrato del MANUAL_FRONTEND.md sección 7.2.
 *  Versión:     1.0.0
 *  Fecha:       25/06/2026
 * ============================================================
 */
package com.xpressrides.backend.dto.response;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class FareResponse {

    @JsonProperty("distanciaKm")
    private BigDecimal distanceKm;

    @JsonProperty("tarifaBase")
    private BigDecimal baseFare;

    @JsonProperty("costoDistancia")
    private BigDecimal distanceCost;

    @JsonProperty("recargoHoraPico")
    private BigDecimal peakHourSurcharge;

    @JsonProperty("recargoNocturnoFinSemana")
    private BigDecimal nightWeekendSurcharge;

    @JsonProperty("descuentoAplicado")
    private BigDecimal discountApplied;

    @JsonProperty("costoFinalUsd")
    private BigDecimal finalCostUsd;

    @JsonProperty("costoFinalVes")
    private BigDecimal finalCostVes;

    @JsonProperty("tasaBcvId")
    private Integer exchangeRateId;

    // Banderas extra para que el frontend muestre los badges correctos
    @JsonProperty("primerViajeGratis")
    private boolean firstTripFree;

    @JsonProperty("descuentoEstudiantil")
    private boolean studentDiscount;

    // Oferta proactiva de cupón de referido — el frontend debe mostrarla
    // visible junto al estimado, no como selector oculto (ver FareService).
    @JsonProperty("cuponReferidoDisponible")
    private boolean referralCouponAvailable;

    @JsonProperty("idCuponReferido")
    private Integer referralCouponClienteId;

    @JsonProperty("descuentoCuponReferido")
    private BigDecimal referralCouponDiscount;

    @JsonProperty("costoConCuponUsd")
    private BigDecimal costWithCouponUsd;

    @JsonProperty("costoConCuponVes")
    private BigDecimal costWithCouponVes;
}
