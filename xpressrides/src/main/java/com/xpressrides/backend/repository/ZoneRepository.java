/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Catálogos Base
 *  Descripción: Repositorio de zonas — acceso directo a la
 *               tabla 'zona' en MySQL mediante Spring Data JPA
 *  Versión:     1.1.0
 *  Fecha:       24/06/2026
 * ============================================================
 */
package com.xpressrides.backend.repository;

import com.xpressrides.backend.model.Zone;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

@Repository
public interface ZoneRepository extends JpaRepository<Zone, Integer> {

    // Buscar zonas activas solamente
    List<Zone> findByActiveTrue();
}
