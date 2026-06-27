package com.xpressrides.backend.service;

import com.xpressrides.backend.model.AdminPersonnel;
import com.xpressrides.backend.model.Customer;
import com.xpressrides.backend.model.Driver;
import com.xpressrides.backend.model.Trip;
import com.xpressrides.backend.model.User;
import com.xpressrides.backend.repository.AdminPersonnelRepository;
import com.xpressrides.backend.repository.CustomerRepository;
import com.xpressrides.backend.repository.DriverRepository;
import com.xpressrides.backend.repository.TripRepository;
import com.xpressrides.backend.repository.UserRepository;
import com.xpressrides.backend.exception.ResourceNotFoundException;
import java.util.HashMap;
import java.util.Map;
import org.springframework.stereotype.Service;

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

    public AdminService(DriverRepository driverRepository,
                        CustomerRepository customerRepository,
                        TripRepository tripRepository,
                        UserRepository userRepository,
                        AdminPersonnelRepository adminPersonnelRepository) {
        this.driverRepository        = driverRepository;
        this.customerRepository      = customerRepository;
        this.tripRepository          = tripRepository;
        this.userRepository          = userRepository;
        this.adminPersonnelRepository = adminPersonnelRepository;
    }

    // Retorna todos los choferes con su estado operativo
    public List<Map<String, Object>> getAllDrivers() {
        return driverRepository.findAll().stream().map(d -> {
            Map<String, Object> item = new HashMap<>();
            item.put("id", d.getId());
            item.put("nombre", d.getUsername().getName());
            item.put("apellido", d.getUsername().getLastName());
            item.put("username", d.getUsername().getUsername());
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
            item.put("nombre", c.getUserId().getName());
            item.put("apellido", c.getUserId().getLastName());
            item.put("username", c.getUserId().getUsername());
            item.put("saldoUsd", c.getBalance());
            item.put("esEstudiante", c.isStudent());
            item.put("primerViajeUsado", c.isFirstTripUsed());
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
            item.put("zonaOrigen", t.getOriginZone() != null ? t.getOriginZone().getName() : null);
            item.put("zonaDestino", t.getDestinationZone() != null ? t.getDestinationZone().getName() : null);
            item.put("costoClienteUsd", t.getCustomerCostUsd());
            item.put("fechaSolicitud", t.getRequestDate());
            return item;
        }).collect(Collectors.toList());
    }
}
