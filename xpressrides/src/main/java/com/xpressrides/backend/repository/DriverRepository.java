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
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

@Repository
public interface DriverRepository extends JpaRepository<Driver, Integer> {

    @Modifying
    @Query("UPDATE Driver d SET d.balance = d.balance - :amount WHERE d.id = :id")
    void subtractBalance(@Param("id") Integer id, @Param("amount") BigDecimal amount);

    // Busca choferes habilitados y disponibles para asignación de traslado
    List<Driver> findByEnabledTrueAndAvailableTrue();

    Optional<Driver> findByUsername_Username(String username);
}
