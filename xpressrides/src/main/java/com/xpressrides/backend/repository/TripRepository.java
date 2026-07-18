package com.xpressrides.backend.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.xpressrides.backend.model.Trip;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

public interface TripRepository extends JpaRepository<Trip, Integer>, JpaSpecificationExecutor<Trip> {

    Page<Trip> findByCustomer_IdOrderByRequestDateDesc(Integer customerId, Pageable pageable);
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

    // Traslados del chofer filtrados por estado y rango de fechas (cancelados, con período)
    List<Trip> findByDriver_Username_UsernameAndStatusAndRequestDateBetweenOrderByRequestDateDesc(
            String username, String status, LocalDateTime desde, LocalDateTime hasta);

    // Marca como pagados todos los viajes completados de un chofer que no habían sido pagados
    @org.springframework.data.jpa.repository.Modifying
    @Query("UPDATE Trip t SET t.pagadoAlChofer = true WHERE t.driver.id = :driverId AND t.status = 'completado' AND t.pagadoAlChofer = false")
    int markTripsAsPaidForDriver(@Param("driverId") Integer driverId);

    // Viajes 'solicitado' cuyo chofer asignado no respondió dentro del plazo (timeout)
    List<Trip> findByStatusAndCurrentAssignmentDateBefore(String status, LocalDateTime threshold);

    // Reclama atómicamente un viaje 'solicitado' incrementando sus rechazos, solo si en este
    // instante SIGUE en ese estado en la BD (condición evaluada por MySQL al tomar el lock de
    // fila, no por una lectura previa en Java). Si devuelve 0, el chofer ya respondió (aceptó/
    // rechazó) o el viaje ya fue procesado por otra ejecución justo antes — evita que el
    // scheduler de timeout y una acción del chofer actúen sobre el mismo viaje a la vez.
    @org.springframework.data.jpa.repository.Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("UPDATE Trip t SET t.rejections = COALESCE(t.rejections, 0) + 1 WHERE t.id = :id AND t.status = 'solicitado'")
    int claimSolicitadoForReassignment(@Param("id") Integer id);
}
