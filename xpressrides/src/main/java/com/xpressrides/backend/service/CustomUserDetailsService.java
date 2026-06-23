package com.xpressrides.backend.service;

import java.util.List;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;

import com.xpressrides.backend.model.Usuario;
import com.xpressrides.backend.repository.UsuarioRepository;

@Service
public class CustomUserDetailsService implements UserDetailsService {

    @Autowired
    private UsuarioRepository usuarioRepository;

    //Verificacion de seguridad si el usuario existe
    @Override
    public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {
        Usuario usuario = usuarioRepository.findByUsername(username)
            .orElseThrow(() -> new UsernameNotFoundException("Usuario no encontrado: " + username));

        SimpleGrantedAuthority authority = new SimpleGrantedAuthority("ROLE_" + usuario.getRole().toUpperCase());

        return new User(usuario.getUsername(), usuario.getPassword(),
            usuario.getActive(), true, true, true,
            List.of(authority));
    }
}
