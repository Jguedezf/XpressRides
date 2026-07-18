package com.xpressrides.backend.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.xpressrides.backend.model.EmergencyContact;

public interface EmergencyContactRepository extends JpaRepository<EmergencyContact,Integer>{
    List<EmergencyContact> findByDriver_Id(Integer driverId);
    long countByDriver_Id(Integer driverId);
}
