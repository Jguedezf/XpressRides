package com.xpressrides.backend.service;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.xpressrides.backend.dto.request.CustomerProfileRequest;
import com.xpressrides.backend.dto.request.RatingRequest;
import com.xpressrides.backend.dto.response.CustomerProfileResponse;
import com.xpressrides.backend.exception.BadRequestException;
import com.xpressrides.backend.exception.ResourceNotFoundException;
import com.xpressrides.backend.model.Customer;
import com.xpressrides.backend.model.CustomerCoupon;
import com.xpressrides.backend.model.Driver;
import com.xpressrides.backend.model.Notification;
import com.xpressrides.backend.model.Trip;
import com.xpressrides.backend.model.User;
import com.xpressrides.backend.model.TopUp;
import com.xpressrides.backend.model.Vehicle;
import com.xpressrides.backend.repository.CustomerCouponRepository;
import com.xpressrides.backend.repository.CustomerRepository;
import com.xpressrides.backend.repository.DriverRepository;
import com.xpressrides.backend.repository.NotificationRepository;
import com.xpressrides.backend.repository.TopUpRepository;
import com.xpressrides.backend.repository.TripRepository;
import com.xpressrides.backend.repository.UserRepository;

@Service
public class CustomerService {

    private final CustomerRepository customerRepository;
    private final UserRepository userRepository;
    private final TripRepository tripRepository;
    private final CustomerCouponRepository customerCouponRepository;
    private final TopUpRepository topUpRepository;
    private final DriverRepository driverRepository;
    private final NotificationRepository notificationRepository;

    public CustomerService(CustomerRepository customerRepository,
                           UserRepository userRepository,
                           TripRepository tripRepository,
                           CustomerCouponRepository customerCouponRepository,
                           TopUpRepository topUpRepository,
                           DriverRepository driverRepository,
                           NotificationRepository notificationRepository) {
        this.customerRepository      = customerRepository;
        this.userRepository          = userRepository;
        this.tripRepository          = tripRepository;
        this.customerCouponRepository = customerCouponRepository;
        this.topUpRepository         = topUpRepository;
        this.driverRepository        = driverRepository;
        this.notificationRepository  = notificationRepository;
    }

    public CustomerProfileResponse getProfile(String username) {
        Customer customer = customerRepository.findByUserId_Username(username)
            .orElseThrow(() -> new ResourceNotFoundException("Cliente no encontrado"));
        return mapToProfileResponse(customer);
    }

    @Transactional
    public CustomerProfileResponse updateProfile(String username, CustomerProfileRequest request) {
        Customer customer = customerRepository.findByUserId_Username(username)
            .orElseThrow(() -> new ResourceNotFoundException("Cliente no encontrado"));
        User user = customer.getUserId();

        if (request.getName() != null) user.setName(request.getName());
        if (request.getLastName() != null) user.setLastName(request.getLastName());
        if (request.getEmail() != null) user.setEmail(request.getEmail());
        if (request.getPhone() != null) user.setPhone(request.getPhone());
        if (request.getIsStudent() != null) customer.setStudent(request.getIsStudent());

        userRepository.save(user);
        customerRepository.save(customer);
        return mapToProfileResponse(customer);
    }

    public List<Trip> getTrips(String username) {
        Customer customer = customerRepository.findByUserId_Username(username)
            .orElseThrow(() -> new ResourceNotFoundException("Cliente no encontrado"));
        return tripRepository.findByCustomer_IdOrderByRequestDateDesc(customer.getId());
    }

    public Trip getTripDetail(String username, Integer tripId) {
        Customer customer = customerRepository.findByUserId_Username(username)
            .orElseThrow(() -> new ResourceNotFoundException("Cliente no encontrado"));
        return tripRepository.findByIdAndCustomer_Id(tripId, customer.getId())
            .orElseThrow(() -> new ResourceNotFoundException("Traslado no encontrado"));
    }

    @Transactional
    public void rateTrip(String username, Integer tripId, RatingRequest request) {
        Customer customer = customerRepository.findByUserId_Username(username)
            .orElseThrow(() -> new ResourceNotFoundException("Cliente no encontrado"));
        Trip trip = tripRepository.findByIdAndCustomer_Id(tripId, customer.getId())
            .orElseThrow(() -> new ResourceNotFoundException("Traslado no encontrado"));

        if (!"completado".equals(trip.getStatus())) {
            throw new BadRequestException("Solo se puede calificar un viaje completado");
        }
        if (trip.getStarRating() != null) {
            throw new BadRequestException("Este viaje ya fue calificado");
        }

        trip.setStarRating(request.getStarRating());
        trip.setCustomerComment(request.getCustomerComment());
        tripRepository.save(trip);
    }

