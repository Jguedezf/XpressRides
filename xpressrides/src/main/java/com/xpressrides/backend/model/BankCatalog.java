package com.xpressrides.backend.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Entity
@NoArgsConstructor
@AllArgsConstructor
@Table(name = "catalogo_banco")
public class BankCatalog {

    @Id
    @Column(name = "codigo_bcv")
    private String bcvCode;

    @Column(name = "nombre")
    private String name;

}
