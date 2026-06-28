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
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.access.AccessDeniedException;

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

        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication == null) {
            throw new AccessDeniedException("No autorizado para modificar este perfil");
        }

        boolean isAdmin = authentication.getAuthorities().stream()
                .anyMatch(a -> a.getAuthority().equals("ROLE_administrador"));
        boolean isSelf = authentication.getName().equals(user.getUsername());

        if (!isAdmin && !isSelf) {
            throw new AccessDeniedException("No autorizado para modificar este perfil");
        }

        // Solo actualiza los campos que vienen en el request (no nulos)
        if (request.getName() != null)     user.setName(request.getName());
        if (request.getLastName() != null) user.setLastName(request.getLastName());
        if (request.getEmail() != null)    user.setEmail(request.getEmail());
        if (request.getPhone() != null)    user.setPhone(request.getPhone());
        if (request.getCi() != null)       user.setCi(request.getCi());

        return userRepository.save(user);
    }
}
