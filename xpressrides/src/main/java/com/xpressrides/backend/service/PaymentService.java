/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Pagos y Facturación
 *  Descripción: Servicio de pagos — lógica de negocio para recargas
 *               de clientes y pagos a choferes, incluyendo cálculo
 *               de IGTF para recargas directas en USD
 *  Versión:     1.2.0
 *  Fecha:       24/06/2026
 * ============================================================
 */
package com.xpressrides.backend.service;

import com.xpressrides.backend.model.DriverPayment;
import com.xpressrides.backend.model.TopUp;
import com.xpressrides.backend.repository.DriverPaymentRepository;
import com.xpressrides.backend.repository.TopUpRepository;
import org.springframework.stereotype.Service;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

import com.xpressrides.backend.model.AdminPersonnel;
import com.xpressrides.backend.model.Driver;
import com.xpressrides.backend.model.ExchangeRate;
import com.xpressrides.backend.repository.AdminPersonnelRepository;
import com.xpressrides.backend.repository.DriverRepository;
import com.xpressrides.backend.repository.TripRepository;
import com.xpressrides.backend.repository.ExchangeRateRepository;
import org.springframework.transaction.annotation.Transactional;

@Service
public class PaymentService {

    private final TopUpRepository topUpRepository;
    private final DriverPaymentRepository driverPaymentRepository;
    private final AdminPersonnelRepository adminRepository;
    private final DriverRepository driverRepository;
    private final TripRepository tripRepository;
    private final ExchangeRateRepository rateRepository;

    // Inyección de dependencias por constructor
    public PaymentService(TopUpRepository topUpRepository,
                          DriverPaymentRepository driverPaymentRepository,
                          AdminPersonnelRepository adminRepository,
                          DriverRepository driverRepository,
                          TripRepository tripRepository,
                          ExchangeRateRepository rateRepository) {
        this.topUpRepository = topUpRepository;
        this.driverPaymentRepository = driverPaymentRepository;
        this.adminRepository = adminRepository;
        this.driverRepository = driverRepository;
        this.tripRepository = tripRepository;
        this.rateRepository = rateRepository;
    }

    // Registra una recarga de saldo — calcula IGTF si el pago es en USD
    public TopUp registerTopUp(TopUp topUp) {
        // Si el frontend no envía moneda_pago, se asume pago en bolívares
        if (topUp.getPaymentCurrency() == null) {
            topUp.setPaymentCurrency("VES");
        }

        // IGTF 3% aplica solo cuando el pago es en divisas USD
        if ("USD".equals(topUp.getPaymentCurrency())) {
            BigDecimal igtfRate = new BigDecimal("0.03");
            topUp.setIgtfPercentage(new BigDecimal("3.00"));
            topUp.setIgtfAmountUsd(topUp.getAmountUsd().multiply(igtfRate)
                    .setScale(2, RoundingMode.HALF_UP));
        } else {
            topUp.setIgtfPercentage(BigDecimal.ZERO);
            topUp.setIgtfAmountUsd(BigDecimal.ZERO);
        }

        return topUpRepository.save(topUp);
    }

    // Retorna el historial de recargas de un cliente específico
    public List<TopUp> getTopUpHistory(Integer customerId) {
        return topUpRepository.findByCustomerIdOrderByDateTimeDesc(customerId);
    }

    // Registra un pago realizado a un chofer por personal admin
    @Transactional
    public DriverPayment registerDriverPayment(DriverPayment payment, String adminUsername) {
        // 1. Obtener Admin
        AdminPersonnel admin = adminRepository.findByUserId_Username(adminUsername)
                .orElseThrow(() -> new RuntimeException("Administrador no encontrado."));
        payment.setAdmin(admin);

        // 2. Obtener Chofer y su deuda
        Driver driver = driverRepository.findById(payment.getDriver().getId())
                .orElseThrow(() -> new RuntimeException("Chofer no encontrado."));
        
        if (driver.getBalance().compareTo(BigDecimal.ZERO) <= 0) {
            throw new RuntimeException("El chofer no tiene deuda pendiente.");
        }

        // Asignar el monto a pagar (todo el saldo pendiente)
        BigDecimal amountToPayUsd = driver.getBalance();
        payment.setAmountUsd(amountToPayUsd);

        // 3. Calcular monto en VES con la tasa de hoy
        ExchangeRate todayRate = rateRepository.findCurrentRate()
                .orElseThrow(() -> new RuntimeException("No hay tasa BCV configurada."));
        
        BigDecimal amountVes = amountToPayUsd.multiply(todayRate.getRateVes()).setScale(2, RoundingMode.HALF_UP);
        payment.setAmountVes(amountVes);
        
        // Asignar fecha actual
        payment.setDateTime(LocalDateTime.now());

        // 4. Guardar el pago
        DriverPayment savedPayment = driverPaymentRepository.save(payment);

        // 5. Vaciar el saldo del chofer
        driver.setBalance(BigDecimal.ZERO);
        driverRepository.save(driver);

        // 6. Marcar todos los traslados pendientes como pagados
        tripRepository.markTripsAsPaidForDriver(driver.getId());

        return savedPayment;
    }

    // Retorna el historial de pagos de un chofer, con filtro de fechas opcional
    public List<DriverPayment> getDriverPaymentHistory(Integer driverId, LocalDate desde, LocalDate hasta) {
        if (desde != null && hasta != null) {
            LocalDateTime desdeDateTime = desde.atStartOfDay();
            LocalDateTime hastaDateTime = hasta.atTime(23, 59, 59);
            return driverPaymentRepository.findByDriver_IdAndDateTimeBetweenOrderByDateTimeDesc(
                    driverId, desdeDateTime, hastaDateTime);
        }
        return driverPaymentRepository.findByDriver_IdOrderByDateTimeDesc(driverId);
    }
}
