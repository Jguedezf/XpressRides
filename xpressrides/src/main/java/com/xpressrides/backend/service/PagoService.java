/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Pagos y Facturación
 *  Descripción: Lógica de negocio para recargas de saldo de clientes
 *               y pagos a choferes por personal administrativo
 *  Versión:     1.0.0
 *  Fecha:       23/06/2026  HH:MM
 * ============================================================
 */
package com.xpressrides.backend.service;

import com.xpressrides.backend.model.PagoChofer;
import com.xpressrides.backend.model.RecargaSaldo;
import com.xpressrides.backend.repository.PagoChoferRepository;
import com.xpressrides.backend.repository.RecargaSaldoRepository;
import org.springframework.stereotype.Service;
import java.util.List;

@Service
public class PagoService {

    private final RecargaSaldoRepository recargaRepository;
    private final PagoChoferRepository pagoChoferRepository;

    // Inyección de dependencias por constructor
    public PagoService(RecargaSaldoRepository recargaRepository,
                       PagoChoferRepository pagoChoferRepository) {
        this.recargaRepository = recargaRepository;
        this.pagoChoferRepository = pagoChoferRepository;
    }

    // Registra una recarga de saldo para un cliente
    public RecargaSaldo registrarRecarga(RecargaSaldo recarga) {
        return recargaRepository.save(recarga);
    }

    // Retorna el historial de recargas de un cliente específico
    public List<RecargaSaldo> historialRecargas(Integer idCliente) {
        return recargaRepository.findByIdClienteOrderByFechaHoraDesc(idCliente);
    }

    // Registra un pago realizado a un chofer por personal admin
    public PagoChofer registrarPagoChofer(PagoChofer pago) {
        return pagoChoferRepository.save(pago);
    }

    // Retorna el historial de pagos de un chofer específico
    public List<PagoChofer> historialPagosChofer(Integer idChofer) {
        return pagoChoferRepository.findByIdChoferOrderByFechaHoraDesc(idChofer);
    }
}