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
import java.util.Optional;

@Repository
public interface VehicleRepository extends JpaRepository<Vehicle, Integer> {

    // Retorna el vehículo registrado de un chofer específico
    Optional<Vehicle> findByDriver_Id(Integer driverId);

    // Verifica si una placa ya existe — evita duplicados en el registro
    boolean existsByPlate(String plate);
}
