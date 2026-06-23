/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Reportes — Vistas SQL
 *  Descripción: Lógica de negocio para todos los reportes —
 *               consulta de las 7 vistas SQL del sistema
 *  Versión:     1.0.0
 *  Fecha:       22/06/2026  HH:MM
 * ============================================================
 */
package com.xpressrides.backend.service;

import com.xpressrides.backend.model.*;
import com.xpressrides.backend.repository.*;
import org.springframework.stereotype.Service;
import java.util.List;

@Service
public class ReporteService {

    private final HistorialTrasladosRepository historialRepo;
    private final GananciasEmpresaRepository gananciasRepo;
    private final PagosPorChoferRepository pagosChoferRepo;
    private final PendientesPagoChoferRepository pendientesRepo;
    private final TrasladosCanceladosRepository canceladosRepo;
    private final FacturasEmitidasRepository facturasRepo;
    private final NotificacionesPendientesRepository notificacionesRepo;

    // Inyección de dependencias por constructor
    public ReporteService(
            HistorialTrasladosRepository historialRepo,
            GananciasEmpresaRepository gananciasRepo,
            PagosPorChoferRepository pagosChoferRepo,
            PendientesPagoChoferRepository pendientesRepo,
            TrasladosCanceladosRepository canceladosRepo,
            FacturasEmitidasRepository facturasRepo,
            NotificacionesPendientesRepository notificacionesRepo) {
        this.historialRepo = historialRepo;
        this.gananciasRepo = gananciasRepo;
        this.pagosChoferRepo = pagosChoferRepo;
        this.pendientesRepo = pendientesRepo;
        this.canceladosRepo = canceladosRepo;
        this.facturasRepo = facturasRepo;
        this.notificacionesRepo = notificacionesRepo;
    }

    // Historial completo de traslados
    public List<HistorialTraslados> listarHistorialTraslados() {
        return historialRepo.findAll();
    }

    // Ganancias diarias de la empresa
    public List<GananciasEmpresa> listarGanancias() {
        return gananciasRepo.findAll();
    }

    // Pagos realizados a choferes
    public List<PagosPorChofer> listarPagosPorChofer() {
        return pagosChoferRepo.findAll();
    }

    // Choferes con saldo pendiente de pago
    public List<PendientesPagoChofer> listarPendientesPago() {
        return pendientesRepo.findAll();
    }

    // Traslados cancelados con motivo
    public List<TrasladosCancelados> listarCancelados() {
        return canceladosRepo.findAll();
    }

    // Facturas emitidas por traslados completados
    public List<FacturasEmitidas> listarFacturas() {
        return facturasRepo.findAll();
    }

    // Notificaciones no leídas de clientes y choferes
    public List<NotificacionesPendientes> listarNotificaciones() {
        return notificacionesRepo.findAll();
    }
}