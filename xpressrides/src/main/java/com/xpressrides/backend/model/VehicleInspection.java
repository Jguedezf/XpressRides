/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Habilitación de Choferes
 *  Descripción: Mapeo de la tabla 'revision_vehiculo' —
 *               calificación mínima aprobatoria: 65/100.
 *               'apto' y 'proxima_revision' son columnas generadas
 *               por MySQL — no se escriben desde Java.
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
@Table(name = "revision_vehiculo")
public class VehicleInspection {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
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

    // Columna generada en MySQL: apto = (calificacion >= 65)
    // No se escribe desde Java — MySQL la calcula automáticamente
    @Column(name = "apto", insertable = false, updatable = false)
    private boolean fitForUse;

    // Columna generada en MySQL: proxima_revision = fecha_revision + 1 año
    // No se escribe desde Java — MySQL la calcula automáticamente
    @Column(name = "proxima_revision", insertable = false, updatable = false)
    private LocalDate nextInspectionDate;

    @Column(name = "creado_en", insertable = false, updatable = false)
    private LocalDateTime createdAt;
}
