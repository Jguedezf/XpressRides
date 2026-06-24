package com.xpressrides.backend.model;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "revision_vehiculo")
@Data
@AllArgsConstructor
@NoArgsConstructor
public class VehicleInspection {

    @Id
    @GeneratedValue(strategy = jakarta.persistence.GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne
    @JoinColumn(name = "id_vehiculo")
    private Vehicle vehicle;

    @ManyToOne
    @JoinColumn(name = "id_admin")
    private AdminPersonnel admin;

    @Column(name = "calificacion")
    private BigDecimal score;

    @Column(name = "fecha_revision")
    private LocalDate inspectionDate;

    @Column(name = "observacion")
    private String observation;

    @Column(name = "proxima_revision", insertable = false, updatable = false)
    private LocalDate nextInspectionDate;

    @Column(name = "proxima_revision", insertable = false, updatable = false)
    private boolean fitForUse;

    @Column(name = "creado_en")
    private LocalDateTime createdAt;

}
