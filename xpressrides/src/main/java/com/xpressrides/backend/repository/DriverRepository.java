package com.xpressrides.backend.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.xpressrides.backend.model.Driver;

public interface DriverRepository extends JpaRepository<Driver, Integer> {

    List<Driver> findByEnabledTrueAndAvailableTrue();

    Optional<Driver> findByUsername_Username(String username);
}
