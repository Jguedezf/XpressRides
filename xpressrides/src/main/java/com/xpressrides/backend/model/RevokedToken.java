package com.xpressrides.backend.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.time.LocalDateTime;

@Entity
@Table(name = "token_revocado")
public class RevokedToken {

    @Id
    @Column(name = "token", length = 512, nullable = false)
    private String token;

    @Column(name = "revocado_en", nullable = false)
    private LocalDateTime revokedAt;

    public RevokedToken() {}

    public RevokedToken(String token, LocalDateTime revokedAt) {
        this.token = token;
        this.revokedAt = revokedAt;
    }

    public String getToken() {
        return token;
    }

    public void setToken(String token) {
        this.token = token;
    }

    public LocalDateTime getRevokedAt() {
        return revokedAt;
    }

    public void setRevokedAt(LocalDateTime revokedAt) {
        this.revokedAt = revokedAt;
    }
}
