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
@Table(name = "recarga_saldo")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class RecargaSaldo {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne
    @JoinColumn(name = "id_cliente")
    private Cliente customer;

    @ManyToOne
    @JoinColumn(name = "id_banco")
    private Banco bank;

    @ManyToOne
    @JoinColumn(name = "id_tasa")
    private TasaBcv rate;

    @Column(name = "monto_usd")
    private BigDecimal amountUsd;

    @Column(name = "monto_ves")
    private BigDecimal amountVes;

    @Column(name = "referencia")
    private String reference;

    @Column(name = "fecha_hora")
    private LocalDateTime dateTime;

}
