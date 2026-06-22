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
 *  Versión:     1.0.0
 *  Fecha:       22/06/2026  17:55
 * ============================================================
 */
package com.xpressrides.backend.service;

import com.xpressrides.backend.model.Banco;
import com.xpressrides.backend.model.Zona;
import com.xpressrides.backend.repository.BancoRepository;
import com.xpressrides.backend.repository.ZonaRepository;
import org.springframework.stereotype.Service;
import java.util.List;

@Service
public class CatalogoService {

    private final ZonaRepository zonaRepository;
    private final BancoRepository bancoRepository;

    // Inyección de dependencias por constructor — mejor práctica en Spring Boot
    public CatalogoService(ZonaRepository zonaRepository, BancoRepository bancoRepository) {
        this.zonaRepository = zonaRepository;
        this.bancoRepository = bancoRepository;
    }

    // Retorna todas las zonas activas para los dropdowns del frontend
    public List<Zona> listarZonasActivas() {
        return zonaRepository.findByActivoTrue();
    }

    // Retorna todas las zonas sin filtro — para el panel administrativo
    public List<Zona> listarTodasLasZonas() {
        return zonaRepository.findAll();
    }

    // Retorna todos los bancos activos para los dropdowns del frontend
    public List<Banco> listarBancosActivos() {
        return bancoRepository.findByActivoTrue();
    }

    // Retorna todos los bancos sin filtro — para el panel administrativo
    public List<Banco> listarTodosLosBancos() {
        return bancoRepository.findAll();
    }
}