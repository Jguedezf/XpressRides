/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Usuarios
 *  Descripción: DTO de entrada para actualizar datos del perfil
 *               de un usuario — nombre, apellido, email, teléfono, cédula
 *  Versión:     1.0.0
 *  Fecha:       25/06/2026
 * ============================================================
 */
package com.xpressrides.backend.dto.request;

import lombok.Data;

@Data
public class UserUpdateRequest {

    private String name;
    private String lastName;
    private String email;
    private String phone;
    private String ci;
}