    @Transactional
    public void cancelTrip(String username, Integer tripId, String reason) {
        Customer customer = customerRepository.findByUserId_Username(username)
            .orElseThrow(() -> new ResourceNotFoundException("Cliente no encontrado"));
        Trip trip = tripRepository.findByIdAndCustomer_Id(tripId, customer.getId())
            .orElseThrow(() -> new ResourceNotFoundException("Traslado no encontrado"));

        if (!"solicitado".equals(trip.getStatus()) && !"aceptado".equals(trip.getStatus())) {
            throw new BadRequestException("Solo se puede cancelar un viaje solicitado o aceptado");
        }

        trip.setStatus("cancelado");
        trip.setCancelledBy("cliente");
        trip.setCancellationReason(reason);
        tripRepository.save(trip);

        if (trip.getDriver() != null) {
            Driver driver = trip.getDriver();
            driver.setAvailable(true);
            driverRepository.save(driver);

            Notification notif = new Notification();
            notif.setUser(driver.getUsername());
            notif.setTrip(trip);
            notif.setType("viaje_cancelado");
            notif.setMessage("El cliente canceló el viaje. Estás disponible para nuevos traslados.");
            notif.setRead(false);
            notif.setDateTime(LocalDateTime.now());
            notificationRepository.save(notif);
        }
    }

    public List<TopUp> getTopUps(String username) {
        Customer customer = customerRepository.findByUserId_Username(username)
            .orElseThrow(() -> new ResourceNotFoundException("Cliente no encontrado"));
        return topUpRepository.findByCustomerIdOrderByDateTimeDesc(customer.getId());
    }

    public List<CustomerCoupon> getCoupons(String username) {
        Customer customer = customerRepository.findByUserId_Username(username)
            .orElseThrow(() -> new ResourceNotFoundException("Cliente no encontrado"));
        return customerCouponRepository.findByCustomer_IdAndUsedFalse(customer.getId());
    }

    @Transactional(readOnly = true)
    public Map<String, Object> getActiveTrip(String username) {
        Customer customer = customerRepository.findByUserId_Username(username)
            .orElseThrow(() -> new ResourceNotFoundException("Cliente no encontrado"));

        List<String> activeStatuses = List.of(
            "solicitado", "aceptado", "en_camino", "chofer_llego", "en_progreso"
        );
        Optional<Trip> tripOpt = tripRepository
            .findFirstByCustomer_IdAndStatusInOrderByRequestDateDesc(
                customer.getId(), activeStatuses);

        if (tripOpt.isEmpty()) {
            return null;
        }

        Trip trip = tripOpt.get();
        Driver driver = trip.getDriver();

        Map<String, Object> choferData = null;
        if (driver != null) {
            User driverUser = driver.getUsername();
            Vehicle vehicle = trip.getVehicle();
            choferData = new HashMap<>();
            choferData.put("nombre", driverUser.getName() + " " + driverUser.getLastName());
            choferData.put("telefono", driverUser.getPhone());
            choferData.put("vehiculo", vehicle.getBrand() + " " + vehicle.getModel() + " " + vehicle.getYear());
            choferData.put("placa", vehicle.getPlate());
            choferData.put("color", vehicle.getColor());
        }

        Map<String, Object> data = new HashMap<>();
        data.put("idTraslado", trip.getId());
        data.put("estado", trip.getStatus());
        data.put("origen", trip.getOriginZone().getName());
        data.put("destino", trip.getDestinationZone().getName());
        data.put("costoEstimadoUsd", trip.getCustomerCostUsd());
        data.put("costoEstimadoVes", trip.getCustomerCostVes());
        data.put("chofer", choferData);
        data.put("tiempoEstimadoLlegadaMinutos", trip.getEtaMinutes() != null ? trip.getEtaMinutes() : 8);
        data.put("fechaSolicitud", trip.getRequestDate());
        data.put("fechaAceptacion", trip.getAcceptanceDate());

        return data;
    }

    private CustomerProfileResponse mapToProfileResponse(Customer customer) {
        User user = customer.getUserId();
        CustomerProfileResponse response = new CustomerProfileResponse();
        response.setId(customer.getId());
        response.setCi(user.getCi());
        response.setName(user.getName());
        response.setLastName(user.getLastName());
        response.setUsername(user.getUsername());
        response.setEmail(user.getEmail());
        response.setPhone(user.getPhone());
        response.setBalance(customer.getBalance());
        response.setStudent(customer.isStudent());
        response.setFirstTripUsed(customer.isFirstTripUsed());
        return response;
    }
}
