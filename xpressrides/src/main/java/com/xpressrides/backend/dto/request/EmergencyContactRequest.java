package com.xpressrides.backend.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;

public class EmergencyContactRequest {

    @NotNull(message = "El ID del chofer es obligatorio")
    private Integer driverId;

    @NotBlank(message = "El nombre es obligatorio")
    @Pattern(regexp = "^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\\s]+$",
            message = "El nombre solo debe contener letras y espacios")
    private String name;

    @NotBlank(message = "El teléfono es obligatorio")
    @Pattern(regexp = "^(0414|0424|0416|0426|0412)-?\\d{7}$",
            message = "Teléfono inválido. Formato: 0414-1234567 o 04141234567")
    private String phone;

    @NotBlank(message = "El parentesco es obligatorio")
    @Pattern(regexp = "^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\\s]+$",
            message = "El parentesco solo debe contener letras y espacios")
    private String relationship;

    public Integer getDriverId() { return driverId; }
    public void setDriverId(Integer driverId) { this.driverId = driverId; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getPhone() { return phone; }
    public void setPhone(String phone) { this.phone = phone; }

    public String getRelationship() { return relationship; }
    public void setRelationship(String relationship) { this.relationship = relationship; }
}
