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
 *  Versión:     1.1.0
 *  Fecha:       24/06/2026
 * ============================================================
 */
package com.xpressrides.backend.service;

import com.xpressrides.backend.model.ExchangeRate;
import com.xpressrides.backend.repository.ExchangeRateRepository;
import org.springframework.stereotype.Service;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

@Service
public class ExchangeRateService {

    private final ExchangeRateRepository exchangeRateRepository;

    // Inyección de dependencias por constructor
    public ExchangeRateService(ExchangeRateRepository exchangeRateRepository) {
        this.exchangeRateRepository = exchangeRateRepository;
    }

    // Retorna la tasa vigente más reciente
    // Si hoy es feriado o fin de semana, devuelve la del último día hábil
    public Optional<ExchangeRate> getCurrentRate() {
        return exchangeRateRepository.findCurrentRate();
    }

    // Retorna el historial completo de tasas registradas
    public List<ExchangeRate> getHistory() {
        return exchangeRateRepository.findAll();
    }

    // Registra una nueva tasa BCV para la fecha indicada
    // Validación: no se puede registrar dos veces la misma fecha (UNIQUE en BD)
    public ExchangeRate registerRate(ExchangeRate exchangeRate) {
        if (exchangeRate.getEffectiveDate() == null) {
            exchangeRate.setEffectiveDate(LocalDate.now());
        }
        return exchangeRateRepository.save(exchangeRate);
    }
}
