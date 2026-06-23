package com.xpressrides.backend.model;

import java.math.BigDecimal;
import java.time.LocalDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "factura")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class Factura {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @OneToOne
    @JoinColumn(name = "id_traslado")
    private Traslado traslado;

    @Column(name = "nro_documento")
    private String documentNumber;

    @Column(name = "nro_control")
    private String controlNumber;

    @Column(name = "serie")
    private String serie;

    @Column(name = "fecha_emision")
    private LocalDateTime issueDate;

    @Column(name = "razon_social")
    private String businessName;

    @Column(name = "rif_cedula")
    private String taxId;

    @Column(name = "direccion_fiscal")
    private String fiscalAddress;

    @Column(name = "codigo_actividad")
    private String activityCode;

    @Column(name = "igtf_porcentaje")
    private BigDecimal igtfPercentage;

    @Column(name = "igtf_monto_usd")
    private BigDecimal igtfAmountUsd;

    @Column(name = "observacion_fiscal")
    private String fiscalObservation;

}
