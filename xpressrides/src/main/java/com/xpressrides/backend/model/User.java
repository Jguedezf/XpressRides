/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Usuarios — Tabla base
 *  Descripción: Mapeo de la tabla 'usuario' — credenciales y datos
 *               comunes de todos los roles del sistema
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
@Table(name = "usuario")
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(name = "cedula")
    private String ci;

    @Column(name = "nombre")
    private String name;

    @Column(name = "apellido")
    private String lastName;

    @Column(name = "username")
    private String username;

    @Column(name = "password_hash")
    private String password;

    @Column(name = "email")
    private String email;

    @Column(name = "telefono")
    private String phone;

    @Column(name = "rol")
    private String role;

    @Column(name = "activo")
    private Boolean active;

    @Column(name = "creado_en", insertable = false, updatable = false)
    private LocalDateTime createdAt;
}
