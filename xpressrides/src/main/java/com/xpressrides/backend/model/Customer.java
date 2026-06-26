package com.xpressrides.backend.model;

import java.math.BigDecimal;
import java.time.LocalDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "cliente")
@Data
@AllArgsConstructor
@NoArgsConstructor
public class Customer {

    @Id
    @GeneratedValue(strategy = jakarta.persistence.GenerationType.IDENTITY)
    private Integer id;

    @OneToOne
    @JoinColumn(name = "id_usuario")
    private User userId;

    @Column(name = "saldo_usd")
    private BigDecimal balance;

    @Column(name = "es_estudiante")
    private boolean isStudent;

    @Column(name = "primer_viaje_usado")
    private boolean firstTripUsed;

    @Column(name = "creado_en")
    private LocalDateTime createdAt;

}
