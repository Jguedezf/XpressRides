package com.xpressrides.backend.dto.response;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

public class CustomerProfileResponse {
    private Integer id;
    private String ci;
    private String name;
    private String lastName;
    private String username;
    private String email;
    private String phone;
    private BigDecimal balance;
    private boolean isStudent;
    private boolean firstTripUsed;

    // Sistema de referidos — ver CustomerService.mapToProfileResponse
    private String codigoReferido;
    private int cuponesDisponibles;
    private List<Map<String, Object>> historialCuponesUsados;
    private boolean puedeAgregarReferido;
    // null si puedeAgregarReferido es false (ya tiene código o venció el plazo)
    private Double horasRestantesReferido;

    public Integer getId() { return id; }
    public void setId(Integer id) { this.id = id; }

    public String getCi() { return ci; }
    public void setCi(String ci) { this.ci = ci; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getLastName() { return lastName; }
    public void setLastName(String lastName) { this.lastName = lastName; }

    public String getUsername() { return username; }
    public void setUsername(String username) { this.username = username; }

    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }

    public String getPhone() { return phone; }
    public void setPhone(String phone) { this.phone = phone; }

    public BigDecimal getBalance() { return balance; }
    public void setBalance(BigDecimal balance) { this.balance = balance; }

    public boolean isStudent() { return isStudent; }
    public void setStudent(boolean isStudent) { this.isStudent = isStudent; }

    public boolean isFirstTripUsed() { return firstTripUsed; }
    public void setFirstTripUsed(boolean firstTripUsed) { this.firstTripUsed = firstTripUsed; }

    public String getCodigoReferido() { return codigoReferido; }
    public void setCodigoReferido(String codigoReferido) { this.codigoReferido = codigoReferido; }

    public int getCuponesDisponibles() { return cuponesDisponibles; }
    public void setCuponesDisponibles(int cuponesDisponibles) { this.cuponesDisponibles = cuponesDisponibles; }

    public List<Map<String, Object>> getHistorialCuponesUsados() { return historialCuponesUsados; }
    public void setHistorialCuponesUsados(List<Map<String, Object>> historialCuponesUsados) { this.historialCuponesUsados = historialCuponesUsados; }

    public boolean isPuedeAgregarReferido() { return puedeAgregarReferido; }
    public void setPuedeAgregarReferido(boolean puedeAgregarReferido) { this.puedeAgregarReferido = puedeAgregarReferido; }

    public Double getHorasRestantesReferido() { return horasRestantesReferido; }
    public void setHorasRestantesReferido(Double horasRestantesReferido) { this.horasRestantesReferido = horasRestantesReferido; }
}
