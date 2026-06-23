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
 *  Versión:     1.0.0
 *  Fecha:       23/06/2026  HH:MM
 * ============================================================
 */
package com.xpressrides.backend.repository;

import com.xpressrides.backend.model.PagoChofer;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;

@Repository
public interface PagoChoferRepository
        extends JpaRepository<PagoChofer, Integer> {

    // Buscar todos los pagos realizados a un chofer específico
    List<PagoChofer> findByIdChoferOrderByFechaHoraDesc(Integer idChofer);
}