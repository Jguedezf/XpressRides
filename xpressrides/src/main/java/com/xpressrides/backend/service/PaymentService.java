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
import java.util.List;

@Service
public class PaymentService {

    private final TopUpRepository topUpRepository;
    private final DriverPaymentRepository driverPaymentRepository;

    // Inyección de dependencias por constructor
    public PaymentService(TopUpRepository topUpRepository,
                          DriverPaymentRepository driverPaymentRepository) {
        this.topUpRepository = topUpRepository;
        this.driverPaymentRepository = driverPaymentRepository;
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
    public DriverPayment registerDriverPayment(DriverPayment payment) {
        return driverPaymentRepository.save(payment);
    }

    // Retorna el historial de pagos de un chofer específico
    public List<DriverPayment> getDriverPaymentHistory(Integer driverId) {
        return driverPaymentRepository.findByDriver_IdOrderByDateTimeDesc(driverId);
    }
}
