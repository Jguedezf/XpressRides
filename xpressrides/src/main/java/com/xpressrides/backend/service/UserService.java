/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Usuarios
 *  Descripción: Lógica de negocio para actualización de datos
 *               del perfil de usuario
 *  Versión:     1.0.0
 *  Fecha:       25/06/2026
 * ============================================================
 */
package com.xpressrides.backend.service;

import com.xpressrides.backend.dto.request.UserUpdateRequest;
import com.xpressrides.backend.model.User;
import com.xpressrides.backend.repository.UserRepository;
import org.springframework.stereotype.Service;

@Service
public class UserService {

    private final UserRepository userRepository;

    public UserService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    // Actualiza los datos del perfil de un usuario por su ID
    public User updateUser(Integer id, UserUpdateRequest request) {
        User user = userRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Usuario no encontrado con ID: " + id));

        // Solo actualiza los campos que vienen en el request (no nulos)
        if (request.getName() != null)     user.setName(request.getName());
        if (request.getLastName() != null) user.setLastName(request.getLastName());
        if (request.getEmail() != null)    user.setEmail(request.getEmail());
        if (request.getPhone() != null)    user.setPhone(request.getPhone());
        if (request.getCi() != null)       user.setCi(request.getCi());

        return userRepository.save(user);
    }
}
