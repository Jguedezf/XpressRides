/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Choferes
 *  Descripción: Repositorio de choferes — acceso directo a la
 *               tabla 'chofer' en MySQL
 *  Versión:     1.0.0
 *  Fecha:       24/06/2026
 * ============================================================
 */
package com.xpressrides.backend.repository;

import com.xpressrides.backend.model.Driver;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;

@Repository
public interface DriverRepository extends JpaRepository<Driver, Integer> {

    // Busca choferes habilitados y disponibles para asignación de traslado
    List<Driver> findByEnabledTrueAndAvailableTrue();
}
