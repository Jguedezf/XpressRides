package com.xpressrides.backend.service;

import com.xpressrides.backend.dto.request.AdminPersonnelRequest;
import com.xpressrides.backend.exception.BadRequestException;
import com.xpressrides.backend.model.AdminPersonnel;
import com.xpressrides.backend.model.Customer;
import com.xpressrides.backend.model.Driver;
import com.xpressrides.backend.model.PsychologicalEvaluation;
import com.xpressrides.backend.model.Trip;
import com.xpressrides.backend.model.User;
import com.xpressrides.backend.model.Vehicle;
import com.xpressrides.backend.model.VehicleInspection;
import com.xpressrides.backend.repository.AdminPersonnelRepository;
import com.xpressrides.backend.repository.CustomerRepository;
import com.xpressrides.backend.repository.DriverRepository;
import com.xpressrides.backend.repository.TripRepository;
import com.xpressrides.backend.repository.UserRepository;
import com.xpressrides.backend.repository.VehicleRepository;
import com.xpressrides.backend.exception.ResourceNotFoundException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
public class AdminService {

    private final DriverRepository driverRepository;
    private final CustomerRepository customerRepository;
    private final TripRepository tripRepository;
    private final UserRepository userRepository;
    private final AdminPersonnelRepository adminPersonnelRepository;
    private final VehicleRepository vehicleRepository;
    private final DriverRegistrationService driverRegistrationService;
    private final PasswordEncoder passwordEncoder;

    public AdminService(DriverRepository driverRepository,
                        CustomerRepository customerRepository,
                        TripRepository tripRepository,
                        UserRepository userRepository,
                        AdminPersonnelRepository adminPersonnelRepository,
                        VehicleRepository vehicleRepository,
                        DriverRegistrationService driverRegistrationService,
                        PasswordEncoder passwordEncoder) {
        this.driverRepository          = driverRepository;
        this.customerRepository        = customerRepository;
        this.tripRepository            = tripRepository;
        this.userRepository            = userRepository;
        this.adminPersonnelRepository  = adminPersonnelRepository;
        this.vehicleRepository         = vehicleRepository;
        this.driverRegistrationService = driverRegistrationService;
        this.passwordEncoder           = passwordEncoder;
    }

    // Alta de personal administrativo desde el panel de admin — ruta separada del
    // registro público (AuthService.register() la bloquea a propósito, ver
    // commit 152c5d1). Solo alcanzable vía POST /api/admin/personal-admin,
    // protegido con @PreAuthorize hasRole('administrador') únicamente.
    public User crearPersonalAdmin(AdminPersonnelRequest request, String creatorUsername) {
        if (userRepository.existsByUsername(request.getUsername())) {
            throw new BadRequestException("El nombre de usuario ya está en uso");
        }

        User creator = null;
        if (creatorUsername != null) {
            creator = userRepository.findByUsername(creatorUsername).orElse(null);
        }

        User user = new User();
        user.setCi(request.getCi());
        user.setName(request.getName());
        user.setLastName(request.getLastName());
        user.setUsername(request.getUsername());
        user.setPassword(passwordEncoder.encode(request.getPassword()));
        user.setEmail(request.getEmail());
        user.setPhone(request.getPhone());
        user.setRole("personal_admin");
        user.setActive(true);
        user.setCreatedAt(LocalDateTime.now());
        user = userRepository.save(user);

        String cargo = request.getPosition() != null && !request.getPosition().isBlank()
            ? request.getPosition() : "Empleado Administrativo";
        AdminPersonnel admin = new AdminPersonnel();
        admin.setUserId(user);
        admin.setPosition(cargo);
        admin.setCreatedBy(creator);
        admin.setCreatedAt(LocalDateTime.now());
        adminPersonnelRepository.save(admin);

        return user;
    }

    // Retorna todos los administradores y personal_admin
    public List<Map<String, Object>> getAllAdmins() {
        return adminPersonnelRepository.findAll().stream().map(ap -> {
            Map<String, Object> item = new HashMap<>();
            item.put("id", ap.getId());
            item.put("usuarioId", ap.getUserId().getId());
            item.put("nombre", ap.getUserId().getName());
            item.put("apellido", ap.getUserId().getLastName());
            item.put("username", ap.getUserId().getUsername());
            item.put("ci", ap.getUserId().getCi());
            item.put("telefono", ap.getUserId().getPhone());
            item.put("correo", ap.getUserId().getEmail());
            item.put("cargo", ap.getPosition());
            item.put("rol", ap.getUserId().getRole()); // administrador o personal_admin
            item.put("creadoEn", ap.getCreatedAt());
            if (ap.getCreatedBy() != null) {
                item.put("creadoPor", ap.getCreatedBy().getName() + " " + ap.getCreatedBy().getLastName());
            } else {
                item.put("creadoPor", "Fundador (Sistema)");
            }
            return item;
        }).collect(Collectors.toList());
    }

