package com.xpressrides.backend.security;

import java.time.LocalDateTime;

import org.springframework.stereotype.Service;

import com.xpressrides.backend.model.RevokedToken;
import com.xpressrides.backend.repository.RevokedTokenRepository;

@Service
public class TokenBlacklistService {

    private final RevokedTokenRepository revokedTokenRepository;

    public TokenBlacklistService(RevokedTokenRepository revokedTokenRepository) {
        this.revokedTokenRepository = revokedTokenRepository;
    }

    public void revoke(String token) {
        if (!revokedTokenRepository.existsById(token)) {
            revokedTokenRepository.save(new RevokedToken(token, LocalDateTime.now()));
        }
    }

    public boolean isRevoked(String token) {
        return revokedTokenRepository.existsById(token);
    }
}
