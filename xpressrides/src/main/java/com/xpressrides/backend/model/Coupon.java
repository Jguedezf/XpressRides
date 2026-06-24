package com.xpressrides.backend.model;

import java.math.BigDecimal;
import java.time.LocalDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "cupon")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class Coupon {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(name = "codigo")
    private String code;

    @Column(name = "tipo")
    private String type;

    @Column(name = "descuento_usd")
    private BigDecimal discountUsd;

    @Column(name = "distancia_max_km")
    private Integer maxDistanceKm;

    @Column(name = "activo")
    private Boolean active;

    @Column(name = "creado_en")
    private LocalDateTime createdAt;
}
