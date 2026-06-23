/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Tasa BCV
 *  Descripción: Repositorio de tasa BCV — acceso directo a la
 *               tabla 'tasa_bcv' en MySQL mediante Spring Data JPA
 *  Versión:     1.0.0
 *  Fecha:       22/06/2026  HH:MM
 * ============================================================
 */
package com.xpressrides.backend.repository;

import com.xpressrides.backend.model.TasaBcv;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;
import java.util.Optional;

@Repository
public interface TasaBcvRepository extends JpaRepository<TasaBcv, Integer> {

    // Obtiene la tasa vigente más reciente — igual que la vista v_tasa_vigente
    @Query("SELECT t FROM TasaBcv t WHERE t.fechaVigencia <= CURRENT_DATE ORDER BY t.fechaVigencia DESC")
    Optional<TasaBcv> findTasaVigente();
}