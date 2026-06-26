package com.xpressrides.backend.dto.response;


public class AuthResponse {
    private String username;
    private String role;
    private String accesToken;
    private String refreshToken;
    private String message;

    
    
    public AuthResponse(String username, String role, String accesToken, String refreshToken, String message) {
        this.username = username;
        this.role = role;
        this.accesToken = accesToken;
        this.refreshToken = refreshToken;
        this.message = message;
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

    public String getAccesToken() {
        return accesToken;
    }

    public void setAccesToken(String accesToken) {
        this.accesToken = accesToken;
    }

    public String getRefreshToken() {
        return refreshToken;
    }

    public void setRefreshToken(String refreshToken) {
        this.refreshToken = refreshToken;
    }

    public String getMessage() {
        return message;
    }

    public void setMessage(String message) {
        this.message = message;
    }
}
