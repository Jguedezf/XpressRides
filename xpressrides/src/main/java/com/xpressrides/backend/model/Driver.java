package com.xpressrides.backend.model;

import java.time.LocalDateTime;
import java.util.List;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OneToMany;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import lombok.*;
import java.math.BigDecimal;

@Entity
@Table(name = "chofer")
@Data
@AllArgsConstructor
@NoArgsConstructor

public class Driver {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @OneToOne
    @JoinColumn(name = "id_usuario")
    private User username;

    @ManyToOne
    @JoinColumn(name = "id_banco")
    private Bank bank;

    @ManyToOne
    @JoinColumn(name = "id_zona_actual")
    private Zone currentZone;

    @Column(name = "numero_cuenta")
    private String accountNumber;

    @Column(name = "saldo_acumulado_usd")
    private BigDecimal balance;

    @Column(name = "habilitado")
    private boolean enabled;

    @Column(name = "disponible")
    private boolean available;

    @Column(name = "creado_en")
    private LocalDateTime createdAt;

    @OneToMany(mappedBy = "driver")
    private List<PsychologicalEvaluation> psychologicalEvaluations;

}
