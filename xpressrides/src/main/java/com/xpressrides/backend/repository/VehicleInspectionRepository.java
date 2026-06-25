/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Habilitación de Choferes
 *  Descripción: Repositorio de revisiones vehiculares — acceso
 *               directo a la tabla 'revision_vehiculo' en MySQL
 *  Versión:     1.0.0
 *  Fecha:       24/06/2026
 * ============================================================
 */
package com.xpressrides.backend.repository;

import com.xpressrides.backend.model.VehicleInspection;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.Optional;

@Repository
public interface VehicleInspectionRepository extends JpaRepository<VehicleInspection, Integer> {

    // Retorna la revisión vehicular más reciente de un vehículo —
    // usada para verificar si el vehículo está apto antes de habilitar al chofer
    Optional<VehicleInspection> findFirstByVehicle_IdOrderByInspectionDateDesc(Integer vehicleId);
}
