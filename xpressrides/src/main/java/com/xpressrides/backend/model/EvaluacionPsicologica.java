package com.xpressrides.backend.model;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.Data;

@Entity
@Table(name = "evaluacion_psicologica")
@Data
public class EvaluacionPsicologica {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne
    @JoinColumn(name = "id_chofer")
    private Chofer driver;

    @ManyToOne
    @JoinColumn(name = "id_admin")
    private PersonalAdmin admin;

    @Column(name = "calificacion")
    private BigDecimal score;

    @Column(name = "fecha_eval")
    private LocalDate dateEval;

    @Column(name = "observacion")
    private String observation;

    @Column(name = "aprobado")
    private boolean approved;

    @Column(name = "creado_en")
    private LocalDateTime createdAt;

}
