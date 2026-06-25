/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Habilitación de Choferes
 *  Descripción: Mapeo de la tabla 'evaluacion_psicologica' —
 *               calificación mínima aprobatoria: 73/100.
 *               'aprobado' es columna generada por MySQL.
 *  Versión:     1.0.0
 *  Fecha:       24/06/2026
 * ============================================================
 */
package com.xpressrides.backend.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Data
@Entity
@NoArgsConstructor
@AllArgsConstructor
@Table(name = "evaluacion_psicologica")
public class PsychologicalEvaluation {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne
    @JoinColumn(name = "id_chofer")
    private Driver driver;

    @ManyToOne
    @JoinColumn(name = "id_admin")
    private AdminPersonnel admin;

    @Column(name = "calificacion")
    private BigDecimal score;

    @Column(name = "fecha_eval")
    private LocalDate evaluationDate;

    @Column(name = "observacion")
    private String observation;

    // Columna generada en MySQL: aprobado = (calificacion >= 73)
    // No se escribe desde Java — MySQL la calcula automáticamente
    @Column(name = "aprobado", insertable = false, updatable = false)
    private boolean approved;

    @Column(name = "creado_en", insertable = false, updatable = false)
    private LocalDateTime createdAt;
}