    // Retorna todos los choferes con su estado operativo
    @Transactional
    public List<Map<String, Object>> getAllDrivers() {
        return driverRepository.findAll().stream().map(d -> {
            boolean hasActiveVehicle = vehicleRepository.findByDriver_IdAndInUseTrue(d.getId()).isPresent();
            
            // Auto-corrección en BD: si no tiene vehículo activo, NO puede estar disponible.
            if (d.isAvailable() && !hasActiveVehicle) {
                d.setAvailable(false);
                driverRepository.save(d);
            }

            Map<String, Object> item = new HashMap<>();
            item.put("id", d.getId());
            item.put("usuarioId", d.getUsername().getId());
            item.put("nombre", d.getUsername().getName());
            item.put("apellido", d.getUsername().getLastName());
            item.put("username", d.getUsername().getUsername());
            item.put("ci", d.getUsername().getCi());
            item.put("telefono", d.getUsername().getPhone());
            item.put("correo", d.getUsername().getEmail());
            item.put("habilitado", d.isEnabled());
            item.put("disponible", d.isAvailable());
            item.put("banco", d.getBank() != null ? d.getBank().getName() : null);
            item.put("numeroCuenta", d.getAccountNumber());
            item.put("saldoAcumuladoUsd", d.getBalance());
            return item;
        }).collect(Collectors.toList());
    }

    // Retorna todos los clientes con su estado financiero
    public List<Map<String, Object>> getAllCustomers() {
        return customerRepository.findAll().stream().map(c -> {
            Map<String, Object> item = new HashMap<>();
            item.put("id", c.getId());
            item.put("usuarioId", c.getUserId().getId());
            item.put("nombre", c.getUserId().getName());
            item.put("apellido", c.getUserId().getLastName());
            item.put("username", c.getUserId().getUsername());
            item.put("ci", c.getUserId().getCi());
            item.put("telefono", c.getUserId().getPhone());
            item.put("correo", c.getUserId().getEmail());
            long existingTrips = tripRepository.countByCustomer_Id(c.getId());
            item.put("saldoUsd", c.getBalance());
            item.put("esEstudiante", c.isStudent());
            item.put("primerViajeUsado", c.isFirstTripUsed() || existingTrips > 0);
            return item;
        }).collect(Collectors.toList());
    }

    // Perfil del usuario autenticado (admin o personal_admin)
    public Map<String, Object> getProfile(String username) {
        User user = userRepository.findByUsername(username)
            .orElseThrow(() -> new ResourceNotFoundException("Usuario no encontrado"));

        Map<String, Object> profile = new HashMap<>();
        profile.put("nombre", user.getName());
        profile.put("apellido", user.getLastName());
        profile.put("cedula", user.getCi());
        profile.put("username", user.getUsername());
        profile.put("email", user.getEmail());
        profile.put("telefono", user.getPhone());
        profile.put("rol", user.getRole());

        if ("personal_admin".equals(user.getRole())) {
            adminPersonnelRepository.findByUserId_Username(username)
                .ifPresent(ap -> profile.put("cargo", ap.getPosition()));
        }
        return profile;
    }

    // Registra evaluación psicológica y revisión vehicular para un chofer en un solo paso
    @Transactional
    public void evaluarChofer(Integer driverId, BigDecimal notaPsicologica, BigDecimal notaVehicular, String obsPsicologica, String obsVehicular, String adminUsername) {
        AdminPersonnel admin = adminPersonnelRepository.findByUserId_Username(adminUsername)
            .orElseThrow(() -> new ResourceNotFoundException("Personal administrativo no encontrado"));

        Driver driver = driverRepository.findById(driverId)
            .orElseThrow(() -> new ResourceNotFoundException("Chofer no encontrado"));

        PsychologicalEvaluation eval = new PsychologicalEvaluation();
        eval.setDriver(driver);
        eval.setAdmin(admin);
        eval.setScore(notaPsicologica);
        eval.setObservation(obsPsicologica);
        eval.setEvaluationDate(LocalDate.now());
        driverRegistrationService.registerPsychologicalEvaluation(eval);

        Vehicle vehicle = vehicleRepository.findByDriver_IdAndInUseTrue(driverId)
            .orElseThrow(() -> new ResourceNotFoundException("El chofer no tiene un vehículo en uso registrado"));
        VehicleInspection inspection = new VehicleInspection();
        inspection.setVehicle(vehicle);
        inspection.setAdmin(admin);
        inspection.setScore(notaVehicular);
        inspection.setObservation(obsVehicular);
        inspection.setInspectionDate(LocalDate.now());
        driverRegistrationService.registerVehicleInspection(inspection);
    }

