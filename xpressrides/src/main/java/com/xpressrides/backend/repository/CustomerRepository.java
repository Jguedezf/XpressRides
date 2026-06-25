package com.xpressrides.backend.repository;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.xpressrides.backend.model.Customer;

public interface CustomerRepository extends JpaRepository<Customer, Integer> {
    Optional<Customer> findByUserId_Username(String username);
}
