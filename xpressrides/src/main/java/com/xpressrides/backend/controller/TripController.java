package com.xpressrides.backend.controller;

import org.springframework.security.core.Authentication;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.xpressrides.backend.dto.TripRequest;
import com.xpressrides.backend.dto.TripResponse;
import com.xpressrides.backend.service.TripService;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/trips")
public class TripController {

    private TripService tripService;

    public TripController(TripService tripService) {
        this.tripService = tripService;
    }

    @PostMapping("/request")
    public ResponseEntity<TripResponse> solicitarTraslado(
            @Valid @RequestBody TripRequest request,
            Authentication authentication) {
        String username = authentication.getName();
        TripResponse response = tripService.solicitarTraslado(request, username);
        return ResponseEntity.ok(response);
    }
}
