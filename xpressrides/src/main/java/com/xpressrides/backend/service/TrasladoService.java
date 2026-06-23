package com.xpressrides.backend.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import com.xpressrides.backend.dto.SolicitarTrasladoRequest;
import com.xpressrides.backend.dto.SolicitarTrasladoResponse;
import com.xpressrides.backend.model.Cliente;
import com.xpressrides.backend.repository.ClienteRepository;

import jakarta.persistence.EntityManager;
import jakarta.persistence.ParameterMode;
import jakarta.persistence.PersistenceContext;
import jakarta.persistence.StoredProcedureQuery;

@Service
public class TrasladoService {

    @PersistenceContext
    private EntityManager entityManager;

    @Autowired
    private ClienteRepository clienteRepository;

    public SolicitarTrasladoResponse solicitarTraslado(SolicitarTrasladoRequest request, String username) {
        Cliente cliente = clienteRepository.findByUserId_Username(username)
            .orElseThrow(() -> new RuntimeException("Cliente no encontrado"));

        StoredProcedureQuery query = entityManager.createStoredProcedureQuery("sp_solicitar_traslado");

        query.registerStoredProcedureParameter("p_id_cliente", Integer.class, ParameterMode.IN);
        query.registerStoredProcedureParameter("p_id_zona_origen", Integer.class, ParameterMode.IN);
        query.registerStoredProcedureParameter("p_id_zona_destino", Integer.class, ParameterMode.IN);
        query.registerStoredProcedureParameter("p_nro_pasajeros", Integer.class, ParameterMode.IN);
        query.registerStoredProcedureParameter("p_id_cupon_cliente", Integer.class, ParameterMode.IN);
        query.registerStoredProcedureParameter("p_id_traslado", Integer.class, ParameterMode.OUT);
        query.registerStoredProcedureParameter("p_mensaje", String.class, ParameterMode.OUT);

        query.setParameter("p_id_cliente", cliente.getId());
        query.setParameter("p_id_zona_origen", request.getIdZoneOrigin());
        query.setParameter("p_id_zona_destino", request.getIdZoneDestiny());
        query.setParameter("p_nro_pasajeros", request.getNroPasajeros());
        query.setParameter("p_id_cupon_cliente", request.getIdCuponCliente());

        query.execute();

        Integer idTraslado = (Integer) query.getOutputParameterValue("p_id_traslado");
        String mensaje = (String) query.getOutputParameterValue("p_mensaje");

        SolicitarTrasladoResponse response = new SolicitarTrasladoResponse();
        response.setSuccess(idTraslado != null);
        response.setIdTraslado(idTraslado);
        response.setMessage(mensaje);
        return response;
    }
}