package com.xpressrides.backend.dto;

import java.time.LocalDate;

public class PsychEvaluationStatus {
    private boolean approved;
    private LocalDate evaluationDate;
    private boolean valid;

    public boolean isApproved() { return approved; }
    public void setApproved(boolean approved) { this.approved = approved; }

    public LocalDate getEvaluationDate() { return evaluationDate; }
    public void setEvaluationDate(LocalDate evaluationDate) { this.evaluationDate = evaluationDate; }

    public boolean isValid() { return valid; }
    public void setValid(boolean valid) { this.valid = valid; }
}
