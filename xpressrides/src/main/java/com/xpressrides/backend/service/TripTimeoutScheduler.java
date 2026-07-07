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

    private static final int RESPONSE_TIMEOUT_SECONDS = 30;

    private final TripRepository tripRepository;
    private final TripRejectionService tripRejectionService;

    public TripTimeoutScheduler(TripRepository tripRepository, TripRejectionService tripRejectionService) {
        this.tripRepository = tripRepository;
        this.tripRejectionService = tripRejectionService;
    }

    @Scheduled(initialDelay = 5000, fixedDelay = 3000)
    public void checkUnansweredTrips() {
        LocalDateTime threshold = LocalDateTime.now().minusSeconds(RESPONSE_TIMEOUT_SECONDS);
        List<Trip> expirados = tripRepository.findByStatusAndCurrentAssignmentDateBefore("solicitado", threshold);

        for (Trip trip : expirados) {
            tripRejectionService.expireTrip(trip.getId());
        }
    }
}
