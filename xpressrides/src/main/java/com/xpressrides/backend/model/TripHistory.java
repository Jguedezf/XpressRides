/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Reportes — Vistas SQL
 *  Descripción: Mapeo de la vista 'v_historial_traslados' —
 *               historial completo de viajes realizados
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
@Table(name = "v_historial_traslados")
public class TripHistory {

    @Id
    @Column(name = "id")
    private Integer id;

    @Column(name = "id_cliente")
    private Integer customerId;

    @Column(name = "cliente")
    private String customerName;

    @Column(name = "chofer")
    private String driverName;

    @Column(name = "placa")
    private String licensePlate;

    @Column(name = "marca")
    private String brand;

    @Column(name = "modelo")
    private String vehicleModel;

    @Column(name = "color")
    private String color;

    @Column(name = "zona_origen")
    private String originZone;

    @Column(name = "zona_destino")
    private String destinationZone;

    @Column(name = "nro_pasajeros")
    private Integer passengerCount;

    @Column(name = "distancia_km")
    private BigDecimal distanceKm;

    @Column(name = "costo_cliente_usd")
    private BigDecimal customerCostUsd;

    @Column(name = "costo_cliente_ves")
    private BigDecimal customerCostVes;

    @Column(name = "estado")
    private String status;

    @Column(name = "cancelado_por")
    private String cancelledBy;

    @Column(name = "calificacion_estrellas")
    private Integer starRating;

    @Column(name = "eta_minutos")
    private Integer etaMinutes;

    @Column(name = "duracion_minutos")
    private Integer durationMinutes;

    @Column(name = "fecha_solicitud")
    private LocalDateTime requestDate;

    @Column(name = "fecha_fin")
    private LocalDateTime endDate;
}
