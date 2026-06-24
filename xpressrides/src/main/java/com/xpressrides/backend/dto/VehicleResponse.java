package com.xpressrides.backend.dto;

import lombok.Data;

@Data
public class VehicleResponse {
    private Integer id;
    private Integer driverId;
    private String plate;
    private String brand;
    private String model;
    private Integer year;
    private String color;
    private Boolean active;
    private VehicleInspectionDTO lastInspection;
}
