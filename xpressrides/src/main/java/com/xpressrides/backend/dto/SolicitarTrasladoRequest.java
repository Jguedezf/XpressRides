package com.xpressrides.backend.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class SolicitarTrasladoRequest {
    @NotNull Integer idZoneOrigin;
    @NotNull Integer idZoneDestiny;
    @NotNull @Min(1) @Max(3) private Integer nroPasajeros;
    private Integer idCuponCliente;

}
