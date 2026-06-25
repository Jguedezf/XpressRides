package com.xpressrides.backend.service;

import java.math.BigDecimal;
import java.util.List;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.xpressrides.backend.dto.request.CustomerProfileRequest;
import com.xpressrides.backend.dto.request.RatingRequest;
import com.xpressrides.backend.dto.response.CustomerProfileResponse;
import com.xpressrides.backend.exception.BadRequestException;
import com.xpressrides.backend.exception.ResourceNotFoundException;
import com.xpressrides.backend.model.Customer;
import com.xpressrides.backend.model.CustomerCoupon;
import com.xpressrides.backend.model.Trip;
import com.xpressrides.backend.model.User;
import com.xpressrides.backend.repository.CustomerCouponRepository;
import com.xpressrides.backend.repository.CustomerRepository;
import com.xpressrides.backend.repository.TripRepository;
import com.xpressrides.backend.repository.UserRepository;

@Service
public class CustomerService {

    private final CustomerRepository customerRepository;
    private final UserRepository userRepository;
    private final TripRepository tripRepository;
    private final CustomerCouponRepository customerCouponRepository;

    public CustomerService(CustomerRepository customerRepository,
                           UserRepository userRepository,
                           TripRepository tripRepository,
                           CustomerCouponRepository customerCouponRepository) {
        this.customerRepository = customerRepository;
        this.userRepository = userRepository;
        this.tripRepository = tripRepository;
        this.customerCouponRepository = customerCouponRepository;
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
    }

    public List<CustomerCoupon> getCoupons(String username) {
        Customer customer = customerRepository.findByUserId_Username(username)
            .orElseThrow(() -> new ResourceNotFoundException("Cliente no encontrado"));
        return customerCouponRepository.findByCustomer_IdAndUsedFalse(customer.getId());
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
