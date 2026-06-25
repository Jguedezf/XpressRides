package com.xpressrides.backend.service;

import java.time.LocalDateTime;
import java.util.List;

import org.springframework.stereotype.Service;

import com.xpressrides.backend.dto.request.EmergencyContactRequest;
import com.xpressrides.backend.exception.ResourceNotFoundException;
import com.xpressrides.backend.model.Driver;
import com.xpressrides.backend.model.EmergencyContact;
import com.xpressrides.backend.repository.DriverRepository;
import com.xpressrides.backend.repository.EmergencyContactRepository;

@Service
public class EmergencyContactService {

    private final EmergencyContactRepository emergencyContactRepository;
    private final DriverRepository driverRepository;

    public EmergencyContactService(EmergencyContactRepository emergencyContactRepository,
            DriverRepository driverRepository) {
        this.emergencyContactRepository = emergencyContactRepository;
        this.driverRepository = driverRepository;
    }

    public EmergencyContact create(EmergencyContactRequest request) {
        Driver driver = driverRepository.findById(request.getDriverId())
            .orElseThrow(() -> new ResourceNotFoundException("Chofer no encontrado"));

        EmergencyContact contact = new EmergencyContact();
        contact.setDriver(driver);
        contact.setName(request.getName());
        contact.setPhone(request.getPhone());
        contact.setRelationship(request.getRelationship());
        contact.setCreatedAt(LocalDateTime.now());

        return emergencyContactRepository.save(contact);
    }

    public List<EmergencyContact> listByDriver(Integer driverId) {
        return emergencyContactRepository.findByDriver_Id(driverId);
    }

    public Driver findDriverByUsername(String username) {
        return driverRepository.findByUsername_Username(username)
            .orElseThrow(() -> new ResourceNotFoundException("Chofer no encontrado"));
    }
}
