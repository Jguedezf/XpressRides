package com.xpressrides.backend.model;

import java.time.LocalDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.Data;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "incidente")
@Data
@NoArgsConstructor
public class Incident {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne
    @JoinColumn(name = "id_usuario_reporta")
    private User reportedBy;

    @ManyToOne
    @JoinColumn(name = "id_traslado")
    private Trip trip;

    @Column(name = "mensaje")
    private String message;

    // abierto | en_proceso | cerrado
    @Column(name = "estado")
    private String status;

    @Column(name = "notas_resolucion")
    private String resolutionNotes;

    @ManyToOne
    @JoinColumn(name = "id_admin_cierra")
    private User closedBy;

    @Column(name = "fecha_creacion", insertable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "fecha_cierre")
    private LocalDateTime closedAt;
}
