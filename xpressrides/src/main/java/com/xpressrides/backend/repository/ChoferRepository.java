package com.xpressrides.backend.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.xpressrides.backend.model.Chofer;

public interface ChoferRepository extends JpaRepository<Chofer, Integer> {

    List<Chofer> findByEnabledTrueAndAvailableTrue();
}
