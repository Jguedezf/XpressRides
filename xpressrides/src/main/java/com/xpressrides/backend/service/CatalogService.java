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

import com.xpressrides.backend.dto.request.BankRequest;
import com.xpressrides.backend.exception.BadRequestException;
import com.xpressrides.backend.exception.ResourceNotFoundException;
import com.xpressrides.backend.model.Bank;
import com.xpressrides.backend.model.Zone;
import com.xpressrides.backend.repository.BankRepository;
import com.xpressrides.backend.repository.ZoneRepository;
import org.springframework.dao.DataAccessException;
import org.springframework.stereotype.Service;
import java.time.LocalDateTime;
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

    // Crea un banco nuevo — personal_admin ingresa datos de tablas base (enunciado)
    public Bank crearBanco(BankRequest request) {
        Bank bank = new Bank();
        bank.setName(request.getName());
        bank.setBcvCode(request.getBcvCode());
        bank.setAcceptsUsd(request.getAcceptsUsd() != null ? request.getAcceptsUsd() : false);
        bank.setAcceptsVes(request.getAcceptsVes() != null ? request.getAcceptsVes() : true);
        bank.setActive(true);
        bank.setCreatedAt(LocalDateTime.now());

        try {
            return bankRepository.save(bank);
        } catch (DataAccessException e) {
            throw new BadRequestException(
                "No se pudo crear el banco: el código BCV ya está en uso o el nombre no cumple el mínimo de 3 caracteres.");
        }
    }

    // Actualiza un banco existente — no toca activo ni fecha de creación
    public Bank actualizarBanco(Integer id, BankRequest request) {
        Bank bank = bankRepository.findById(id)
            .orElseThrow(() -> new ResourceNotFoundException("Banco no encontrado"));

        bank.setName(request.getName());
        bank.setBcvCode(request.getBcvCode());
        bank.setAcceptsUsd(request.getAcceptsUsd() != null ? request.getAcceptsUsd() : false);
        bank.setAcceptsVes(request.getAcceptsVes() != null ? request.getAcceptsVes() : true);

        try {
            return bankRepository.save(bank);
        } catch (DataAccessException e) {
            throw new BadRequestException(
                "No se pudo actualizar el banco: el código BCV ya está en uso o el nombre no cumple el mínimo de 3 caracteres.");
        }
    }

    // Desactiva un banco — soft delete, mismo patrón que 'activo' en Zone
    public Bank desactivarBanco(Integer id) {
        Bank bank = bankRepository.findById(id)
            .orElseThrow(() -> new ResourceNotFoundException("Banco no encontrado"));

        bank.setActive(false);
        return bankRepository.save(bank);
    }
}
