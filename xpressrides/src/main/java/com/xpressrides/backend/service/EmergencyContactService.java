package com.xpressrides.backend.service;

import java.time.LocalDateTime;
import java.util.List;

import org.springframework.stereotype.Service;

import com.xpressrides.backend.dto.request.EmergencyContactRequest;
import com.xpressrides.backend.exception.BadRequestException;
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

    public EmergencyContact update(Integer contactId, Integer driverId, EmergencyContactRequest request) {
        EmergencyContact contact = findOwnedContact(contactId, driverId);

        contact.setName(request.getName());
        contact.setPhone(request.getPhone());
        contact.setRelationship(request.getRelationship());

        return emergencyContactRepository.save(contact);
    }

    public void delete(Integer contactId, Integer driverId) {
        EmergencyContact contact = findOwnedContact(contactId, driverId);

        Driver driver = contact.getDriver();
        if (driver.isEnabled()) {
            long remaining = emergencyContactRepository.countByDriver_Id(driverId) - 1;
            if (remaining < 2) {
                throw new BadRequestException(
                    "No se puede eliminar: el chofer habilitado debe mantener mínimo 2 contactos de emergencia.");
            }
        }

        emergencyContactRepository.delete(contact);
    }

    private EmergencyContact findOwnedContact(Integer contactId, Integer driverId) {
        EmergencyContact contact = emergencyContactRepository.findById(contactId)
            .orElseThrow(() -> new ResourceNotFoundException("Contacto de emergencia no encontrado"));

        if (!contact.getDriver().getId().equals(driverId)) {
            throw new ResourceNotFoundException("Contacto de emergencia no encontrado");
        }

        return contact;
    }

    public Driver findDriverByUsername(String username) {
        return driverRepository.findByUsername_Username(username)
            .orElseThrow(() -> new ResourceNotFoundException("Chofer no encontrado"));
    }
}
