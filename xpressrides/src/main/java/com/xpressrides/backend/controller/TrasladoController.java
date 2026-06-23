package com.xpressrides.backend.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.core.Authentication;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.xpressrides.backend.dto.SolicitarTrasladoRequest;
import com.xpressrides.backend.dto.SolicitarTrasladoResponse;
import com.xpressrides.backend.service.TrasladoService;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/traslados")
public class TrasladoController {

    @Autowired private TrasladoService trasladoService;

    @PostMapping("/solicitar")
    public ResponseEntity<SolicitarTrasladoResponse> solicitarTraslado(
            @Valid @RequestBody SolicitarTrasladoRequest request,
            Authentication authentication) {
        String username = authentication.getName();
        SolicitarTrasladoResponse response = trasladoService.solicitarTraslado(request, username);
        return ResponseEntity.ok(response);
    }
}
