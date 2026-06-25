package com.xpressrides.backend.repository;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.xpressrides.backend.model.PsychologicalEvaluation;

public interface PsychologicalEvaluationRepository extends JpaRepository<PsychologicalEvaluation,Integer>{
    Optional<PsychologicalEvaluation> findFirstByDriver_IdOrderByEvaluationDateDesc(Integer driverId);
}
