package com.xpressrides.backend.repository;

import java.util.List;


import org.hibernate.type.internal.UserTypeSqlTypeAdapter;
import org.springframework.boot.autoconfigure.security.servlet.UserDetailsServiceAutoConfiguration;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.xpressrides.backend.model.Usuario;

@Repository
public interface UsuarioRepository extends JpaRepository<Usuario, Integer> {


    @Override
    public UserDetailsServiceAutoConfiguration loadUserByUsername(String username){
        Usuario user = usuarioRepository.findByUsername(username).orElseThrow(() -> new UsernameNotFoundException("Usuario no encontrado con username: " + username));
        return new User(user.getUsername(), user.getPassword(), getAuthorities(user)); 
    }

    List<Usuario> findByActiveTrueAndRole(String role);
}
