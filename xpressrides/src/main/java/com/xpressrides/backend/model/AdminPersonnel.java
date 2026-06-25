/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Personal Administrativo
 *  Descripción: Mapeo de la tabla 'personal_admin' — cargo y datos
 *               del personal que gestiona choferes y pagos
 *  Versión:     1.0.0
 *  Fecha:       24/06/2026
 * ============================================================
 */
package com.xpressrides.backend.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.time.LocalDateTime;

@Data
@Entity
@NoArgsConstructor
@AllArgsConstructor
@Table(name = "personal_admin")
public class AdminPersonnel {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @OneToOne
    @JoinColumn(name = "id_usuario")
    private User userId;

    @Column(name = "cargo")
    private String position;

    @Column(name = "creado_en", insertable = false, updatable = false)
    private LocalDateTime createdAt;
}
