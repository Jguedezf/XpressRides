package com.xpressrides.backend.model;

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
import com.fasterxml.jackson.annotation.JsonIgnore;

@Entity
@Table(name = "cupon_cliente")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class CustomerCoupon {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne
    @JoinColumn(name = "id_cupon")
    private Coupon coupon;

    @JsonIgnore
    @ManyToOne
    @JoinColumn(name = "id_cliente")
    private Customer customer;

    @Column(name = "usado")
    private Boolean used;

    @Column(name = "fecha_uso")
    private LocalDateTime usedDate;

    @Column(name = "creado_en")
    private LocalDateTime createdAt;
}
