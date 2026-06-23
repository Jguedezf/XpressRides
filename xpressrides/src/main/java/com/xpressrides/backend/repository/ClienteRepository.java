package com.xpressrides.backend.repository;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.xpressrides.backend.model.Cliente;

public interface ClienteRepository extends JpaRepository<Cliente, Integer> {
    Optional<Cliente> findByUserId_Username(String username);
}
