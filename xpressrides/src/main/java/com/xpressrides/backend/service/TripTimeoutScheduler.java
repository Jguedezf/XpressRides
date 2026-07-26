package com.xpressrides.backend.service;

import java.time.LocalDateTime;
import java.util.List;

import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import com.xpressrides.backend.model.Trip;
import com.xpressrides.backend.repository.TripRepository;

// Detecta viajes 'solicitado' cuyo chofer asignado no respondió (ni aceptó ni rechazó)
// dentro del plazo de RESPONSE_TIMEOUT_SECONDS, y dispara la misma reasignación/cancelación
// que usa el rechazo explícito (TripRejectionService.expireTrip).
@Component
public class TripTimeoutScheduler {

    private static final int RESPONSE_TIMEOUT_SECONDS = 40;

    private final TripRepository tripRepository;
    private final TripRejectionService tripRejectionService;
    private final TripService tripService;

    public TripTimeoutScheduler(TripRepository tripRepository, TripRejectionService tripRejectionService, TripService tripService) {
        this.tripRepository = tripRepository;
        this.tripRejectionService = tripRejectionService;
        this.tripService = tripService;
    }

    @Scheduled(initialDelay = 5000, fixedDelay = 3000)
    public void checkUnansweredTrips() {
        LocalDateTime threshold = LocalDateTime.now().minusSeconds(RESPONSE_TIMEOUT_SECONDS);
        List<Trip> expirados = tripRepository.findByStatusAndCurrentAssignmentDateBefore("solicitado", threshold);

        for (Trip trip : expirados) {
            tripRejectionService.expireTrip(trip.getId());
        }
    }

    @Scheduled(initialDelay = 5000, fixedDelay = 5000)
    public void checkBuscandoTrips() {
        List<Trip> buscando = tripRepository.findByStatus("buscando");
        LocalDateTime threshold = LocalDateTime.now().minusMinutes(5); // 5 minutes timeout

        for (Trip trip : buscando) {
            if (trip.getRequestDate() != null && trip.getRequestDate().isBefore(threshold)) {
                // Time out!
                tripRejectionService.cancelBuscandoTrip(trip.getId());
            } else {
                tripService.searchDriverForTrip(trip.getId());
            }
        }
    }
}
