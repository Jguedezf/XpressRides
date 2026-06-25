package com.xpressrides.backend.service;

import com.xpressrides.backend.exception.BadRequestException;
import com.xpressrides.backend.exception.ResourceNotFoundException;
import com.xpressrides.backend.model.Driver;
import com.xpressrides.backend.model.Notification;
import com.xpressrides.backend.model.Trip;
import com.xpressrides.backend.repository.DriverRepository;
import com.xpressrides.backend.repository.NotificationRepository;
import com.xpressrides.backend.repository.TripRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
public class TripRejectionService {

    private final TripRepository tripRepository;
    private final DriverRepository driverRepository;
    private final NotificationRepository notificationRepository;

    public TripRejectionService(TripRepository tripRepository,
                                DriverRepository driverRepository,
                                NotificationRepository notificationRepository) {
        this.tripRepository         = tripRepository;
        this.driverRepository       = driverRepository;
        this.notificationRepository = notificationRepository;
    }

    // PUT /api/chofer/traslados/{id}/rechazar — chofer rechaza el viaje asignado
    @Transactional
    public Map<String, Object> rejectTrip(String driverUsername, Integer tripId) {

        Trip trip = tripRepository.findById(tripId)
            .orElseThrow(() -> new ResourceNotFoundException("Traslado no encontrado con ID: " + tripId));

        if (!"solicitado".equals(trip.getStatus())) {
            throw new BadRequestException("Solo se puede rechazar un traslado en estado 'solicitado'");
        }

        Driver currentDriver = driverRepository.findByUsername_Username(driverUsername)
            .orElseThrow(() -> new ResourceNotFoundException("Chofer no encontrado"));

        if (!currentDriver.getId().equals(trip.getDriver().getId())) {
            throw new BadRequestException("Este traslado no está asignado a tu cuenta");
        }

        // Liberar al chofer actual y sumar rechazo
        currentDriver.setAvailable(true);
        driverRepository.save(currentDriver);

        int rechazos = (trip.getRejections() == null ? 0 : trip.getRejections()) + 1;
        trip.setRejections(rechazos);

        if (rechazos < 3) {
            // Buscar siguiente chofer disponible distinto al actual
            List<Driver> disponibles = driverRepository.findByEnabledTrueAndAvailableTrue()
                .stream()
                .filter(d -> !d.getId().equals(currentDriver.getId()))
                .collect(Collectors.toList());

            if (!disponibles.isEmpty()) {
                Driver siguiente = disponibles.get(0);
                siguiente.setAvailable(false);
                driverRepository.save(siguiente);
                trip.setDriver(siguiente);
                tripRepository.save(trip);

                Map<String, Object> result = new HashMap<>();
                result.put("estado", "reasignado");
                result.put("nuevoChofer", siguiente.getUsername().getName() + " " + siguiente.getUsername().getLastName());
                return result;
            }
        }

        // 3 rechazos o sin choferes disponibles — cancelar y notificar al cliente
        trip.setStatus("cancelado");
        trip.setCancelledBy("sistema");
        trip.setCancellationReason("No hay choferes disponibles en este momento");
        tripRepository.save(trip);

        Notification notif = new Notification();
        notif.setUser(trip.getCustomer().getUserId());
        notif.setTrip(trip);
        notif.setType("sin_chofer");
        notif.setMessage("Lo sentimos, no hay choferes disponibles en este momento. Por favor intenta más tarde.");
        notif.setRead(false);
        notif.setDateTime(LocalDateTime.now());
        notificationRepository.save(notif);

        Map<String, Object> result = new HashMap<>();
        result.put("estado", "cancelado");
        result.put("motivo", "No hay choferes disponibles");
        return result;
    }
}
