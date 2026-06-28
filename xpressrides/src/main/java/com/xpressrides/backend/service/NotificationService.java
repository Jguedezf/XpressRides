package com.xpressrides.backend.service;

import java.util.List;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.xpressrides.backend.exception.ResourceNotFoundException;
import com.xpressrides.backend.model.Notification;
import com.xpressrides.backend.model.User;
import com.xpressrides.backend.repository.NotificationRepository;
import com.xpressrides.backend.repository.UserRepository;

@Service
public class NotificationService {

    private final NotificationRepository notificationRepository;
    private final UserRepository userRepository;

    public NotificationService(NotificationRepository notificationRepository,
                               UserRepository userRepository) {
        this.notificationRepository = notificationRepository;
        this.userRepository = userRepository;
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
        User driverUser = userRepository.findByUsername(username)
            .orElseThrow(() -> new ResourceNotFoundException("Usuario no encontrado"));

        List<User> admins = userRepository.findAll().stream()
            .filter(u -> "administrador".equalsIgnoreCase(u.getRole()) || "personal_admin".equalsIgnoreCase(u.getRole()))
            .toList();

        for (User admin : admins) {
            Notification alert = new Notification();
            alert.setUser(admin);
            alert.setType("emergencia");
            alert.setMessage("🚨 EMERGENCIA REPORTADA por el chofer " + driverUser.getName() + " " + driverUser.getLastName() + 
                             (tripId != null ? " en el traslado #" + tripId : ""));
            alert.setRead(false);
            alert.setDateTime(java.time.LocalDateTime.now());
            // Opcionalmente se puede asociar el tripId si se recupera la entidad Trip
            notificationRepository.save(alert);
        }
    }
}
