package com.xpressrides.backend.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.xpressrides.backend.dto.request.PsychEvaluationRequest;
import com.xpressrides.backend.dto.response.PsychEvaluationResponse;
import com.xpressrides.backend.service.PsychEvaluationService;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/evaluacion-psicologica")
public class PsychEvaluationController {

    private final PsychEvaluationService psychEvaluationService;

    public PsychEvaluationController(PsychEvaluationService psychEvaluationService) {
        this.psychEvaluationService = psychEvaluationService;
    }

    @PreAuthorize("hasRole('administrador') or hasRole('personal_admin')")
    @PostMapping
    public ResponseEntity<PsychEvaluationResponse> create(@Valid @RequestBody PsychEvaluationRequest request){
        PsychEvaluationResponse response = psychEvaluationService.create(request);
        return ResponseEntity.ok(response);
    }
}
