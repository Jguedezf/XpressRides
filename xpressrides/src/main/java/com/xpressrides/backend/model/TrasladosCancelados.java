/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Reportes — Vistas SQL
 *  Descripción: Mapeo de la vista 'v_traslados_cancelados' —
 *               listado de traslados cancelados con motivo
 *  Versión:     1.0.0
 *  Fecha:       22/06/2026  HH:MM
 * ============================================================
 */
package com.xpressrides.backend.model;

import jakarta.persistence.*;
import lombok.Data;
import org.hibernate.annotations.Immutable;
import java.time.LocalDateTime;

@Data
@Entity
@Immutable
@Table(name = "v_traslados_cancelados")
public class TrasladosCancelados {

    @Id
    @Column(name = "id")
    private Integer id;

    @Column(name = "cliente")
    private String cliente;

    @Column(name = "chofer")
    private String chofer;

    @Column(name = "zona_origen")
    private String zonaOrigen;

    @Column(name = "zona_destino")
    private String zonaDestino;

    @Column(name = "cancelado_por")
    private String canceladoPor;

    @Column(name = "motivo_cancelacion")
    private String motivoCancelacion;

    @Column(name = "fecha_solicitud")
    private LocalDateTime fechaSolicitud;
}