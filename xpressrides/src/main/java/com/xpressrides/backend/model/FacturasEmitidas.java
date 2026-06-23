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
 *  Versión:     1.0.0
 *  Fecha:       22/06/2026  HH:MM
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
public class FacturasEmitidas {

    @Id
    @Column(name = "id")
    private Integer id;

    @Column(name = "nro_documento")
    private String nroDocumento;

    @Column(name = "nro_control")
    private String nroControl;

    @Column(name = "serie")
    private String serie;

    @Column(name = "fecha_emision")
    private LocalDateTime fechaEmision;

    @Column(name = "razon_social")
    private String razonSocial;

    @Column(name = "rif_cedula")
    private String rifCedula;

    @Column(name = "monto_usd")
    private BigDecimal montoUsd;

    @Column(name = "monto_ves")
    private BigDecimal montoVes;

    @Column(name = "igtf_monto_usd")
    private BigDecimal igtfMontoUsd;

    @Column(name = "zona_origen")
    private String zonaOrigen;

    @Column(name = "zona_destino")
    private String zonaDestino;
}