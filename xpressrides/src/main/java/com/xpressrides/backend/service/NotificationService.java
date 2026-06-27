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
}
