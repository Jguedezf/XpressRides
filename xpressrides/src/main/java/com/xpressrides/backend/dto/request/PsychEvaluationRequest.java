package com.xpressrides.backend.dto.request;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.time.LocalDate;

public class PsychEvaluationRequest {

    @NotNull
    private Integer driverId;

    @NotNull
    private Integer adminId;

    @NotNull
    @DecimalMin("0") @DecimalMax("100")
    private BigDecimal score;

    @NotNull
    private LocalDate evaluationDate;

    private String observation;

    public Integer getDriverId() { return driverId; }
    public void setDriverId(Integer driverId) { this.driverId = driverId; }

    public Integer getAdminId() { return adminId; }
    public void setAdminId(Integer adminId) { this.adminId = adminId; }

    public BigDecimal getScore() { return score; }
    public void setScore(BigDecimal score) { this.score = score; }

    public LocalDate getEvaluationDate() { return evaluationDate; }
    public void setEvaluationDate(LocalDate evaluationDate) { this.evaluationDate = evaluationDate; }

    public String getObservation() { return observation; }
    public void setObservation(String observation) { this.observation = observation; }
}
