package com.xpressrides.backend.dto.request;

import jakarta.validation.constraints.NotNull;

public class EnableRequest {
    @NotNull(message = "El estado de habilitación es obligatorio")
    private Boolean enabled;

    public Boolean getEnabled() { return enabled; }
    public void setEnabled(Boolean enabled) { this.enabled = enabled; }
}
