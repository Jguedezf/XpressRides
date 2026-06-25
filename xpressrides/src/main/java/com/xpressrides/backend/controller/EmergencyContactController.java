package com.xpressrides.backend.controller;

import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.xpressrides.backend.dto.request.EmergencyContactRequest;
import com.xpressrides.backend.model.Driver;
import com.xpressrides.backend.model.EmergencyContact;
import com.xpressrides.backend.service.EmergencyContactService;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/emergencias")
public class EmergencyContactController {

    private final EmergencyContactService emergencyContactService;

    public EmergencyContactController(EmergencyContactService emergencyContactService) {
        this.emergencyContactService = emergencyContactService;
    }

    @PreAuthorize("hasRole('chofer')")
    @PostMapping
    public ResponseEntity<EmergencyContact> create(@Valid @RequestBody EmergencyContactRequest request) {
        EmergencyContact contact = emergencyContactService.create(request);
        return ResponseEntity.ok(contact);
    }

    @PreAuthorize("hasRole('chofer')")
    @GetMapping
    public ResponseEntity<List<EmergencyContact>> list(Authentication authentication) {
        Driver driver = emergencyContactService.findDriverByUsername(authentication.getName());
        List<EmergencyContact> contacts = emergencyContactService.listByDriver(driver.getId());
        return ResponseEntity.ok(contacts);
    }
}
