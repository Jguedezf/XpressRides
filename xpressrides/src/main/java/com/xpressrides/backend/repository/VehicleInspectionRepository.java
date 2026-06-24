package com.xpressrides.backend.repository;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.xpressrides.backend.model.VehicleInspection;

public interface VehicleInspectionRepository extends JpaRepository<VehicleInspection,Integer>{
    Optional<VehicleInspection> findFirstByVehicleIdOrderByInspectionDateDesc(Integer vehicleId);
}
