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
 *  Versión:     1.1.0
 *  Fecha:       24/06/2026
 * ============================================================
 */
package com.xpressrides.backend.service;

import com.xpressrides.backend.model.*;
import com.xpressrides.backend.repository.*;
import org.springframework.stereotype.Service;
import java.util.List;

@Service
public class ReportService {

    private final TripHistoryRepository tripHistoryRepository;
    private final CompanyEarningsRepository companyEarningsRepository;
    private final DriverPaymentReportRepository driverPaymentReportRepository;
    private final PendingDriverPaymentRepository pendingDriverPaymentRepository;
    private final CancelledTripRepository cancelledTripRepository;
    private final IssuedInvoiceRepository issuedInvoiceRepository;
    private final PendingNotificationRepository pendingNotificationRepository;

    // Inyección de dependencias por constructor
    public ReportService(
            TripHistoryRepository tripHistoryRepository,
            CompanyEarningsRepository companyEarningsRepository,
            DriverPaymentReportRepository driverPaymentReportRepository,
            PendingDriverPaymentRepository pendingDriverPaymentRepository,
            CancelledTripRepository cancelledTripRepository,
            IssuedInvoiceRepository issuedInvoiceRepository,
            PendingNotificationRepository pendingNotificationRepository) {
        this.tripHistoryRepository = tripHistoryRepository;
        this.companyEarningsRepository = companyEarningsRepository;
        this.driverPaymentReportRepository = driverPaymentReportRepository;
        this.pendingDriverPaymentRepository = pendingDriverPaymentRepository;
        this.cancelledTripRepository = cancelledTripRepository;
        this.issuedInvoiceRepository = issuedInvoiceRepository;
        this.pendingNotificationRepository = pendingNotificationRepository;
    }

    // Historial completo de traslados
    public List<TripHistory> getTripHistory() {
        return tripHistoryRepository.findAll();
    }

    // Ganancias diarias de la empresa
    public List<CompanyEarnings> getCompanyEarnings() {
        return companyEarningsRepository.findAll();
    }

    // Pagos realizados a choferes
    public List<DriverPaymentReport> getDriverPaymentReport() {
        return driverPaymentReportRepository.findAll();
    }

    // Choferes con saldo pendiente de pago
    public List<PendingDriverPayment> getPendingDriverPayments() {
        return pendingDriverPaymentRepository.findAll();
    }

    // Traslados cancelados con motivo
    public List<CancelledTrip> getCancelledTrips() {
        return cancelledTripRepository.findAll();
    }

    // Facturas emitidas por traslados completados
    public List<IssuedInvoice> getIssuedInvoices() {
        return issuedInvoiceRepository.findAll();
    }

    // Notificaciones no leídas de clientes y choferes
    public List<PendingNotification> getPendingNotifications() {
        return pendingNotificationRepository.findAll();
    }
}
