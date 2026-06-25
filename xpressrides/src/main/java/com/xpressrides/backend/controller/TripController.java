package com.xpressrides.backend.controller;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.xpressrides.backend.dto.request.TripRequest;
import com.xpressrides.backend.dto.response.TripResponse;
import com.xpressrides.backend.service.TripService;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/traslado")
public class TripController {

    private TripService tripService;

    public TripController(TripService tripService) {
        this.tripService = tripService;
    }

    @PreAuthorize("hasRole('cliente')") //solo clientes
    @PostMapping("/solicitar")
    public ResponseEntity<TripResponse> solicitarTraslado(
            @Valid @RequestBody TripRequest request,
            Authentication authentication) {
        String username = authentication.getName();
        TripResponse response = tripService.solicitarTraslado(request, username);
        return ResponseEntity.ok(response);
    }
}
