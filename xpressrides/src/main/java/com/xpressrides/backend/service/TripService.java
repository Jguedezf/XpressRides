package com.xpressrides.backend.service;

import org.springframework.stereotype.Service;

import com.xpressrides.backend.dto.TripRequest;
import com.xpressrides.backend.dto.TripResponse;
import com.xpressrides.backend.model.Customer;
import com.xpressrides.backend.repository.CustomerRepository;

import jakarta.persistence.EntityManager;
import jakarta.persistence.ParameterMode;
import jakarta.persistence.PersistenceContext;
import jakarta.persistence.StoredProcedureQuery;

@Service
public class TripService {

    @PersistenceContext
    private EntityManager entityManager;

    private CustomerRepository customerRepository;
    

    public TripService(CustomerRepository customerRepository) {
        this.customerRepository = customerRepository;
    }


    public TripResponse solicitarTraslado(TripRequest request, String username) {
        Customer customer = customerRepository.findByUserId_Username(username)
            .orElseThrow(() -> new RuntimeException("Cliente no encontrado"));

        StoredProcedureQuery query = entityManager.createStoredProcedureQuery("sp_solicitar_traslado");

        query.registerStoredProcedureParameter("p_id_cliente", Integer.class, ParameterMode.IN);
        query.registerStoredProcedureParameter("p_id_zona_origen", Integer.class, ParameterMode.IN);
        query.registerStoredProcedureParameter("p_id_zona_destino", Integer.class, ParameterMode.IN);
        query.registerStoredProcedureParameter("p_nro_pasajeros", Integer.class, ParameterMode.IN);
        query.registerStoredProcedureParameter("p_id_cupon_cliente", Integer.class, ParameterMode.IN);
        query.registerStoredProcedureParameter("p_id_traslado", Integer.class, ParameterMode.OUT);
        query.registerStoredProcedureParameter("p_mensaje", String.class, ParameterMode.OUT);

        query.setParameter("p_id_cliente", customer.getId());
        query.setParameter("p_id_zona_origen", request.getIdZoneOrigin());
        query.setParameter("p_id_zona_destino", request.getIdZoneDestiny());
        query.setParameter("p_nro_pasajeros", request.getPassengerCount());
        query.setParameter("p_id_cupon_cliente", request.getCustomerCouponId());

        query.execute();

        Integer tripId = (Integer) query.getOutputParameterValue("p_id_traslado");
        String message = (String) query.getOutputParameterValue("p_mensaje");

        TripResponse response = new TripResponse();
        response.setSuccess(tripId != null);
        response.setTripId(tripId);
        response.setMessage(message);
        return response;
    }
}