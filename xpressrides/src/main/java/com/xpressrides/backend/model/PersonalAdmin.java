package com.xpressrides.backend.model;

import java.beans.ConstructorProperties;
import java.time.LocalDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "personal_admin")
@Data
@AllArgsConstructor
@NoArgsConstructor

public class PersonalAdmin {

    @Id
    @GeneratedValue(strategy = jakarta.persistence.GenerationType.IDENTITY)
    private Integer id;

    @OneToOne
    @JoinColumn(name = "id_usuario")
    private Usuario userId;

    @Column(name = "cargo")
    private String position;

    @Column(name = "creado_en")
    private LocalDateTime createdAt;
}
