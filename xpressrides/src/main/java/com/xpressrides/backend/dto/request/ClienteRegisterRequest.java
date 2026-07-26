package com.xpressrides.backend.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public class ClienteRegisterRequest {

    @NotBlank(message = "El nombre es obligatorio")
    @Pattern(regexp = "^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\\s]+$",
            message = "El nombre solo debe contener letras y espacios")
    private String nombre;

    @NotBlank(message = "El apellido es obligatorio")
    @Pattern(regexp = "^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\\s]+$",
            message = "El apellido solo debe contener letras y espacios")
    private String apellido;

    @NotBlank(message = "El usuario es obligatorio")
    @Pattern(regexp = "^[a-zA-Z0-9_]{4,20}$",
            message = "El usuario debe tener entre 4 y 20 caracteres y solo puede contener letras, números y guiones bajos")
    private String username;

    @NotBlank(message = "La cédula es obligatoria")
    @Pattern(regexp = "^[VE]-\\d{6,8}$",
            message = "La cédula debe tener formato V-12345678 (máximo 8 dígitos)")
    private String cedula;

    @NotBlank(message = "El teléfono es obligatorio")
    @Pattern(regexp = "^(0414|0424|0416|0426|0412)-?\\d{7}$",
            message = "Teléfono inválido. Formato: 0414-1234567 o 04141234567")
    private String telefono;

    @NotBlank(message = "La contraseña es obligatoria")
    @Size(min = 8, message = "La contraseña debe tener al menos 8 caracteres")
    @Pattern(regexp = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)(?=.*[!@#$%^&*()_+\\-=\\[\\]{};':\"\\\\|,.<>/?`~]).{8,}$",
            message = "La contraseña debe contener al menos una mayúscula, una minúscula, un número y un carácter especial")
    private String password;

    private Boolean esEstudiante;

    public ClienteRegisterRequest() {}

    public String getNombre() { return nombre; }
    public void setNombre(String nombre) { this.nombre = nombre; }

    public String getApellido() { return apellido; }
    public void setApellido(String apellido) { this.apellido = apellido; }

    public String getUsername() { return username; }
    public void setUsername(String username) { this.username = username; }

    public String getCedula() { return cedula; }
    public void setCedula(String cedula) { this.cedula = cedula; }

    public String getTelefono() { return telefono; }
    public void setTelefono(String telefono) { this.telefono = telefono; }

    public String getPassword() { return password; }
    public void setPassword(String password) { this.password = password; }

    public Boolean getEsEstudiante() { return esEstudiante; }
    public void setEsEstudiante(Boolean esEstudiante) { this.esEstudiante = esEstudiante; }
}
