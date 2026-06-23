package com.xpressrides.backend.dto;


public class AuthResponse {
    private String username;
    private String role;
    private String menssage;

    public AuthResponse(String username, String role, String menssage) {
        this.username = username;
        this.role = role;
        this.menssage = menssage;
    }

    public String getUsername() {
        return username;
    }

    public void setUsername(String username) {
        this.username = username;
    }

    public String getRole() {
        return role;
    }

    public void setRole(String role) {
        this.role = role;
    }

    public String getMenssage() {
        return menssage;
    }

    public void setMenssage(String menssage) {
        this.menssage = menssage;
    }
}
