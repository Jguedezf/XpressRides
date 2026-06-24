package com.xpressrides.backend.repository;

import org.springframework.data.jpa.repository.JpaRepository;

import com.xpressrides.backend.model.Trip;

public interface TripRepository extends JpaRepository<Trip, Integer> {
    
}
