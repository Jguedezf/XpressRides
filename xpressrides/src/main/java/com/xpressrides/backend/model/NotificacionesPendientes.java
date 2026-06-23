/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Reportes — Vistas SQL
 *  Descripción: Mapeo de la vista 'v_notificaciones_pendientes' —
 *               notificaciones no leídas de clientes y choferes
 *  Versión:     1.0.0
 *  Fecha:       22/06/2026  HH:MM
 * ============================================================
 */
package com.xpressrides.backend.model;

import jakarta.persistence.*;
import lombok.Data;
import org.hibernate.annotations.Immutable;
import java.time.LocalDateTime;

@Data
@Entity
@Immutable
@Table(name = "v_notificaciones_pendientes")
public class NotificacionesPendientes {

    @Id
    @Column(name = "id")
    private Integer id;

    @Column(name = "id_usuario")
    private Integer idUsuario;

    @Column(name = "tipo")
    private String tipo;

    @Column(name = "mensaje")
    private String mensaje;

    @Column(name = "fecha_hora")
    private LocalDateTime fechaHora;

    @Column(name = "usuario")
    private String usuario;

    @Column(name = "rol_usuario")
    private String rolUsuario;
}