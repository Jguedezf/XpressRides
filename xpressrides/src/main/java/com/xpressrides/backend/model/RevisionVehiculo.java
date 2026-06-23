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
import lombok.Data;

@Entity
@Table(name = "revision_vehiculo")
@Data
public class RevisionVehiculo {

    @Id
    @GeneratedValue(strategy = jakarta.persistence.GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne
    @JoinColumn(name = "id_vehiculo")
    private Vehiculo vehicle;

    @ManyToOne
    @JoinColumn(name = "id_admin")
    private PersonalAdmin admin;

    @Column(name = "calificacion")
    private BigDecimal score;

    @Column(name = "fecha_revision")
    private LocalDate revisionDate;

    @Column(name = "observacion")
    private String observation;

    @Column(name = "proxima_revision")
    private LocalDate nextRevisionDate;

    @Column(name = "apto")
    private boolean fitForUse;

    @Column(name = "creado_en")
    private LocalDateTime createdAt;

}
