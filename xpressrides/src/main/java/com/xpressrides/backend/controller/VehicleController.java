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
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;


@RestController
@RequestMapping("/api/vehicle")
public class VehicleController {

    private final VehicleService vehicleService;

    public VehicleController(VehicleService vehicleService) {
        this.vehicleService = vehicleService;
    }

    @PreAuthorize("hasRole('chofer')")
    @PostMapping("/register")
    public ResponseEntity<VehicleResponse> register(@Valid @RequestBody VehicleRequest request) {
        VehicleResponse response = vehicleService.registerVehicle(request);
       return ResponseEntity.ok(response);
    }
    
    @PreAuthorize("hasRole('administrador') or hasRole('personal_admin')")
    @PostMapping("/revision")
    public ResponseEntity<VehicleInspectionDTO> revision(@RequestBody InspectionRequest request) {
        VehicleInspectionDTO response = vehicleService.createInspection(request);
        return ResponseEntity.ok(response);
    }
    
}
