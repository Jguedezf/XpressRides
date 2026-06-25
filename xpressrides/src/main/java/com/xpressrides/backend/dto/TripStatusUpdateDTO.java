/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Traslados
 *  Descripción: DTO para actualización de estado del traslado —
 *               recibe el nuevo estado y los campos opcionales
 *               de cancelación cuando aplica
 *  Versión:     1.0.0
 *  Fecha:       24/06/2026
 * ============================================================
 */
package com.xpressrides.backend.dto;

import lombok.Data;

@Data
public class TripStatusUpdateDTO {

    // Estados válidos: aceptado, en_camino, chofer_llego, en_progreso, completado, cancelado
    private String estado;

    // Requerido solo cuando estado = "cancelado": cliente, chofer, empresa
    private String canceladoPor;

    // Opcional cuando estado = "cancelado"
    private String motivoCancelacion;
}
