package com.xpressrides.backend.repository;


import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.xpressrides.backend.model.Driver;

public interface DriverRepository extends JpaRepository<Driver, Integer> {

    List<Driver> findByEnabledTrueAndAvailableTrue();
}
