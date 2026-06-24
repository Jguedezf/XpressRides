package com.xpressrides.backend.service;

import java.time.LocalDateTime;

import org.springframework.stereotype.Service;

import com.xpressrides.backend.dto.VehicleInspectionDTO;
import com.xpressrides.backend.dto.VehicleRequest;
import com.xpressrides.backend.dto.VehicleResponse;
import com.xpressrides.backend.model.Driver;
import com.xpressrides.backend.model.Vehicle;
import com.xpressrides.backend.model.VehicleInspection;
import com.xpressrides.backend.repository.DriverRepository;
import com.xpressrides.backend.repository.VehicleInspectionRepository;
import com.xpressrides.backend.repository.VehicleRepository;

@Service
public class VehicleService {

    private VehicleRepository vehicleRepository;
    private DriverRepository driverRepository;
    private VehicleInspectionRepository vehicleInspectionRepository;
    

    public VehicleService(VehicleRepository vehicleRepository, DriverRepository driverRepository,
            VehicleInspectionRepository vehicleInspectionRepository) {
        this.vehicleRepository = vehicleRepository;
        this.driverRepository = driverRepository;
        this.vehicleInspectionRepository = vehicleInspectionRepository;
    }

    public VehicleResponse registerVehicle(VehicleRequest request, String username){
      
        if(vehicleRepository.existsByPlate(request.getPlate())){
            throw new RuntimeException("Esta placa ya esta registrada");
        }
        
        Driver driver= driverRepository.findById(request.getDriverId()).orElseThrow(() -> new RuntimeException("Chofer no encontrado"));

        Vehicle vehicle = new Vehicle();
        vehicle.setDriver(driver);
        vehicle.setPlate(request.getPlate());
        vehicle.setBrand(request.getBrand());
        vehicle.setModel(request.getModel());
        vehicle.setYear(request.getYear());
        vehicle.setColor(request.getColor());
        vehicle.setActive(true);
        vehicle.setCreatedAt(LocalDateTime.now());

        vehicle = vehicleRepository.save(vehicle);

        return mapToResponse(vehicle);
    }

    private VehicleResponse mapToResponse(Vehicle vehicle) {
        VehicleResponse response = new VehicleResponse();
        response.setId(vehicle.getId());
        response.setDriverId(vehicle.getDriver().getId());
        response.setPlate(vehicle.getPlate());
        response.setBrand(vehicle.getBrand());
        response.setModel(vehicle.getModel());
        response.setYear(vehicle.getYear());
        response.setColor(vehicle.getColor());
        response.setActive(vehicle.getActive());

         // Última inspección (ordenada por fecha descendente, top 1)
        VehicleInspection lastInsp = vehicleInspectionRepository.findFirstByVehicleIdOrderByInspectionDateDesc(vehicle.getId()).orElseThrow(()-> new RuntimeException("No se encontro ninguna inspeccion"));
        if (lastInsp != null) {
            VehicleInspectionDTO dto = new VehicleInspectionDTO();
            dto.setId(lastInsp.getId());
            dto.setInspectionDate(lastInsp.getInspectionDate());
            dto.setScore(lastInsp.getScore());
            dto.setObservation(lastInsp.getObservation());
            dto.setFitForUse(lastInsp.isFitForUse());
            dto.setNextInspectionDate(lastInsp.getNextInspectionDate());
            response.setLastInspection(dto);
        }

        return response;
    }
}


