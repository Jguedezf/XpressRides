/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Vehículos
 *  Descripción: Repositorio de vehículos — acceso directo a la
 *               tabla 'vehiculo' en MySQL
 *  Versión:     1.0.0
 *  Fecha:       24/06/2026
 * ============================================================
 */
package com.xpressrides.backend.repository;

import com.xpressrides.backend.model.Vehicle;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.Optional;

@Repository
public interface VehicleRepository extends JpaRepository<Vehicle, Integer> {

    // Retorna todos los vehículos registrados de un chofer (puede tener varios)
    List<Vehicle> findByDriver_Id(Integer driverId);

    // Retorna el vehículo que el chofer está usando actualmente (a lo sumo uno,
    // garantizado por el índice único funcional uq_vehiculo_en_uso_por_chofer)
    Optional<Vehicle> findByDriver_IdAndInUseTrue(Integer driverId);

    // Verifica si una placa ya existe — evita duplicados en el registro
    boolean existsByPlate(String plate);
}
