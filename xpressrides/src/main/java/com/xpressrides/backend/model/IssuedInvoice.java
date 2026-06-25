/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Reportes — Vistas SQL
 *  Descripción: Mapeo de la vista 'v_facturas_emitidas' —
 *               facturas fiscales generadas por traslados completados
 *  Versión:     1.1.0
 *  Fecha:       24/06/2026
 * ============================================================
 */
package com.xpressrides.backend.model;

import jakarta.persistence.*;
import lombok.Data;
import org.hibernate.annotations.Immutable;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@Entity
@Immutable
@Table(name = "v_facturas_emitidas")
public class IssuedInvoice {

    @Id
    @Column(name = "id")
    private Integer id;

    @Column(name = "nro_documento")
    private String documentNumber;

    @Column(name = "nro_control")
    private String controlNumber;

    @Column(name = "serie")
    private String series;

    @Column(name = "fecha_emision")
    private LocalDateTime issueDate;

    @Column(name = "razon_social")
    private String businessName;

    @Column(name = "rif_cedula")
    private String taxId;

    @Column(name = "monto_usd")
    private BigDecimal amountUsd;

    @Column(name = "monto_ves")
    private BigDecimal amountVes;

    @Column(name = "igtf_monto_usd")
    private BigDecimal igtfAmountUsd;

    @Column(name = "zona_origen")
    private String originZone;

    @Column(name = "zona_destino")
    private String destinationZone;
}
