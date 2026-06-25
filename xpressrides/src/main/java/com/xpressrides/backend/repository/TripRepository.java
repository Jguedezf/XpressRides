package com.xpressrides.backend.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.xpressrides.backend.model.Trip;
import java.util.List;
import java.util.Optional;

public interface TripRepository extends JpaRepository<Trip, Integer> {

    @Query("SELECT AVG(t.starRating) FROM Trip t WHERE t.driver.id = :driverId AND t.status = 'completado' AND t.starRating IS NOT NULL")
    Double findAverageRatingByDriverId(@Param("driverId") Integer driverId);

    List<Trip> findByCustomer_IdOrderByRequestDateDesc(Integer customerId);

    Optional<Trip> findByIdAndCustomer_Id(Integer id, Integer customerId);

    List<Trip> findByDriver_Username_UsernameOrderByRequestDateDesc(String username);

    Optional<Trip> findByIdAndDriver_Username_Username(Integer id, String username);
}
