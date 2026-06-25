/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Facturación
 *  Descripción: Repositorio de facturas — consulta combinada con
 *               traslado y tasa BCV para obtener todos los campos
 *               requeridos por el frontend en un solo query
 *  Versión:     1.0.0
 *  Fecha:       24/06/2026
 * ============================================================
 */
package com.xpressrides.backend.repository;

import com.xpressrides.backend.model.Invoice;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface InvoiceRepository extends JpaRepository<Invoice, Integer> {

    // Busca la factura por id_traslado con todos los datos financieros del viaje
    @Query(value = """
            SELECT
              f.id               AS facturaId,
              f.nro_documento    AS numeroDocumento,
              f.nro_control      AS control,
              f.serie            AS serie,
              DATE(f.fecha_emision) AS fechaEmision,
              TIME(f.fecha_emision) AS horaEmision,
              f.razon_social     AS clienteNombre,
              f.rif_cedula       AS clienteCedula,
              f.direccion_fiscal AS clienteDireccion,
              t.costo_cliente_usd AS costoUsd,
              tb.tasa_ves        AS tasaVes,
              f.igtf_monto_usd   AS montoIgtfUsd
            FROM factura f
            JOIN traslado t  ON f.id_traslado = t.id
            JOIN tasa_bcv tb ON t.id_tasa = tb.id
            WHERE f.id_traslado = :trasladoId
            """, nativeQuery = true)
    List<Object[]> findInvoiceDataByTripId(@Param("trasladoId") Integer trasladoId);
}
