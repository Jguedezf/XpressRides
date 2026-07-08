package com.xpressrides.backend.service;

import java.math.BigDecimal;
import java.time.LocalDateTime;

import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import com.xpressrides.backend.dto.request.ChangePasswordRequest;
import com.xpressrides.backend.dto.request.LoginRequest;
import com.xpressrides.backend.dto.request.RefreshTokenRequest;
import com.xpressrides.backend.dto.request.RegisterRequest;
import com.xpressrides.backend.dto.response.AuthResponse;
import com.xpressrides.backend.model.Driver;
import com.xpressrides.backend.model.Customer;
import com.xpressrides.backend.model.AdminPersonnel;
import com.xpressrides.backend.model.Bank;
import com.xpressrides.backend.model.User;
import com.xpressrides.backend.repository.DriverRepository;
import com.xpressrides.backend.repository.CustomerRepository;
import com.xpressrides.backend.repository.AdminPersonnelRepository;
import com.xpressrides.backend.repository.BankRepository;
import com.xpressrides.backend.repository.UserRepository;
import com.xpressrides.backend.security.JwtService;

//Servicio de autenticacion para el registro de usuarios
@Service
public class AuthService {

    private UserRepository userRepository;

    private CustomerRepository customerRepository;

    private DriverRepository driverRepository;

    private AdminPersonnelRepository adminPersonnelRepository;

    private PasswordEncoder passwordEncoder;

    private AuthenticationManager authenticationManager;

    private BankRepository bankRepository;

    private JwtService jwtService;

    //aqui se reciben todos los datos del registro
    public AuthService(UserRepository userRepository, CustomerRepository customerRepository,
            DriverRepository driverRepository, AdminPersonnelRepository adminPersonnelRepository,
            PasswordEncoder passwordEncoder, AuthenticationManager authenticationManager,
            JwtService jwtService, BankRepository bankRepository) {
            this.userRepository = userRepository;
            this.bankRepository = bankRepository;
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
                customer.setStudent(Boolean.TRUE.equals(request.getIsStudent()));
                customer.setFirstTripUsed(false);
                customer.setCreatedAt(LocalDateTime.now());
                customer.setCodigoReferido(generarCodigoReferidoUnico());
                customer.setRecompensaReferidoOtorgada(false);
                customerRepository.save(customer);
            }
            case "chofer" -> {
                if (request.getBankId() == null)
                    throw new RuntimeException("Banco requerido para choferes");
                if (request.getAccountNumber()== null || request.getAccountNumber().isBlank()){
                    throw new RuntimeException("numero de cuenta requerido para choferes");
                }
                Bank bank = bankRepository.findById(request.getBankId())
                    .orElseThrow(()-> new RuntimeException("Banco no encontrado"));
                Driver driver = new Driver();
                driver.setUsername(user);
                driver.setBank(bank);
                driver.setAccountNumber(request.getAccountNumber());
                driver.setBalance(BigDecimal.ZERO);
                driver.setEnabled(false);
                driver.setAvailable(false);
                driver.setCreatedAt(LocalDateTime.now());
                driverRepository.save(driver);
            }
            case "personal_admin" -> {
                String cargo = request.getPosition() != null ? request.getPosition() : "Empleado Administrativo";
                AdminPersonnel admin = new AdminPersonnel();
                admin.setUserId(user);
                admin.setPosition(cargo);
                admin.setCreatedAt(LocalDateTime.now());
                adminPersonnelRepository.save(admin);
            }
        }

        //devovemos el registro
        String accessToken = jwtService.generateToken(user.getUsername());
        String refreshToken = jwtService.generateRefreshToken(user.getUsername());
        return new AuthResponse(user.getUsername(), user.getRole(), accessToken, refreshToken, "Registro exitoso");
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
        String accessToken = jwtService.generateToken(user.getUsername());
        String refreshToken = jwtService.generateRefreshToken(user.getUsername());
        return new AuthResponse(user.getUsername(), user.getRole(), accessToken, refreshToken, "Inicio de sesión exitoso");
    }

    public AuthResponse refresh(RefreshTokenRequest request) {
        String token = request.getRefreshToken();
        if (!jwtService.isRefreshTokenValid(token)) {
            throw new RuntimeException("Refresh token inválido o expirado");
        }
        String username = jwtService.extractUsername(token);
        String newAccess = jwtService.generateToken(username);
        String newRefresh = jwtService.generateRefreshToken(username);
        return new AuthResponse(username, null, newAccess, newRefresh, "Token renovado exitosamente");
    }

    private static final String ALFABETO_CODIGO_REFERIDO = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    private static final int LONGITUD_CODIGO_REFERIDO = 8;

    // Genera el código de referido propio del cliente: aleatorio, no derivado del
    // ID (para no revelar cuántos clientes hay registrados ni hacerlo adivinable),
    // reintentando ante una colisión improbable con un código ya existente.
    private String generarCodigoReferidoUnico() {
        java.util.concurrent.ThreadLocalRandom random = java.util.concurrent.ThreadLocalRandom.current();
        String codigo;
        do {
            StringBuilder sb = new StringBuilder(LONGITUD_CODIGO_REFERIDO);
            for (int i = 0; i < LONGITUD_CODIGO_REFERIDO; i++) {
                sb.append(ALFABETO_CODIGO_REFERIDO.charAt(random.nextInt(ALFABETO_CODIGO_REFERIDO.length())));
            }
            codigo = sb.toString();
        } while (customerRepository.existsByCodigoReferido(codigo));
        return codigo;
    }

    public void changePassword(ChangePasswordRequest request){
        String username = SecurityContextHolder.getContext().getAuthentication().getName();
        User user = userRepository.findByUsername(username).orElseThrow(()-> new RuntimeException("Usuario no encontrado"));

        if(!passwordEncoder.matches(request.getCurrentPassword(), user.getPassword())){
            throw new RuntimeException("La contraseña actual no es correcta");
        }

        user.setPassword(passwordEncoder.encode(request.getNewPassword()));
        userRepository.save(user);
    }
}
