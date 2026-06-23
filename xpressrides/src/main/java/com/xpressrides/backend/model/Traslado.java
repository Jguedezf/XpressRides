package com.xpressrides.backend.model;

import java.math.BigDecimal;
import java.time.LocalDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "traslado")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class Traslado {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne
    @JoinColumn(name = "id_cliente")
    private Cliente customer;

    @ManyToOne
    @JoinColumn(name = "id_chofer")
    private Chofer driver;

    @ManyToOne
    @JoinColumn(name = "id_vehiculo")
    private Vehiculo vehicle;

    @ManyToOne
    @JoinColumn(name = "id_zona_origen")
    private Zona originZone;

    @ManyToOne
    @JoinColumn(name = "id_zona_destino")
    private Zona destinationZone;

    @ManyToOne
    @JoinColumn(name = "id_tasa")
    private TasaBcv rate;

    @ManyToOne
    @JoinColumn(name = "id_cupon_cliente")
    private CuponCliente customerCoupon;

    @Column(name = "nro_pasajeros")
    private Integer passengerCount;

    @Column(name = "distancia_km")
    private BigDecimal distanceKm;

    @Column(name = "tarifa_base_usd")
    private BigDecimal baseFareUsd;

    @Column(name = "recargo_horario_usd")
    private BigDecimal timeSurchargeUsd;

    @Column(name = "factor_hora_pico")
    private BigDecimal peakHourFactor;

    @Column(name = "descuento_usd")
    private BigDecimal discountUsd;

    @Column(name = "costo_cliente_usd")
    private BigDecimal customerCostUsd;

    @Column(name = "monto_chofer_usd")
    private BigDecimal driverAmountUsd;

    @Column(name = "monto_empresa_usd")
    private BigDecimal companyAmountUsd;

    @Column(name = "costo_cliente_ves")
    private BigDecimal customerCostVes;

    @Column(name = "estado")
    private String status;

    @Column(name = "cancelado_por")
    private String cancelledBy;

    @Column(name = "motivo_cancelacion")
    private String cancellationReason;

    @Column(name = "calificacion_estrellas")
    private Integer starRating;

    @Column(name = "comentario_cliente")
    private String customerComment;

    @Column(name = "intentos_asignacion")
    private Integer assignmentAttempts;

    @Column(name = "eta_minutos")
    private Integer etaMinutes;

    @Column(name = "fecha_solicitud")
    private LocalDateTime requestDate;

    @Column(name = "fecha_aceptacion")
    private LocalDateTime acceptanceDate;

    @Column(name = "fecha_inicio")
    private LocalDateTime startDate;

    @Column(name = "fecha_fin")
    private LocalDateTime endDate;

    @Column(name = "duracion_minutos")
    private Integer durationMinutes;

}
