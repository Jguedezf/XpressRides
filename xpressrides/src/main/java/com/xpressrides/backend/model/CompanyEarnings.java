/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Reportes — Vistas SQL
 *  Descripción: Mapeo de la vista 'v_ganancias_empresa' —
 *               ganancias diarias de la empresa por viajes completados
 *  Versión:     1.1.0
 *  Fecha:       24/06/2026
 * ============================================================
 */
package com.xpressrides.backend.model;

import jakarta.persistence.*;
import lombok.Data;
import org.hibernate.annotations.Immutable;
import java.math.BigDecimal;
import java.time.LocalDate;

@Data
@Entity
@Immutable
@Table(name = "v_ganancias_empresa")
public class CompanyEarnings {

    @Id
    @Column(name = "fecha")
    private LocalDate date;

    @Column(name = "cantidad_viajes")
    private Integer tripCount;

    @Column(name = "total_empresa_usd")
    private BigDecimal totalCompanyUsd;

    @Column(name = "total_empresa_ves")
    private BigDecimal totalCompanyVes;
}
