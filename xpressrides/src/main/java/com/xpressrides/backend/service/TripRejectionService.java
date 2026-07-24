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
    private final com.xpressrides.backend.repository.CustomerRepository customerRepository;

    public TripRejectionService(TripRepository tripRepository,
                                DriverRepository driverRepository,
                                NotificationRepository notificationRepository,
                                com.xpressrides.backend.repository.CustomerRepository customerRepository) {
        this.tripRepository         = tripRepository;
        this.driverRepository       = driverRepository;
        this.notificationRepository = notificationRepository;
        this.customerRepository     = customerRepository;
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

        // Liberar al chofer actual
        currentDriver.setAvailable(true);
        driverRepository.save(currentDriver);

        Map<String, Object> result = reassignOrCancel(tripId, currentDriver);
        if (result == null) {
            throw new BadRequestException("Este traslado ya no está disponible para rechazar (puede que ya haya cambiado de estado)");
        }
        return result;
    }

    // Disparado por TripTimeoutScheduler cuando el chofer asignado no respondió dentro del plazo
    @Transactional
    public void expireTrip(Integer tripId) {
        Trip trip = tripRepository.findById(tripId).orElse(null);
        if (trip == null || !"solicitado".equals(trip.getStatus())) {
            // Ya fue aceptado/cancelado/reasignado entre el barrido del scheduler y esta ejecución
            return;
        }

        Driver currentDriver = trip.getDriver();
        if (currentDriver != null) {
            currentDriver.setAvailable(true);
            driverRepository.save(currentDriver);
        }

        reassignOrCancel(tripId, currentDriver); // resultado null (nadie lo reclamó) se ignora aquí
    }

    // Lógica compartida entre rechazo explícito (rejectTrip) y no-respuesta por timeout (expireTrip):
    // reclama el viaje atómicamente y busca el siguiente chofer disponible, o cancela +
    // reembolsa + notifica al agotarse los 3 intentos. Devuelve null si el viaje ya no estaba
    // en 'solicitado' cuando se intentó reclamar (otra ejecución lo procesó primero).
    private Map<String, Object> reassignOrCancel(Integer tripId, Driver currentDriver) {
        if (tripRepository.claimSolicitadoForReassignment(tripId) == 0) {
            return null;
        }

        Trip trip = tripRepository.findById(tripId)
            .orElseThrow(() -> new ResourceNotFoundException("Traslado no encontrado con ID: " + tripId));

        int rechazos = trip.getRejections(); // ya viene incrementado por el claim atómico

        if (rechazos < 3) {
            // Buscar siguiente chofer disponible distinto al actual
            List<Driver> disponibles = driverRepository.findByEnabledTrueAndAvailableTrue()
                .stream()
                .filter(d -> currentDriver == null || !d.getId().equals(currentDriver.getId()))
                .collect(Collectors.toList());

            if (!disponibles.isEmpty()) {
                Driver siguiente = disponibles.get(0);
                siguiente.setAvailable(false);
                driverRepository.save(siguiente);
                trip.setDriver(siguiente);
                trip.setCurrentAssignmentDate(LocalDateTime.now());
                tripRepository.save(trip);

                Map<String, Object> result = new HashMap<>();
                result.put("estado", "reasignado");
                result.put("nuevoChofer", siguiente.getUsername().getName() + " " + siguiente.getUsername().getLastName());
                return result;
            }
        }

        // 3 rechazos/timeouts o sin choferes disponibles — cancelar y notificar al cliente
        trip.setStatus("cancelado");
        trip.setCancelledBy("sistema");
        trip.setCancellationReason("No hay choferes disponibles en este momento");
        trip.setDriver(null);
        tripRepository.save(trip);

        // Refund the customer
        if (trip.getCustomerCostUsd() != null) {
            com.xpressrides.backend.model.Customer customer = trip.getCustomer();
            customer.setBalance(customer.getBalance().add(trip.getCustomerCostUsd()));
            customerRepository.save(customer);
        }

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

    @Transactional
    public void cancelBuscandoTrip(Integer tripId) {
        Trip trip = tripRepository.findById(tripId).orElse(null);
        if (trip == null || !"buscando".equals(trip.getStatus())) return;

        // Liberar al chofer si por alguna razón estaba asociado (no debería,
        // pero un viaje previo podría haber dejado datos inconsistentes)
        Driver driver = trip.getDriver();
        if (driver != null) {
            driver.setAvailable(true);
            driverRepository.save(driver);
        }

        trip.setStatus("cancelado");
        trip.setCancelledBy("sistema");
        trip.setCancellationReason("No hay choferes disponibles en este momento");
        trip.setDriver(null);
        tripRepository.save(trip);

        if (trip.getCustomerCostUsd() != null) {
            com.xpressrides.backend.model.Customer customer = trip.getCustomer();
            customer.setBalance(customer.getBalance().add(trip.getCustomerCostUsd()));
            customerRepository.save(customer);
        }

        Notification notif = new Notification();
        notif.setUser(trip.getCustomer().getUserId());
        notif.setTrip(trip);
        notif.setType("sin_chofer");
        notif.setMessage("Lo sentimos, no pudimos encontrar choferes disponibles en este momento. Hemos cancelado tu viaje.");
        notif.setRead(false);
        notif.setDateTime(LocalDateTime.now());
        notificationRepository.save(notif);
    }
}
