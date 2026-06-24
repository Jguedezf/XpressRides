/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Catálogos Base
 *  Descripción: Repositorio de bancos — acceso directo a la
 *               tabla 'banco' en MySQL mediante Spring Data JPA
 *  Versión:     1.0.0
 *  Fecha:       22/06/2026  17:40
 * ============================================================
 */
package com.xpressrides.backend.repository;

import com.xpressrides.backend.model.Bank;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;


public interface BankRepository extends JpaRepository<Bank, Integer> {

    // Buscar bancos activos solamente
    List<Bank> findByActiveTrue();
}