    // Retorna traslados en estados activos (no finalizados)
    public List<Map<String, Object>> getActiveTrips() {
        List<String> activeStatuses = List.of(
            "solicitado", "aceptado", "en_camino", "chofer_llego", "en_progreso"
        );
        return tripRepository.findByStatusIn(activeStatuses).stream().map(t -> {
            Map<String, Object> item = new HashMap<>();
            item.put("id", t.getId());
            item.put("estado", t.getStatus());
            item.put("cliente", t.getCustomer() != null
                ? t.getCustomer().getUserId().getName() + " " + t.getCustomer().getUserId().getLastName()
                : null);
            item.put("chofer", t.getDriver() != null
                ? t.getDriver().getUsername().getName() + " " + t.getDriver().getUsername().getLastName()
                : null);
            item.put("zonaOrigen", t.getOriginZone() != null ? t.getOriginZone().getName() : t.getOriginAddress());
            item.put("zonaDestino", t.getDestinationZone() != null ? t.getDestinationZone().getName() : t.getDestinationAddress());
            item.put("costoClienteUsd", t.getCustomerCostUsd());
            item.put("fechaSolicitud", t.getRequestDate());
            return item;
        }).collect(Collectors.toList());
    }

    public void updateUserAdmin(Integer id, com.xpressrides.backend.dto.request.UserUpdateRequest request, String adminUsername) {
        User targetUser = userRepository.findById(id).orElseThrow(() -> new RuntimeException("Usuario no encontrado con ID: " + id));
        User adminUser = userRepository.findByUsername(adminUsername).orElseThrow(() -> new RuntimeException("Administrador no encontrado"));

        String adminRole = adminUser.getRole();
        String targetRole = targetUser.getRole();

        if (adminRole.equals("personal_admin")) {
            if (targetRole.equals("administrador") || targetRole.equals("personal_admin")) {
                throw new org.springframework.security.access.AccessDeniedException("El personal administrativo no puede modificar a administradores u otro personal");
            }
        } else if (adminRole.equals("administrador")) {
            if (targetRole.equals("administrador") && !targetUser.getId().equals(adminUser.getId())) {
                throw new org.springframework.security.access.AccessDeniedException("Un administrador no puede modificar a otro administrador");
            }
        }

        if (request.getName() != null) targetUser.setName(request.getName());
        if (request.getLastName() != null) targetUser.setLastName(request.getLastName());
        if (request.getEmail() != null) targetUser.setEmail(request.getEmail());
        if (request.getPhone() != null) targetUser.setPhone(request.getPhone());
        if (request.getCi() != null) targetUser.setCi(request.getCi());
        
        if (request.getUsername() != null && !request.getUsername().isBlank()) {
            String newUsername = request.getUsername().trim();
            if (!newUsername.equals(targetUser.getUsername())) {
                if (userRepository.findByUsername(newUsername).isPresent()) {
                    throw new RuntimeException("El nombre de usuario ya está en uso");
                }
                targetUser.setUsername(newUsername);
            }
        }
        
        if (request.getPassword() != null && !request.getPassword().isBlank()) {
            targetUser.setPassword(passwordEncoder.encode(request.getPassword()));
        }

        userRepository.save(targetUser);
    }

    public void deleteUserAdmin(Integer id, String adminUsername) {
        User targetUser = userRepository.findById(id).orElseThrow(() -> new RuntimeException("Usuario no encontrado con ID: " + id));
        User adminUser = userRepository.findByUsername(adminUsername).orElseThrow(() -> new RuntimeException("Administrador no encontrado"));

        String adminRole = adminUser.getRole();
        String targetRole = targetUser.getRole();

        if (adminRole.equals("personal_admin")) {
            if (targetRole.equals("administrador") || targetRole.equals("personal_admin")) {
                throw new org.springframework.security.access.AccessDeniedException("El personal administrativo no puede eliminar a administradores u otro personal");
            }
        } else if (adminRole.equals("administrador")) {
            if (targetRole.equals("administrador")) {
                throw new org.springframework.security.access.AccessDeniedException("Un administrador no puede eliminar a otro administrador");
            }
        }

        userRepository.delete(targetUser);
    }
}
