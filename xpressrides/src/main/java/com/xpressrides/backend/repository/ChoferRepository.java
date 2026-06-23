package com.xpressrides.backend.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.xpressrides.backend.model.Chofer;

@Repository
public interface ChoferRepository extends JpaRepository<Chofer, Integer> {

    List<Chofer> findByEnabledTrueAndAvailableTrue();
}
