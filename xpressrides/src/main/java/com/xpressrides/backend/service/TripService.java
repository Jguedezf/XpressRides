package com.xpressrides.backend.service;

import org.springframework.stereotype.Service;

import com.xpressrides.backend.dto.request.TripRequest;
import com.xpressrides.backend.dto.response.TripResponse;
import com.xpressrides.backend.dto.response.TripResponse.Car;
import com.xpressrides.backend.dto.response.TripResponse.Data;
import com.xpressrides.backend.dto.response.TripResponse.Drive;
import com.xpressrides.backend.exception.ResourceNotFoundException;
import com.xpressrides.backend.model.Customer;
import com.xpressrides.backend.model.Driver;
import com.xpressrides.backend.model.Trip;
import com.xpressrides.backend.model.User;
import com.xpressrides.backend.model.Vehicle;
import com.xpressrides.backend.repository.CustomerRepository;
import com.xpressrides.backend.repository.TripRepository;

import jakarta.persistence.EntityManager;
import jakarta.persistence.ParameterMode;
import jakarta.persistence.PersistenceContext;
import jakarta.persistence.StoredProcedureQuery;

@Service
public class TripService {

    @PersistenceContext
    private EntityManager entityManager;

    private final CustomerRepository customerRepository;
    private final TripRepository tripRepository;

    public TripService(CustomerRepository customerRepository, TripRepository tripRepository) {
        this.customerRepository = customerRepository;
        this.tripRepository = tripRepository;
    }


    public TripResponse solicitarTraslado(TripRequest request, String username) {
        Customer customer = customerRepository.findByUserId_Username(username)
            .orElseThrow(() -> new ResourceNotFoundException("Cliente no encontrado"));

        StoredProcedureQuery query = entityManager.createStoredProcedureQuery("sp_solicitar_traslado");

        query.registerStoredProcedureParameter("p_id_cliente", Integer.class, ParameterMode.IN);
        query.registerStoredProcedureParameter("p_id_zona_origen", Integer.class, ParameterMode.IN);
        query.registerStoredProcedureParameter("p_id_zona_destino", Integer.class, ParameterMode.IN);
        query.registerStoredProcedureParameter("p_origen_direccion", String.class, ParameterMode.IN);
        query.registerStoredProcedureParameter("p_origen_lat", java.math.BigDecimal.class, ParameterMode.IN);
        query.registerStoredProcedureParameter("p_origen_lng", java.math.BigDecimal.class, ParameterMode.IN);
        query.registerStoredProcedureParameter("p_destino_direccion", String.class, ParameterMode.IN);
        query.registerStoredProcedureParameter("p_destino_lat", java.math.BigDecimal.class, ParameterMode.IN);
        query.registerStoredProcedureParameter("p_destino_lng", java.math.BigDecimal.class, ParameterMode.IN);
        query.registerStoredProcedureParameter("p_nro_pasajeros", Integer.class, ParameterMode.IN);
        query.registerStoredProcedureParameter("p_id_cupon_cliente", Integer.class, ParameterMode.IN);
        query.registerStoredProcedureParameter("p_id_traslado", Integer.class, ParameterMode.OUT);
        query.registerStoredProcedureParameter("p_mensaje", String.class, ParameterMode.OUT);

        query.setParameter("p_id_cliente", customer.getId());
        query.setParameter("p_id_zona_origen", request.getIdZoneOrigin());
        query.setParameter("p_id_zona_destino", request.getIdZoneDestiny());
        query.setParameter("p_origen_direccion", request.getOriginAddress());
        query.setParameter("p_origen_lat", request.getOriginLat() != null ? java.math.BigDecimal.valueOf(request.getOriginLat()) : null);
        query.setParameter("p_origen_lng", request.getOriginLng() != null ? java.math.BigDecimal.valueOf(request.getOriginLng()) : null);
        query.setParameter("p_destino_direccion", request.getDestinationAddress());
        query.setParameter("p_destino_lat", request.getDestinationLat() != null ? java.math.BigDecimal.valueOf(request.getDestinationLat()) : null);
        query.setParameter("p_destino_lng", request.getDestinationLng() != null ? java.math.BigDecimal.valueOf(request.getDestinationLng()) : null);
        query.setParameter("p_nro_pasajeros", request.getPassengerCount());
        query.setParameter("p_id_cupon_cliente", request.getCustomerCouponId());

        query.execute();

        Integer tripId = (Integer) query.getOutputParameterValue("p_id_traslado");
        String message = (String) query.getOutputParameterValue("p_mensaje");

        TripResponse response = new TripResponse();
        response.setSuccess(tripId != null);
        response.setMessage(message);

        if(tripId != null){
            Trip trip = tripRepository.findById(tripId).orElseThrow(()-> new ResourceNotFoundException("Traslado no encontrado"));

            trip.setCurrentAssignmentDate(java.time.LocalDateTime.now());
            tripRepository.save(trip);

            Data data = new Data();
            data.setTripId(trip.getId());
            data.setState(trip.getStatus());

            Driver driver = trip.getDriver();
            User driverUser = driver.getUsername();
            
            Drive drive = new Drive();
            drive.setName(driverUser.getName()+ " " + driverUser.getLastName());
            drive.setScore(tripRepository.findAverageRatingByDriverId(driver.getId()));
            drive.setPhone(driverUser.getPhone());
            
            Vehicle vehicle = trip.getVehicle();
            Car car = new Car();
            car.setBrand(vehicle.getBrand());
            car.setModel(vehicle.getModel());
            car.setColor(vehicle.getColor());
            car.setPlate(vehicle.getPlate());

            drive.setVehiculo(car);
            data.setDriver(drive);
            response.setData(data);
        }

        return response;
    }
}