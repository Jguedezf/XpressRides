package com.xpressrides.backend.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.xpressrides.backend.model.Trip;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

public interface TripRepository extends JpaRepository<Trip, Integer> {

    List<Trip> findByStatusIn(List<String> statuses);

    @Query("SELECT AVG(t.starRating) FROM Trip t WHERE t.driver.id = :driverId AND t.status = 'completado' AND t.starRating IS NOT NULL")
    Double findAverageRatingByDriverId(@Param("driverId") Integer driverId);

    List<Trip> findByCustomer_IdOrderByRequestDateDesc(Integer customerId);

    Optional<Trip> findByIdAndCustomer_Id(Integer id, Integer customerId);

    List<Trip> findByDriver_Username_UsernameOrderByRequestDateDesc(String username);

    Optional<Trip> findByIdAndDriver_Username_Username(Integer id, String username);

    // Busca el viaje activo más reciente de un cliente dado una lista de estados
    Optional<Trip> findFirstByCustomer_IdAndStatusInOrderByRequestDateDesc(
            Integer customerId, List<String> statuses);

    // Busca el viaje activo más reciente de un chofer dado una lista de estados
    Optional<Trip> findFirstByDriver_Username_UsernameAndStatusInOrderByRequestDateDesc(
            String username, List<String> statuses);

    // Historial del chofer filtrado por rango de fechas
    List<Trip> findByDriver_Username_UsernameAndRequestDateBetweenOrderByRequestDateDesc(
            String username, LocalDateTime desde, LocalDateTime hasta);

    // Traslados del chofer filtrados por estado (usado para cancelados)
    List<Trip> findByDriver_Username_UsernameAndStatusOrderByRequestDateDesc(
            String username, String status);
}
