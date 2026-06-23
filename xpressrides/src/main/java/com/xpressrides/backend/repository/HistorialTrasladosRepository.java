/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Reportes — Vistas SQL
 *  Descripción: Repositorio de la vista 'v_historial_traslados'
 *  Versión:     1.0.0
 *  Fecha:       22/06/2026  HH:MM
 * ============================================================
 */
package com.xpressrides.backend.repository;

import com.xpressrides.backend.model.HistorialTraslados;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface HistorialTrasladosRepository
        extends JpaRepository<HistorialTraslados, Integer> {}