/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Personal Administrativo
 *  Descripción: Repositorio de personal admin — acceso directo a
 *               la tabla 'personal_admin' en MySQL
 *  Versión:     1.0.0
 *  Fecha:       24/06/2026
 * ============================================================
 */
package com.xpressrides.backend.repository;

import com.xpressrides.backend.model.AdminPersonnel;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface AdminPersonnelRepository extends JpaRepository<AdminPersonnel, Integer> {
}
