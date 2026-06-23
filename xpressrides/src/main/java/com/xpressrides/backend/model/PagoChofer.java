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
@Table(name = "pago_chofer")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class PagoChofer {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne
    @JoinColumn(name = "id_chofer")
    private Chofer driver;

    @ManyToOne
    @JoinColumn(name = "id_admin")
    private PersonalAdmin admin;

    @ManyToOne
    @JoinColumn(name = "id_banco")
    private Banco bank;

    @Column(name = "monto_usd")
    private BigDecimal amountUsd;

    @Column(name = "monto_ves")
    private BigDecimal amountVes;

    @Column(name = "referencia")
    private String reference;

    @Column(name = "fecha_hora")
    private LocalDateTime dateTime;

}
