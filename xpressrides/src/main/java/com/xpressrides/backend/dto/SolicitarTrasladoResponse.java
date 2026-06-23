package com.xpressrides.backend.dto;

import lombok.Data;

@Data
public class SolicitarTrasladoResponse {
    private boolean success;
    private Integer idTraslado;
    private String message;
}
