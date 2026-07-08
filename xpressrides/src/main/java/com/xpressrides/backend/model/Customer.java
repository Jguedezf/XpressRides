package com.xpressrides.backend.model;

import java.math.BigDecimal;
import java.time.LocalDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
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

    // Código propio que este cliente comparte para referir a otros — se genera
    // en el registro (ver AuthService) y nunca se deriva del ID.
    @Column(name = "codigo_referido")
    private String codigoReferido;

    // Cliente que lo refirió, si aplica. Se asigna al registrarse (si el flujo
    // lo captura) o después vía PUT /api/cliente/perfil/referido, dentro de la
    // ventana configurable en application.properties.
    @ManyToOne
    @JoinColumn(name = "referido_por")
    private Customer referidoPor;

    // Evita que la recompensa del referente se otorgue más de una vez para
    // este mismo cliente referido — la marca trg_recompensa_referido en la BD.
    @Column(name = "recompensa_referido_otorgada")
    private Boolean recompensaReferidoOtorgada;

}
