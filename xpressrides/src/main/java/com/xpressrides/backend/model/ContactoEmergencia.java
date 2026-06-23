package com.xpressrides.backend.model;

import java.time.LocalDateTime;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "contacto_emergencia")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class ContactoEmergencia {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @ManyToOne
    @JoinColumn(name = "id_chofer")
    private Chofer driver;

    @Column(name = "nombre")
    private String name;

    @Column(name = "telefono")
    private String phone;

    @Column(name = "parentesco")
    private String relationship;

    @Column(name = "creado_en")
    private LocalDateTime createdAt;
    
}