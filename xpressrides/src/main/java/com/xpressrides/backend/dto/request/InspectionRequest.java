package com.xpressrides.backend.dto.request;

import java.math.BigDecimal;
import java.time.LocalDate;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public class InspectionRequest {
    @NotNull Integer vehicleId;
    @NotNull Integer adminId;
    @NotNull BigDecimal score;
    @NotNull LocalDate inspectionDate;
    @NotBlank String observation;
    
    public InspectionRequest(@NotBlank Integer vehicleId, @NotBlank Integer adminId, @NotNull BigDecimal score, @NotNull LocalDate inspectionDate, @NotNull String observation) {
        this.vehicleId = vehicleId;
        this.adminId = adminId;
        this.score = score;
        this.inspectionDate = inspectionDate;
        this.observation = observation;
    }

    public Integer getVehicleId() {
        return vehicleId;
    }

    public void setVehicleId(Integer vehicleId) {
        this.vehicleId = vehicleId;
    }

    public Integer getAdminId() {
        return adminId;
    }

    public void setAdminId(Integer adminId) {
        this.adminId = adminId;
    }

    public BigDecimal getScore() {
        return score;
    }

    public void setScore(BigDecimal score) {
        this.score = score;
    }

    public LocalDate getInspectionDate() {
        return inspectionDate;
    }

    public void setInspectionDate(LocalDate inspectDate) {
        this.inspectionDate = inspectDate;
    }

    public String getObservation() {
        return observation;
    }

    public void setObservation(String observation) {
        this.observation = observation;
    }

    
}
