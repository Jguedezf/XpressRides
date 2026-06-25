package com.xpressrides.backend.dto.response;

import com.xpressrides.backend.dto.PsychEvaluationStatus;
import com.xpressrides.backend.dto.VehicleInspectionStatus;

public class DriverStatusResponse {
    private Integer driverId;
    private boolean enabled;
    private boolean available;
    private PsychEvaluationStatus psychEvaluation;
    private VehicleInspectionStatus vehicleInspection;
    private boolean qualified;

    public Integer getDriverId() { return driverId; }
    public void setDriverId(Integer driverId) { this.driverId = driverId; }

    public boolean isEnabled() { return enabled; }
    public void setEnabled(boolean enabled) { this.enabled = enabled; }

    public boolean isAvailable() { return available; }
    public void setAvailable(boolean available) { this.available = available; }

    public PsychEvaluationStatus getPsychEvaluation() { return psychEvaluation; }
    public void setPsychEvaluation(PsychEvaluationStatus psychEvaluation) { this.psychEvaluation = psychEvaluation; }

    public VehicleInspectionStatus getVehicleInspection() { return vehicleInspection; }
    public void setVehicleInspection(VehicleInspectionStatus vehicleInspection) { this.vehicleInspection = vehicleInspection; }

    public boolean isQualified() { return qualified; }
    public void setQualified(boolean qualified) { this.qualified = qualified; }
}
