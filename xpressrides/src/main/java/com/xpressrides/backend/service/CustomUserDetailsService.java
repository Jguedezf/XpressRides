package com.xpressrides.backend.service;

import java.util.List;

import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;

import com.xpressrides.backend.repository.UserRepository;

@Service
public class CustomUserDetailsService implements UserDetailsService {

    private UserRepository userRepository;

    public CustomUserDetailsService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    //Verificacion de seguridad si el usuario existe
    @Override
    public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {
        com.xpressrides.backend.model.User user = userRepository.findByUsername(username)
            .orElseThrow(() -> new UsernameNotFoundException("Usuario no encontrado: " + username));

        // Avoid IllegalArgumentException or NullPointerException when constructing Spring User.
        // isBlank() also catches empty strings ("") that would bypass validation.
        if (user.getUsername() == null || user.getUsername().isBlank() || user.getPassword() == null || user.getPassword().isBlank()) {
            throw new UsernameNotFoundException("Datos de usuario incompletos para: " + username);
        }

        // Avoid NullPointerException if role is null
        String role = user.getRole() != null ? user.getRole() : "cliente";
        SimpleGrantedAuthority authority = new SimpleGrantedAuthority("ROLE_" + role);

        // Safe unboxing using Boolean.TRUE.equals to avoid NullPointerException
        boolean isActive = Boolean.TRUE.equals(user.getActive());

        return new org.springframework.security.core.userdetails.User(user.getUsername(), user.getPassword(),
            isActive, true, true, true,
            List.of(authority));
    }
}
