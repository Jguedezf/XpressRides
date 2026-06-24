package com.xpressrides.backend.dto;

public class TripResponse {
    private boolean success;
    private Integer tripId;
    private String message;

    public TripResponse() {
    }

    public TripResponse(boolean success, Integer tripId, String message) {
        this.success = success;
        this.tripId = tripId;
        this.message = message;
    }
    public boolean isSuccess() {
        return success;
    }
    public void setSuccess(boolean success) {
        this.success = success;
    }
    public Integer getTripId() {
        return tripId;
    }
    public void setTripId(Integer tripId) {
        this.tripId = tripId;
    }
    public String getMessage() {
        return message;
    }
    public void setMessage(String message) {
        this.message = message;
    }

    
}
