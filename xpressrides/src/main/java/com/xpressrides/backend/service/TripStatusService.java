/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Traslados
 *  Descripción: Servicio para actualización de estado del traslado —
 *               valida transiciones, actualiza timestamps y delega
 *               la generación de factura al trigger de MySQL
 *  Versión:     1.0.0
 *  Fecha:       24/06/2026
 * ============================================================
 */
package com.xpressrides.backend.service;

import com.xpressrides.backend.dto.TripStatusUpdateDTO;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import jakarta.persistence.Query;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
public class TripStatusService {

    @PersistenceContext
    private EntityManager entityManager;

    private static final List<String> ESTADOS_VALIDOS = Arrays.asList(
            "aceptado", "en_camino", "chofer_llego", "en_progreso", "completado", "cancelado"
    );

    private static final List<String> CANCELADO_POR_VALIDOS = Arrays.asList(
            "cliente", "chofer", "empresa"
    );

    @Transactional
    public Map<String, Object> updateStatus(Integer tripId, TripStatusUpdateDTO dto) {

        if (dto.getEstado() == null || !ESTADOS_VALIDOS.contains(dto.getEstado())) {
            throw new RuntimeException(
                    "Estado inválido. Valores permitidos: " + String.join(", ", ESTADOS_VALIDOS));
        }

        // Cuando se cancela, canceladoPor es obligatorio y debe ser valor válido
        if ("cancelado".equals(dto.getEstado())) {
            if (dto.getCanceladoPor() == null || !CANCELADO_POR_VALIDOS.contains(dto.getCanceladoPor())) {
                throw new RuntimeException(
                        "Para cancelar debe indicar quién cancela: cliente, chofer o empresa");
            }
        }

        // Verificar que el traslado existe
        Query checkQuery = entityManager.createNativeQuery(
                "SELECT COUNT(*) FROM traslado WHERE id = :id");
        checkQuery.setParameter("id", tripId);
        Long count = ((Number) checkQuery.getSingleResult()).longValue();
        if (count == 0) {
            throw new RuntimeException("No existe traslado con id: " + tripId);
        }

        // Actualizar estado y timestamps correspondientes al nuevo estado
        Query updateQuery = entityManager.createNativeQuery("""
                UPDATE traslado SET
                  estado              = :estado,
                  cancelado_por       = :canceladoPor,
                  motivo_cancelacion  = :motivoCancelacion,
                  fecha_aceptacion    = CASE WHEN :estado = 'aceptado'
                                            THEN NOW() ELSE fecha_aceptacion END,
                  fecha_inicio        = CASE WHEN :estado = 'en_progreso'
                                            THEN NOW() ELSE fecha_inicio END,
                  fecha_fin           = CASE WHEN :estado IN ('completado','cancelado')
                                            THEN NOW() ELSE fecha_fin END,
                  duracion_minutos    = CASE WHEN :estado = 'completado'
                                             AND fecha_inicio IS NOT NULL
                                            THEN TIMESTAMPDIFF(MINUTE, fecha_inicio, NOW())
                                            ELSE duracion_minutos END
                WHERE id = :id
                """);

        updateQuery.setParameter("estado", dto.getEstado());
        updateQuery.setParameter("canceladoPor", dto.getCanceladoPor());
        updateQuery.setParameter("motivoCancelacion", dto.getMotivoCancelacion());
        updateQuery.setParameter("id", tripId);

        int filas = updateQuery.executeUpdate();
        if (filas == 0) {
            throw new RuntimeException("No se pudo actualizar el estado del traslado");
        }

        // Cuando estado = completado, el trigger trg_traslado_eventos genera
        // la factura y las notificaciones automáticamente — no se requiere acción adicional

        Map<String, Object> result = new HashMap<>();
        result.put("trasladoId", tripId);
        result.put("estado", dto.getEstado());
        return result;
    }
}
