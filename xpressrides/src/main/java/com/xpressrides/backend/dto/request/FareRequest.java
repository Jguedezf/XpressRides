/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Traslados — Cálculo de Tarifa
 *  Descripción: DTO de entrada para calcular la tarifa antes de
 *               confirmar el viaje. No crea ni modifica nada.
 *  Versión:     1.0.0
 *  Fecha:       25/06/2026
 * ============================================================
 */
package com.xpressrides.backend.dto.request;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class FareRequest {

    private Integer idZoneOrigin;

    private Integer idZoneDestiny;

    private String originAddress;
    private Double originLat;
    private Double originLng;
    private String destinationAddress;
    private Double destinationLat;
    private Double destinationLng;

    @NotNull(message = "El número de pasajeros es obligatorio")
    @Min(value = 1, message = "Mínimo 1 pasajero")
    @Max(value = 3, message = "Máximo 3 pasajeros")
    private Integer passengerCount;
}
