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
import com.xpressrides.backend.model.Driver;
import com.xpressrides.backend.model.Customer;
import com.xpressrides.backend.model.AdminPersonnel;
import com.xpressrides.backend.model.User;
import com.xpressrides.backend.repository.DriverRepository;
import com.xpressrides.backend.repository.CustomerRepository;
import com.xpressrides.backend.repository.AdminPersonnelRepository;
import com.xpressrides.backend.repository.UserRepository;
import com.xpressrides.backend.segurity.JwtService;

//Servicio de autenticacion para el registro de usuarios
@Service
public class AuthService {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private CustomerRepository customerRepository;

    @Autowired
    private DriverRepository driverRepository;

    @Autowired
    private AdminPersonnelRepository adminPersonnelRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private AuthenticationManager authenticationManager;

    @Autowired
    private JwtService jwtService;

    //aqui se reciben todos los datos del registro
    public AuthService(UserRepository userRepository, CustomerRepository customerRepository,
            DriverRepository driverRepository, AdminPersonnelRepository adminPersonnelRepository,
            PasswordEncoder passwordEncoder, AuthenticationManager authenticationManager,
            JwtService jwtService) {
            this.userRepository = userRepository;
            this.customerRepository = customerRepository;
            this.driverRepository = driverRepository;
            this.adminPersonnelRepository = adminPersonnelRepository;
            this.passwordEncoder = passwordEncoder;
            this.authenticationManager = authenticationManager;
            this.jwtService = jwtService;
    }

    // aqui se Registra el usuario directamente
    public AuthResponse register(RegisterRequest request) {
        if (userRepository.existsByUsername(request.getUsername())) {
            throw new RuntimeException("El nombre de usuario ya está en uso");
        }

        User user = new User();
        user.setCi(request.getCi());
        user.setName(request.getName());
        user.setLastName(request.getLastName());
        user.setUsername(request.getUsername());
        user.setPassword(passwordEncoder.encode(request.getPassword()));
        user.setEmail(request.getEmail());
        user.setPhone(request.getPhone());
        user.setRole(request.getRole().toLowerCase());
        user.setActive(true);
        user.setCreatedAt(LocalDateTime.now());
        user = userRepository.save(user);

        //se le asigna un rol
        switch (user.getRole()) {
            case "cliente" -> {
                Customer customer = new Customer();
                customer.setUserId(user);
                customer.setBalance(BigDecimal.ZERO);
                customer.setStudent(false);
                customer.setFirstTripUsed(false);
                customer.setCreatedAt(LocalDateTime.now());
                customerRepository.save(customer);
            }
            case "chofer" -> {
                Driver driver = new Driver();
                driver.setUsername(user);
                driver.setBalance(BigDecimal.ZERO);
                driver.setEnabled(false);
                driver.setAvailable(false);
                driver.setCreatedAt(LocalDateTime.now());
                driverRepository.save(driver);
            }
            case "admin", "personal_admin" -> {
                AdminPersonnel admin = new AdminPersonnel();
                admin.setUserId(user);
                admin.setCreatedAt(LocalDateTime.now());
                adminPersonnelRepository.save(admin);
            }
        }

        //devovemos el registro
        String token = jwtService.generateToken(user.getUsername());
        return new AuthResponse(user.getUsername(), user.getRole(), token, "Registro exitoso");
    }

    //Inicio de Sesion
    public AuthResponse login(LoginRequest request) {
        //se le pide solamente usuario y contraseña
        authenticationManager.authenticate(
            new UsernamePasswordAuthenticationToken(request.getUsername(), request.getPassword()));
        
        //se busca el usuario
        User user = userRepository.findByUsername(request.getUsername())
            .orElseThrow(() -> new RuntimeException("Usuario no encontrado"));
        //Inicia la sesion
        String token = jwtService.generateToken(user.getUsername());
        return new AuthResponse(user.getUsername(), user.getRole(), token, "Inicio de sesión exitoso");
    }
}
