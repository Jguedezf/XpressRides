package com.xpressrides.backend.dto.request;

import jakarta.validation.constraints.NotBlank;

public class ReferralCodeRequest {

    @NotBlank(message = "El código de referido es obligatorio")
    private String codigoReferido;

    public String getCodigoReferido() { return codigoReferido; }
    public void setCodigoReferido(String codigoReferido) { this.codigoReferido = codigoReferido; }
}
