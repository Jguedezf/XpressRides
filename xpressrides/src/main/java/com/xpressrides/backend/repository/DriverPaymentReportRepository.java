/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Reportes — Vistas SQL
 *  Descripción: Repositorio de pagos por chofer — lectura
 *               de la vista 'v_pagos_por_chofer'
 *  Versión:     1.1.0
 *  Fecha:       24/06/2026
 * ============================================================
 */
package com.xpressrides.backend.repository;

import com.xpressrides.backend.model.DriverPaymentReport;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.time.LocalDateTime;
import java.util.List;

@Repository
public interface DriverPaymentReportRepository extends JpaRepository<DriverPaymentReport, Integer> {

    @Query("SELECT d FROM DriverPaymentReport d WHERE " +
           "(:nombre IS NULL OR :nombre = '' OR LOWER(d.driverName) LIKE LOWER(CONCAT('%', :nombre, '%'))) AND " +
           "(cast(:desde as timestamp) IS NULL OR d.dateTime >= :desde) AND " +
           "(cast(:hasta as timestamp) IS NULL OR d.dateTime <= :hasta) " +
           "ORDER BY d.dateTime DESC")
    List<DriverPaymentReport> findByFilters(@Param("nombre") String nombre,
                                            @Param("desde") LocalDateTime desde,
                                            @Param("hasta") LocalDateTime hasta);
}
