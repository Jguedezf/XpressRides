package com.xpressrides.backend.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.xpressrides.backend.model.Usuario;


public interface UsuarioRepository extends JpaRepository<Usuario, Integer> {

    Optional<Usuario> findByUsername(String username);
    
    boolean existsByUsername(String username);

    List<Usuario> findByActiveTrueAndRole(String role);
}
