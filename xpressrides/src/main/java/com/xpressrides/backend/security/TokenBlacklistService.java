package com.xpressrides.backend.security;

import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.stereotype.Service;

@Service
public class TokenBlacklistService {

    private final Set<String> blacklist = ConcurrentHashMap.newKeySet();

    public void revoke(String token) {
        blacklist.add(token);
    }

    public boolean isRevoked(String token) {
        return blacklist.contains(token);
    }
}
