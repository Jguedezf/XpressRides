package com.xpressrides.backend.dto;

import java.time.LocalDate;

public class VehicleInspectionStatus {
    private boolean fitForUse;
    private LocalDate nextInspectionDate;
    private boolean valid;

    public boolean isFitForUse() { return fitForUse; }
    public void setFitForUse(boolean fitForUse) { this.fitForUse = fitForUse; }

    public LocalDate getNextInspectionDate() { return nextInspectionDate; }
    public void setNextInspectionDate(LocalDate nextInspectionDate) { this.nextInspectionDate = nextInspectionDate; }

    public boolean isValid() { return valid; }
    public void setValid(boolean valid) { this.valid = valid; }
}
