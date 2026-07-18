package com.xpressrides.backend.dto.response;

import com.xpressrides.backend.dto.VehicleInspectionDTO;

public class VehicleResponse {
    private Integer id;
    private Integer driverId;
    private String plate;
    private String brand;
    private String model;
    private Integer year;
    private String color;
    private Boolean active;
    private Boolean inUse;
    private VehicleInspectionDTO lastInspection;

    public VehicleResponse() {
    }
    
    public VehicleResponse(Integer id, Integer driverId, String plate, String brand, String model, Integer year, String color, Boolean active, VehicleInspectionDTO lastInspection) {
        this.id = id;
        this.driverId = driverId;
        this.plate = plate;
        this.brand = brand;
        this.model = model;
        this.year = year;
        this.color = color;
        this.active = active;
        this.lastInspection = lastInspection;
    }
    public Integer getId() {
        return id;
    }
    public void setId(Integer id) {
        this.id = id;
    }
    public Integer getDriverId() {
        return driverId;
    }
    public void setDriverId(Integer driverId) {
        this.driverId = driverId;
    }
    public String getPlate() {
        return plate;
    }
    public void setPlate(String plate) {
        this.plate = plate;
    }
    public String getBrand() {
        return brand;
    }
    public void setBrand(String brand) {
        this.brand = brand;
    }
    public String getModel() {
        return model;
    }
    public void setModel(String model) {
        this.model = model;
    }
    public Integer getYear() {
        return year;
    }
    public void setYear(Integer year) {
        this.year = year;
    }
    public String getColor() {
        return color;
    }
    public void setColor(String color) {
        this.color = color;
    }
    public Boolean getActive() {
        return active;
    }
    public void setActive(Boolean active) {
        this.active = active;
    }
    public Boolean getInUse() {
        return inUse;
    }
    public void setInUse(Boolean inUse) {
        this.inUse = inUse;
    }
    public VehicleInspectionDTO getLastInspection() {
        return lastInspection;
    }
    public void setLastInspection(VehicleInspectionDTO lastInspection) {
        this.lastInspection = lastInspection;
    }

    
}
