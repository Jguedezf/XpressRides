package com.xpressrides.backend.dto.response;

import java.math.BigDecimal;
import java.time.LocalDate;

public class PsychEvaluationResponse {
    private Integer id;
    private Integer driverId;
    private Integer adminId;
    private BigDecimal score;
    private LocalDate evaluationDate;
    private String observation;
    private boolean approved;

    public Integer getId() { return id; }
    public void setId(Integer id) { this.id = id; }

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

    public boolean isApproved() { return approved; }
    public void setApproved(boolean approved) { this.approved = approved; }
}
