package com.xpressrides.backend.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.xpressrides.backend.model.User;


public interface UserRepository extends JpaRepository<User, Integer> {

    Optional<User> findByUsername(String username);
    
    boolean existsByUsername(String username);

    List<User> findByActiveTrueAndRole(String role);
}
