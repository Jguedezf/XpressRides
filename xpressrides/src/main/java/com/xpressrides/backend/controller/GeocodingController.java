package com.xpressrides.backend.controller;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.util.UriComponentsBuilder;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/geocoding")
public class GeocodingController {

    @Value("${google.maps.api.key}")
    private String googleMapsApiKey;

    private final RestTemplate restTemplate = new RestTemplate();

    // GET /api/geocoding/reverse — reverse geocoding a nivel de calle (result_type=route),
    // filtro que solo existe en la REST API de Google, no en el Geocoder JS del navegador.
    // Sin resultado a ese nivel (o si falla la llamada), success:false — el fallback ya
    // vive en el frontend (reverseGeocodeAmigable en dashboard.js), no se duplica aquí.
    @GetMapping("/reverse")
    @SuppressWarnings("unchecked")
    public Map<String, Object> reverseGeocode(@RequestParam double lat, @RequestParam double lng) {
        Map<String, Object> response = new HashMap<>();
        try {
            String url = UriComponentsBuilder.fromHttpUrl("https://maps.googleapis.com/maps/api/geocode/json")
                    .queryParam("latlng", lat + "," + lng)
                    .queryParam("result_type", "route")
                    .queryParam("key", googleMapsApiKey)
                    .toUriString();

            Map<String, Object> googleResponse = restTemplate.getForObject(url, Map.class);
            String status = googleResponse != null ? (String) googleResponse.get("status") : null;

            if ("OK".equals(status)) {
                List<Map<String, Object>> results = (List<Map<String, Object>>) googleResponse.get("results");
                if (results != null && !results.isEmpty()) {
                    response.put("success", true);
                    response.put("data", results.get(0).get("formatted_address"));
                    return response;
                }
            }
        } catch (Exception e) {
            // Red caída o respuesta inesperada de Google: se trata igual que ZERO_RESULTS.
        }
        response.put("success", false);
        response.put("data", null);
        return response;
    }
}