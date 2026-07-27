package com.xpressrides.backend.service;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.xpressrides.backend.exception.ResourceNotFoundException;
import com.xpressrides.backend.model.Incident;
import com.xpressrides.backend.model.Notification;
import com.xpressrides.backend.model.User;
import com.xpressrides.backend.repository.IncidentRepository;
import com.xpressrides.backend.repository.NotificationRepository;
import com.xpressrides.backend.repository.TripRepository;
import com.xpressrides.backend.repository.UserRepository;

@Service
public class NotificationService {

    private final NotificationRepository notificationRepository;
    private final UserRepository userRepository;
    private final IncidentRepository incidentRepository;
    private final TripRepository tripRepository;

    public NotificationService(NotificationRepository notificationRepository,
                               UserRepository userRepository,
                               IncidentRepository incidentRepository,
                               TripRepository tripRepository) {
        this.notificationRepository = notificationRepository;
        this.userRepository = userRepository;
        this.incidentRepository = incidentRepository;
        this.tripRepository = tripRepository;
    }

    public List<Notification> getNotifications(String username) {
        User user = userRepository.findByUsername(username)
            .orElseThrow(() -> new ResourceNotFoundException("Usuario no encontrado"));
        return notificationRepository.findByUser_IdOrderByDateTimeDesc(user.getId());
    }

    @Transactional
    public void markAsRead(String username, Integer notificationId) {
        User user = userRepository.findByUsername(username)
            .orElseThrow(() -> new ResourceNotFoundException("Usuario no encontrado"));
        Notification notification = notificationRepository.findByIdAndUser_Id(notificationId, user.getId())
            .orElseThrow(() -> new ResourceNotFoundException("Notificación no encontrada"));
        notification.setRead(true);
        notificationRepository.save(notification);
    }

    public long countUnread(String username) {
        User user = userRepository.findByUsername(username)
            .orElseThrow(() -> new ResourceNotFoundException("Usuario no encontrado"));
        return notificationRepository.countByUser_IdAndReadFalse(user.getId());
    }

    @Transactional
    public void sendEmergencyAlert(String username, Integer tripId) {
        User reportingUser = userRepository.findByUsername(username)
            .orElseThrow(() -> new ResourceNotFoundException("Usuario no encontrado"));

        List<User> admins = userRepository.findByRoleIn(List.of("administrador", "personal_admin"));
        
        String mensaje = "🚨 EMERGENCIA REPORTADA por " + reportingUser.getName() + " " + reportingUser.getLastName() +
                         (tripId != null ? " en el traslado #" + tripId : "");

        for (User admin : admins) {
            if (admin.getActive() == null || !admin.getActive()) continue;
            Notification alert = new Notification();
            alert.setUser(admin);
            alert.setType("emergencia");
            alert.setMessage(mensaje);
            alert.setRead(false);
            alert.setDateTime(java.time.LocalDateTime.now());
            // Opcionalmente se puede asociar el tripId si se recupera la entidad Trip
            notificationRepository.save(alert);
        }

        // Un solo Incidente por evento de emergencia (no uno por cada Notification
        // generada arriba, ya que hay una por cada admin) — es el caso que el admin
        // puede tomar y cerrar desde el panel.
        Incident incident = new Incident();
        incident.setReportedBy(reportingUser);
        incident.setMessage(mensaje);
        incident.setStatus("abierto");
        incident.setCreatedAt(java.time.LocalDateTime.now());
        if (tripId != null) {
            tripRepository.findById(tripId).ifPresent(incident::setTrip);
        }
        incidentRepository.save(incident);
    }

    public List<Map<String, Object>> getIncidents() {
        return incidentRepository.findAllByOrderByCreatedAtDesc().stream()
                .map(this::mapIncidentToDto)
                .collect(Collectors.toList());
    }

    @Transactional
    public Map<String, Object> takeIncident(Integer incidentId) {
        Incident incident = incidentRepository.findById(incidentId)
            .orElseThrow(() -> new ResourceNotFoundException("Incidente no encontrado"));
        incident.setStatus("en_proceso");
        incident = incidentRepository.save(incident);
        return mapIncidentToDto(incident);
    }

    @Transactional
    public Map<String, Object> closeIncident(Integer incidentId, String adminUsername, String resolutionNotes) {
        Incident incident = incidentRepository.findById(incidentId)
            .orElseThrow(() -> new ResourceNotFoundException("Incidente no encontrado"));
        User admin = userRepository.findByUsername(adminUsername)
            .orElseThrow(() -> new ResourceNotFoundException("Usuario no encontrado"));

        incident.setStatus("cerrado");
        incident.setResolutionNotes(resolutionNotes);
        incident.setClosedBy(admin);
        incident.setClosedAt(java.time.LocalDateTime.now());
        incident = incidentRepository.save(incident);
        return mapIncidentToDto(incident);
    }

    private Map<String, Object> mapIncidentToDto(Incident inc) {
        Map<String, Object> dto = new HashMap<>();
        dto.put("id", inc.getId());
        dto.put("message", inc.getMessage());
        dto.put("status", inc.getStatus());
        dto.put("resolutionNotes", inc.getResolutionNotes());
        dto.put("createdAt", inc.getCreatedAt());

        if (inc.getReportedBy() != null) {
            Map<String, Object> rb = new HashMap<>();
            rb.put("name", inc.getReportedBy().getName());
            rb.put("lastName", inc.getReportedBy().getLastName());
            rb.put("phone", inc.getReportedBy().getPhone());
            rb.put("email", inc.getReportedBy().getEmail());
            dto.put("reportedBy", rb);
        }

        if (inc.getTrip() != null) {
            Map<String, Object> tr = new HashMap<>();
            tr.put("id", inc.getTrip().getId());
            tr.put("originAddress", inc.getTrip().getOriginAddress());
            tr.put("destinationAddress", inc.getTrip().getDestinationAddress());
            tr.put("customerCostUsd", inc.getTrip().getCustomerCostUsd());
            
            if (inc.getTrip().getDriver() != null) {
                Map<String, Object> dr = new HashMap<>();
                dr.put("latActual", inc.getTrip().getDriver().getLatActual());
                dr.put("lngActual", inc.getTrip().getDriver().getLngActual());
                tr.put("driver", dr);
            }
            dto.put("trip", tr);
        }

        return dto;
    }
}
