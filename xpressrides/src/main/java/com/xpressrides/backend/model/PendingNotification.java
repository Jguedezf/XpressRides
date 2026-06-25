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
 *  Versión:     1.1.0
 *  Fecha:       24/06/2026
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
public class PendingNotification {

    @Id
    @Column(name = "id")
    private Integer id;

    @Column(name = "id_usuario")
    private Integer userId;

    @Column(name = "tipo")
    private String type;

    @Column(name = "mensaje")
    private String message;

    @Column(name = "fecha_hora")
    private LocalDateTime dateTime;

    @Column(name = "usuario")
    private String username;

    @Column(name = "rol_usuario")
    private String userRole;
}
