package com.xpressrides.backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public class VehicleRequest {
    @NotBlank String plate;
    @NotBlank String brand;
    @NotBlank String model;
    @NotNull Integer year;
    @NotBlank String color;
    @NotNull Integer driverId;

    public VehicleRequest(String plate, String brand, String model,
            Integer year, String color, Integer driverId) {
        this.plate = plate;
        this.brand = brand;
        this.model = model;
        this.year = year;
        this.color = color;
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



    public Integer getDriverId() {
        return driverId;
    }



    public void setDriverId(Integer driverId) {
        this.driverId = driverId;
    }

    
}
