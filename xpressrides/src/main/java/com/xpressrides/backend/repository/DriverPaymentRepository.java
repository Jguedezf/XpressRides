/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Pagos y Facturación
 *  Descripción: Repositorio de pagos a choferes — acceso directo
 *               a la tabla 'pago_chofer' en MySQL
 *  Versión:     1.1.0
 *  Fecha:       24/06/2026
 * ============================================================
 */
package com.xpressrides.backend.repository;

import com.xpressrides.backend.model.DriverPayment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.time.LocalDateTime;
import java.util.List;

@Repository
public interface DriverPaymentRepository extends JpaRepository<DriverPayment, Integer> {

    // Buscar todos los pagos realizados a un chofer específico
    List<DriverPayment> findByDriver_IdOrderByDateTimeDesc(Integer driverId);

    // Pagos a un chofer en un rango de fechas
    List<DriverPayment> findByDriver_IdAndDateTimeBetweenOrderByDateTimeDesc(
            Integer driverId, LocalDateTime desde, LocalDateTime hasta);
}
