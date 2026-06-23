package com.xpressrides.backend.repository;

import org.springframework.data.jpa.repository.JpaRepository;

import com.xpressrides.backend.model.PersonalAdmin;

public interface PersonalAdminRepository extends JpaRepository<PersonalAdmin, Integer> {
}
