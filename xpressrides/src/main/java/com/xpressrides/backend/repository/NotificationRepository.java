package com.xpressrides.backend.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.xpressrides.backend.model.Notification;

public interface NotificationRepository extends JpaRepository<Notification, Integer> {
    List<Notification> findByUser_IdOrderByDateTimeDesc(Integer userId);
    Optional<Notification> findByIdAndUser_Id(Integer id, Integer userId);
}
