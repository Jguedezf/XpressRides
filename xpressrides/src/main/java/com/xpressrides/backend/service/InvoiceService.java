/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Facturación
 *  Descripción: Servicio de facturación — obtiene los datos de la
 *               factura y construye el DTO con los totales calculados
 *  Versión:     1.0.0
 *  Fecha:       24/06/2026
 * ============================================================
 */
package com.xpressrides.backend.service;

import com.xpressrides.backend.dto.InvoiceResponseDTO;
import com.xpressrides.backend.repository.InvoiceRepository;
import org.springframework.stereotype.Service;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;

@Service
public class InvoiceService {

    private final InvoiceRepository invoiceRepository;

    public InvoiceService(InvoiceRepository invoiceRepository) {
        this.invoiceRepository = invoiceRepository;
    }

    public InvoiceResponseDTO getInvoiceByTripId(Integer trasladoId) {
        List<Object[]> results = invoiceRepository.findInvoiceDataByTripId(trasladoId);
        if (results.isEmpty()) {
            throw new RuntimeException(
                    "No existe factura para el traslado con id: " + trasladoId);
        }
        Object[] row = results.get(0);

        InvoiceResponseDTO dto = new InvoiceResponseDTO();
        dto.setFacturaId(((Number) row[0]).intValue());
        dto.setNumeroDocumento((String) row[1]);
        dto.setControl((String) row[2]);
        dto.setSerie((String) row[3]);
        dto.setFechaEmision(row[4].toString());
        dto.setHoraEmision(row[5].toString());
        dto.setClienteNombre((String) row[6]);
        dto.setClienteCedula((String) row[7]);
        dto.setClienteDireccion((String) row[8]);
        dto.setChoferNombre((String) row[9]);
        dto.setZonaOrigen((String) row[10]);
        dto.setZonaDestino((String) row[11]);
        dto.setDistanciaKm(new BigDecimal(row[12].toString()));
        BigDecimal descuentoUsd = new BigDecimal(row[13].toString());
        dto.setDescuentoUsd(descuentoUsd);

        BigDecimal costoUsd     = new BigDecimal(row[14].toString());
        BigDecimal tasaVes      = new BigDecimal(row[15].toString());
        BigDecimal montoIgtfUsd = new BigDecimal(row[16].toString());

        dto.setDescuentoVes(descuentoUsd.multiply(tasaVes).setScale(2, RoundingMode.HALF_UP));

        BigDecimal totalUsd = costoUsd.add(montoIgtfUsd)
                .setScale(2, RoundingMode.HALF_UP);
        BigDecimal totalVes = totalUsd.multiply(tasaVes)
                .setScale(2, RoundingMode.HALF_UP);

        dto.setCostoUsd(costoUsd);
        dto.setTasaVes(tasaVes);
        dto.setMontoIgtfUsd(montoIgtfUsd);
        dto.setTotalUsd(totalUsd);
        dto.setTotalVes(totalVes);

        return dto;
    }
}
