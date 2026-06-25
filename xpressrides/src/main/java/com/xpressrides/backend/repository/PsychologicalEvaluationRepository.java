/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Habilitación de Choferes
 *  Descripción: Repositorio de evaluaciones psicológicas — acceso
 *               directo a la tabla 'evaluacion_psicologica' en MySQL
 *  Versión:     1.0.0
 *  Fecha:       24/06/2026
 * ============================================================
 */
package com.xpressrides.backend.repository;

import com.xpressrides.backend.model.PsychologicalEvaluation;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.Optional;

@Repository
public interface PsychologicalEvaluationRepository extends JpaRepository<PsychologicalEvaluation, Integer> {

    // Verifica si el chofer tiene al menos una evaluación psicológica aprobada —
    // usada por el servicio de habilitación para activar chofer.habilitado
    boolean existsByDriver_IdAndApprovedTrue(Integer driverId);

    Optional<PsychologicalEvaluation> findFirstByDriver_IdOrderByEvaluationDateDesc(Integer driverId);
}
