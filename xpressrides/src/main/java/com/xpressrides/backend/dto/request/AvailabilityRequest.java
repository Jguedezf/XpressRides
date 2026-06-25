package com.xpressrides.backend.dto.request;

import jakarta.validation.constraints.NotNull;

public class AvailabilityRequest {
    @NotNull(message = "Se necesita saber el estado de disponibilidad")
    private boolean available;

    public boolean getAvailable(){return available;}
    public void setAvailable(boolean available){this.available = available;}
}
