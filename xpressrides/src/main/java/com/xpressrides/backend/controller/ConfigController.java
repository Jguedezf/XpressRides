package com.xpressrides.backend.controller;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/config")
public class ConfigController {

    @Value("${google.maps.api.key}")
    private String googleMapsApiKey;

    @GetMapping("/maps-key")
    public Map<String, Object> getMapsKey() {
        Map<String, Object> response = new HashMap<>();
        response.put("success", true);
        response.put("data", googleMapsApiKey);
        return response;
    }
}
