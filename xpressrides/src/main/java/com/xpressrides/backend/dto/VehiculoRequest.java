package com.xpressrides.backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class VehiculoRequest {
    @NotBlank String placa;
    @NotBlank String marca;
    @NotBlank String modelo;
    @NotNull Integer anioFabricacion;
    @NotBlank String color;

}
