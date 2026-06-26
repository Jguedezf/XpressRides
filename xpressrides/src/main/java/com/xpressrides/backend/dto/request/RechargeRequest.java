package com.xpressrides.backend.dto.request;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;

public class RechargeRequest {
    @NotNull
    @DecimalMin(value = "0.01", message = "El monto debe ser mayor a cero")
    private BigDecimal montoUsd;

    @NotNull
    private Integer idBanco;

    @NotBlank
    private String referencia;

    public BigDecimal getMontoUsd() { return montoUsd; }
    public void setMontoUsd(BigDecimal montoUsd) { this.montoUsd = montoUsd; }

    public Integer getIdBanco() { return idBanco; }
    public void setIdBanco(Integer idBanco) { this.idBanco = idBanco; }

    public String getReferencia() { return referencia; }
    public void setReferencia(String referencia) { this.referencia = referencia; }
}
