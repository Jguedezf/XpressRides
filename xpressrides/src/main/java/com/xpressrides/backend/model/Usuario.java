package com.xpressrides.backend.model;

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
@Table(name = "usuario")
@Data
@AllArgsConstructor
@NoArgsConstructor

public class Usuario {

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

    @Column(name = "creado_en")
    private LocalDateTime createdAt;
}
