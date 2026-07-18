package com.xpressrides.backend.controller;

import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.xpressrides.backend.dto.VehicleInspectionDTO;
import com.xpressrides.backend.dto.request.InspectionRequest;
import com.xpressrides.backend.dto.request.VehicleRequest;
import com.xpressrides.backend.dto.response.VehicleResponse;
import com.xpressrides.backend.service.VehicleService;

import jakarta.validation.Valid;

import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;

import com.xpressrides.backend.model.Driver;
import com.xpressrides.backend.repository.DriverRepository;


@RestController
@RequestMapping("/api/vehiculo")
public class VehicleController {

    private final VehicleService vehicleService;
    private final DriverRepository driverRepository;

    public VehicleController(VehicleService vehicleService, DriverRepository driverRepository) {
        this.vehicleService = vehicleService;
        this.driverRepository = driverRepository;
    }

    // POST /api/vehiculo/registrar — chofer registra un vehículo (puede tener varios)
    @PreAuthorize("hasRole('chofer')")
    @PostMapping("/registrar")
    public ResponseEntity<VehicleResponse> register(@Valid @RequestBody VehicleRequest request) {
        VehicleResponse response = vehicleService.registerVehicle(request);
        return ResponseEntity.ok(response);
    }

    // PUT /api/vehiculo/{id}/activar — chofer marca cuál de sus vehículos usa para traslados
    @PreAuthorize("hasRole('chofer')")
    @PutMapping("/{id}/activar")
    public ResponseEntity<VehicleResponse> activar(@PathVariable Integer id, Authentication authentication) {
        Driver driver = driverRepository.findByUsername_Username(authentication.getName())
            .orElseThrow(() -> new com.xpressrides.backend.exception.ResourceNotFoundException("Chofer no encontrado"));
        VehicleResponse response = vehicleService.activarVehiculo(id, driver.getId());
        return ResponseEntity.ok(response);
    }

    // POST /api/vehiculo/revision — admin registra revisión vehicular
    @PreAuthorize("hasRole('administrador') or hasRole('personal_admin')")
    @PostMapping("/revision")
    public ResponseEntity<VehicleInspectionDTO> revision(@RequestBody InspectionRequest request) {
        VehicleInspectionDTO response = vehicleService.createInspection(request);
        return ResponseEntity.ok(response);
    }

}
