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
    private final com.xpressrides.backend.repository.UserRepository userRepository;

    // Inyección de dependencias por constructor
    public ExchangeRateService(ExchangeRateRepository exchangeRateRepository, com.xpressrides.backend.repository.UserRepository userRepository) {
        this.exchangeRateRepository = exchangeRateRepository;
        this.userRepository = userRepository;
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
    // Si ya existe una tasa para la fecha indicada, la actualiza (Upsert)
    public ExchangeRate registerRate(ExchangeRate exchangeRate) {
        if (exchangeRate.getEffectiveDate() == null) {
            exchangeRate.setEffectiveDate(LocalDate.now());
        }

        // Resolver dinámicamente el usuario administrador autenticado
        String username = org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication().getName();
        com.xpressrides.backend.model.User user = userRepository.findByUsername(username)
                .orElseThrow(() -> new RuntimeException("Usuario autenticado no encontrado"));
        exchangeRate.setRegisteredBy(user.getId());
        exchangeRate.setCreatedAt(java.time.LocalDateTime.now());

        Optional<ExchangeRate> existingOpt = exchangeRateRepository.findByEffectiveDate(exchangeRate.getEffectiveDate());
        if (existingOpt.isPresent()) {
            ExchangeRate existing = existingOpt.get();
            existing.setRateVes(exchangeRate.getRateVes());
            existing.setRegisteredBy(user.getId());
            return exchangeRateRepository.save(existing);
        }
        return exchangeRateRepository.save(exchangeRate);
    }
}
