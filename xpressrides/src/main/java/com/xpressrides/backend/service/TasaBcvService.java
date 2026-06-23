/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Tasa BCV
 *  Descripción: Lógica de negocio para la tasa BCV —
 *               consulta de tasa vigente y registro de nueva tasa.
 *               Solo se registra en días hábiles bancarios.
 *  Versión:     1.0.0
 *  Fecha:       22/06/2026  HH:MM
 * ============================================================
 */
package com.xpressrides.backend.service;

import com.xpressrides.backend.model.TasaBcv;
import com.xpressrides.backend.repository.TasaBcvRepository;
import org.springframework.stereotype.Service;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

@Service
public class TasaBcvService {

    private final TasaBcvRepository tasaBcvRepository;

    // Inyección de dependencias por constructor
    public TasaBcvService(TasaBcvRepository tasaBcvRepository) {
        this.tasaBcvRepository = tasaBcvRepository;
    }

    // Retorna la tasa vigente más reciente
    // Si hoy es feriado o fin de semana, devuelve la del último día hábil
    public Optional<TasaBcv> obtenerTasaVigente() {
        return tasaBcvRepository.findTasaVigente();
    }

    // Retorna el historial completo de tasas registradas
    public List<TasaBcv> listarHistorial() {
        return tasaBcvRepository.findAll();
    }

    // Registra una nueva tasa BCV para la fecha indicada
    // Validación: no se puede registrar dos veces la misma fecha (UNIQUE en BD)
    public TasaBcv registrarTasa(TasaBcv tasa) {
        // Si no se especifica fecha, se usa la fecha de hoy
        if (tasa.getFechaVigencia() == null) {
            tasa.setFechaVigencia(LocalDate.now());
        }
        return tasaBcvRepository.save(tasa);
    }
}