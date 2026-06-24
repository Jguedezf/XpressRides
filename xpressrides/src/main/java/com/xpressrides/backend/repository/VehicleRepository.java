package com.xpressrides.backend.repository;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.xpressrides.backend.model.Vehicle;

public interface VehicleRepository extends JpaRepository<Vehicle, Integer>{
    Optional<Vehicle> findByDriver_Id(Integer idChofer);
    
    boolean existsByPlate(String plate);
}
