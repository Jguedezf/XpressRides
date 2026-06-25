package com.xpressrides.backend.dto.response;

import java.math.BigDecimal;
import java.time.LocalDate;

public class InspectionResponse {
    private Integer id;
    private Integer vehicleId;
    private Integer adminId;
    private BigDecimal score;
    private LocalDate inspectionDate;
    private String observation;
    private Boolean fitForUse;
    private LocalDate nextInspectionDate;
    
    public InspectionResponse() {
    }

    public InspectionResponse(Integer id, Integer vehicleId, Integer adminId, BigDecimal score,
            LocalDate inspectionDate, String observation, Boolean fitForUse, LocalDate nextInspectionDate) {
        this.id = id;
        this.vehicleId = vehicleId;
        this.adminId = adminId;
        this.score = score;
        this.inspectionDate = inspectionDate;
        this.observation = observation;
        this.fitForUse = fitForUse;
        this.nextInspectionDate = nextInspectionDate;
    }

    public Integer getId() {
        return id;
    }

    public void setId(Integer id) {
        this.id = id;
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

    public void setInspectionDate(LocalDate inspectionDate) {
        this.inspectionDate = inspectionDate;
    }

    public String getObservation() {
        return observation;
    }

    public void setObservation(String observation) {
        this.observation = observation;
    }

    public Boolean getFitForUse() {
        return fitForUse;
    }

    public void setFitForUse(Boolean fitForUse) {
        this.fitForUse = fitForUse;
    }

    public LocalDate getNextInspectionDate() {
        return nextInspectionDate;
    }

    public void setNextInspectionDate(LocalDate nextInspectionDate) {
        this.nextInspectionDate = nextInspectionDate;
    }

    
}
