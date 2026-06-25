/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Catálogos Base
 *  Descripción: Lógica de negocio para catálogos geográficos
 *               y bancarios — zonas y bancos activos
 *  Versión:     1.1.0
 *  Fecha:       24/06/2026
 * ============================================================
 */
package com.xpressrides.backend.service;

import com.xpressrides.backend.model.Bank;
import com.xpressrides.backend.model.Zone;
import com.xpressrides.backend.repository.BankRepository;
import com.xpressrides.backend.repository.ZoneRepository;
import org.springframework.stereotype.Service;
import java.util.List;

@Service
public class CatalogService {

    private final ZoneRepository zoneRepository;
    private final BankRepository bankRepository;

    // Inyección de dependencias por constructor
    public CatalogService(ZoneRepository zoneRepository, BankRepository bankRepository) {
        this.zoneRepository = zoneRepository;
        this.bankRepository = bankRepository;
    }

    // Retorna todas las zonas activas para los dropdowns del frontend
    public List<Zone> listarZonasActivas() {
        return zoneRepository.findByActiveTrue();
    }

    // Retorna todas las zonas sin filtro — para el panel administrativo
    public List<Zone> listarTodasLasZonas() {
        return zoneRepository.findAll();
    }

    // Retorna todos los bancos activos para los dropdowns del frontend
    public List<Bank> listarBancosActivos() {
        return bankRepository.findByActiveTrue();
    }

    // Retorna todos los bancos sin filtro — para el panel administrativo
    public List<Bank> listarTodosLosBancos() {
        return bankRepository.findAll();
    }
}
