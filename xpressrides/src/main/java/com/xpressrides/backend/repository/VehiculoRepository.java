package com.xpressrides.backend.repository;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.xpressrides.backend.model.Vehiculo;

public interface VehiculoRepository extends JpaRepository<Vehiculo, Integer>{
    Optional<Vehiculo> findByDriver_Id(Integer idChofer);
    boolean existsByPlate(String plate);
}
