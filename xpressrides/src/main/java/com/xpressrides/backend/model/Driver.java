/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Choferes
 *  Descripción: Mapeo de la tabla 'chofer' — datos operativos del
 *               chofer: banco, zona actual, saldo, habilitación
 *  Versión:     1.0.0
 *  Fecha:       24/06/2026
 * ============================================================
 */
package com.xpressrides.backend.model;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

@Data
@Entity
@NoArgsConstructor
@AllArgsConstructor
@Table(name = "chofer")
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

    @Column(name = "lat_actual")
    private BigDecimal latActual;

    @Column(name = "lng_actual")
    private BigDecimal lngActual;

    @Column(name = "ubicacion_actualizada_en")
    private LocalDateTime ubicacionActualizadaEn;

    @Column(name = "creado_en", insertable = false, updatable = false)
    private LocalDateTime createdAt;

    // @JsonIgnore evita recursión infinita al serializar:
    // Driver → List<PsychologicalEvaluation> → Driver → ...
    @JsonIgnore
    @OneToMany(mappedBy = "driver")
    private List<PsychologicalEvaluation> psychologicalEvaluations;

}
