package com.xpressrides.backend.dto;

import java.math.BigDecimal;
import java.time.LocalDate;

import lombok.Data;

@Data
public class VehicleInspectionDTO {
    private Integer id;
    private LocalDate inspectionDate;
    private BigDecimal score;
    private String observation;
    private Boolean fitForUse;
    private LocalDate nextInspectionDate;
}
