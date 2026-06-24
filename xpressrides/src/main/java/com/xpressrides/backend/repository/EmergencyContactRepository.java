package com.xpressrides.backend.repository;

import org.springframework.data.jpa.repository.JpaRepository;

import com.xpressrides.backend.model.EmergencyContact;

public interface EmergencyContactRepository extends JpaRepository<EmergencyContact,Integer>{
}
