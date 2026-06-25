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
 *  Versión:     1.1.0
 *  Fecha:       24/06/2026
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
public class CancelledTrip {

    @Id
    @Column(name = "id")
    private Integer id;

    @Column(name = "cliente")
    private String customerName;

    @Column(name = "chofer")
    private String driverName;

    @Column(name = "zona_origen")
    private String originZone;

    @Column(name = "zona_destino")
    private String destinationZone;

    @Column(name = "cancelado_por")
    private String cancelledBy;

    @Column(name = "motivo_cancelacion")
    private String cancellationReason;

    @Column(name = "fecha_solicitud")
    private LocalDateTime requestDate;
}
