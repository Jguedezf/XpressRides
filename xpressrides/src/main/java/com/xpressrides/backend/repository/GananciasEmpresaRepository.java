/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Reportes — Vistas SQL
 *  Descripción: Repositorio de solo lectura para
 *               la vista 'v_ganancias_empresa'
 *  Versión:     1.0.0
 *  Fecha:       22/06/2026  HH:MM
 * ============================================================
 */
package com.xpressrides.backend.repository;

import com.xpressrides.backend.model.GananciasEmpresa;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.time.LocalDate;

@Repository
public interface GananciasEmpresaRepository
        extends JpaRepository<GananciasEmpresa, LocalDate> {}