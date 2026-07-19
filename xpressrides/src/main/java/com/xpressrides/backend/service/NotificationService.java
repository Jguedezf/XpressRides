package com.xpressrides.backend.service;

import java.util.List;

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

        List<User> admins = userRepository.findAll().stream()
            .filter(u -> "administrador".equalsIgnoreCase(u.getRole()) || "personal_admin".equalsIgnoreCase(u.getRole()))
            .toList();

        String mensaje = "🚨 EMERGENCIA REPORTADA por " + reportingUser.getName() + " " + reportingUser.getLastName() +
                         (tripId != null ? " en el traslado #" + tripId : "");

        for (User admin : admins) {
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

    public List<Incident> getIncidents() {
        return incidentRepository.findAllByOrderByCreatedAtDesc();
    }

    @Transactional
    public Incident takeIncident(Integer incidentId) {
        Incident incident = incidentRepository.findById(incidentId)
            .orElseThrow(() -> new ResourceNotFoundException("Incidente no encontrado"));
        incident.setStatus("en_proceso");
        return incidentRepository.save(incident);
    }

    @Transactional
    public Incident closeIncident(Integer incidentId, String adminUsername, String resolutionNotes) {
        Incident incident = incidentRepository.findById(incidentId)
            .orElseThrow(() -> new ResourceNotFoundException("Incidente no encontrado"));
        User admin = userRepository.findByUsername(adminUsername)
            .orElseThrow(() -> new ResourceNotFoundException("Usuario no encontrado"));

        incident.setStatus("cerrado");
        incident.setResolutionNotes(resolutionNotes);
        incident.setClosedBy(admin);
        incident.setClosedAt(java.time.LocalDateTime.now());
        return incidentRepository.save(incident);
    }
}
