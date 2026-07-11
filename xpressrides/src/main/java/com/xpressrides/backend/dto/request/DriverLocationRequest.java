package com.xpressrides.backend.dto.request;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class DriverLocationRequest {

    @NotNull(message = "La latitud es obligatoria")
    private Double lat;

    @NotNull(message = "La longitud es obligatoria")
    private Double lng;
}
