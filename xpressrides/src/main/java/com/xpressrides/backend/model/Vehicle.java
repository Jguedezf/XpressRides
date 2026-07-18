/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Vehículos
 *  Descripción: Mapeo de la tabla 'vehiculo' — datos del vehículo
 *               asignado al chofer: placa, marca, modelo, color
 *  Versión:     1.0.0
 *  Fecha:       24/06/2026
 * ============================================================
 */
package com.xpressrides.backend.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.time.LocalDateTime;

@Data
@Entity
@NoArgsConstructor
@AllArgsConstructor
@Table(name = "vehiculo")
public class Vehicle {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne
    @JoinColumn(name = "id_chofer")
    private Driver driver;

    @Column(name = "placa")
    private String plate;

    @Column(name = "marca")
    private String brand;

    @Column(name = "modelo")
    private String model;

    @Column(name = "anio_fabricacion")
    private Integer year;

    @Column(name = "color")
    private String color;

    @Column(name = "activo")
    private Boolean active;

    @Column(name = "en_uso")
    private Boolean inUse;

    @Column(name = "creado_en", insertable = false, updatable = false)
    private LocalDateTime createdAt;

    @com.fasterxml.jackson.annotation.JsonIgnore
    @OneToMany(mappedBy = "vehicle")
    private java.util.List<VehicleInspection> inspections;
}
