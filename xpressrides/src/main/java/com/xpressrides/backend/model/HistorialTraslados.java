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
@Table(name = "v_historial_traslados")
public class HistorialTraslados {

    @Id
    @Column(name = "id")
    private Integer id;

    @Column(name = "id_cliente")
    private Integer idCliente;

    @Column(name = "cliente")
    private String cliente;

    @Column(name = "chofer")
    private String chofer;

    @Column(name = "placa")
    private String placa;

    @Column(name = "marca")
    private String marca;

    @Column(name = "modelo")
    private String modelo;

    @Column(name = "color")
    private String color;

    @Column(name = "zona_origen")
    private String zonaOrigen;

    @Column(name = "zona_destino")
    private String zonaDestino;

    @Column(name = "nro_pasajeros")
    private Integer nroPasajeros;

    @Column(name = "distancia_km")
    private BigDecimal distanciaKm;

    @Column(name = "costo_cliente_usd")
    private BigDecimal costoClienteUsd;

    @Column(name = "costo_cliente_ves")
    private BigDecimal costoClienteVes;

    @Column(name = "estado")
    private String estado;

    @Column(name = "cancelado_por")
    private String canceladoPor;

    @Column(name = "calificacion_estrellas")
    private Integer calificacionEstrellas;

    @Column(name = "eta_minutos")
    private Integer etaMinutos;

    @Column(name = "duracion_minutos")
    private Integer duracionMinutos;

    @Column(name = "fecha_solicitud")
    private LocalDateTime fechaSolicitud;

    @Column(name = "fecha_fin")
    private LocalDateTime fechaFin;
}