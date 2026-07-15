/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Catálogos Base
 *  Descripción: Entidad que representa la tabla 'banco' —
 *               catálogo de entidades bancarias registradas
 *  Versión:     1.1.0
 *  Fecha:       24/06/2026
 * ============================================================
 */
package com.xpressrides.backend.model;

import jakarta.persistence.*;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@Entity
@Table(name = "banco")
public class Bank {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(name = "nombre", nullable = false, length = 100)
    private String name;

    @Column(name = "codigo_bcv", nullable = false, unique = true, length = 10)
    private String bcvCode;

    @Column(name = "activo", nullable = false)
    private Boolean active;

    @Column(name = "acepta_usd", nullable = false)
    private Boolean acceptsUsd;

    @Column(name = "acepta_ves", nullable = false)
    private Boolean acceptsVes;

    @Column(name = "creado_en", nullable = false, updatable = false)
    private LocalDateTime createdAt;
}
