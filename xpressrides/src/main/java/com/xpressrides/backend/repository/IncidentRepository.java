package com.xpressrides.backend.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.xpressrides.backend.model.Incident;

public interface IncidentRepository extends JpaRepository<Incident, Integer> {
    List<Incident> findAllByOrderByCreatedAtDesc();
}
