package com.xpressrides.backend.service;

import java.math.BigDecimal;
import java.time.LocalDateTime;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import com.xpressrides.backend.dto.AuthResponse;
import com.xpressrides.backend.dto.LoginRequest;
import com.xpressrides.backend.dto.RegisterRequest;
import com.xpressrides.backend.model.Chofer;
import com.xpressrides.backend.model.Cliente;
import com.xpressrides.backend.model.PersonalAdmin;
import com.xpressrides.backend.model.Usuario;
import com.xpressrides.backend.repository.ChoferRepository;
import com.xpressrides.backend.repository.ClienteRepository;
import com.xpressrides.backend.repository.PersonalAdminRepository;
import com.xpressrides.backend.repository.UsuarioRepository;

//Servicio de autenticacion para el registro de usuarios
@Service
public class AuthService {

    @Autowired
    private UsuarioRepository usuarioRepository;

    @Autowired
    private ClienteRepository clienteRepository;

    @Autowired
    private ChoferRepository choferRepository;

    @Autowired
    private PersonalAdminRepository personalAdminRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private AuthenticationManager authenticationManager;

    //aqui se reciben todos los datos del registro
    public AuthService(UsuarioRepository usuarioRepository, ClienteRepository clienteRepository,
            ChoferRepository choferRepository, PersonalAdminRepository personalAdminRepository,
            PasswordEncoder passwordEncoder, AuthenticationManager authenticationManager) {
            this.usuarioRepository = usuarioRepository;
            this.clienteRepository = clienteRepository;
            this.choferRepository = choferRepository;
            this.personalAdminRepository = personalAdminRepository;
            this.passwordEncoder = passwordEncoder;
            this.authenticationManager = authenticationManager;
    }

    // aqui se Registra el usuario directamente
    public AuthResponse register(RegisterRequest request) {
        if (usuarioRepository.existsByUsername(request.getUsername())) {
            throw new RuntimeException("El nombre de usuario ya está en uso");
        }

        Usuario usuario = new Usuario();
        usuario.setCi(request.getCi());
        usuario.setName(request.getName());
        usuario.setLastName(request.getLastName());
        usuario.setUsername(request.getUsername());
        usuario.setPassword(passwordEncoder.encode(request.getPassword()));
        usuario.setEmail(request.getEmail());
        usuario.setPhone(request.getPhone());
        usuario.setRole(request.getRole().toLowerCase());
        usuario.setActive(true);
        usuario.setCreatedAt(LocalDateTime.now());
        usuario = usuarioRepository.save(usuario);

        //se le asigna un rol
        switch (usuario.getRole()) {
            case "cliente" -> {
                Cliente cliente = new Cliente();
                cliente.setUserId(usuario);
                cliente.setBalance(BigDecimal.ZERO);
                cliente.setStudent(false);
                cliente.setFirstTripUsed(false);
                cliente.setCreatedAt(LocalDateTime.now());
                clienteRepository.save(cliente);
            }
            case "chofer" -> {
                Chofer chofer = new Chofer();
                chofer.setUsername(usuario);
                chofer.setBalance(BigDecimal.ZERO);
                chofer.setEnabled(false);
                chofer.setAvailable(false);
                chofer.setCreatedAt(LocalDateTime.now());
                choferRepository.save(chofer);
            }
            case "admin", "personal_admin" -> {
                PersonalAdmin admin = new PersonalAdmin();
                admin.setUserId(usuario);
                admin.setCreatedAt(LocalDateTime.now());
                personalAdminRepository.save(admin);
            }
        }

        //devovemos el registro
        return new AuthResponse(usuario.getUsername(), usuario.getRole(), "Registro exitoso");
    }

    //Inicio de Sesion
    public AuthResponse login(LoginRequest request) {
        //se le pide solamente usuario y contraseña
        authenticationManager.authenticate(
            new UsernamePasswordAuthenticationToken(request.getUsername(), request.getPassword()));
        
        //se busca el usuario
        Usuario usuario = usuarioRepository.findByUsername(request.getUsername())
            .orElseThrow(() -> new RuntimeException("Usuario no encontrado"));
        //Inicia la sesion
        return new AuthResponse(usuario.getUsername(), usuario.getRole(), "Inicio de sesión exitoso");
    }
}
