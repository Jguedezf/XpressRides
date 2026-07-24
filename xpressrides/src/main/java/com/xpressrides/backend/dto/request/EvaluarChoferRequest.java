package com.xpressrides.backend.dto.request;

import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;

public class EvaluarChoferRequest {

    @NotNull(message = "La nota psicológica es obligatoria")
    private BigDecimal notaPsicologica;

    @NotNull(message = "La nota vehicular es obligatoria")
    private BigDecimal notaVehicular;

    public BigDecimal getNotaPsicologica() {
        return notaPsicologica;
    }

    public void setNotaPsicologica(BigDecimal notaPsicologica) {
        this.notaPsicologica = notaPsicologica;
    }

    public BigDecimal getNotaVehicular() {
        return notaVehicular;
    }

    public void setNotaVehicular(BigDecimal notaVehicular) {
        this.notaVehicular = notaVehicular;
    }
}
