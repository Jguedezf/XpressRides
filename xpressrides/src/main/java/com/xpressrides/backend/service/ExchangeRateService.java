/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Tasa BCV
 *  Descripción: Lógica de negocio para la tasa BCV —
 *               consulta de tasa vigente y registro de nueva tasa.
 *               Solo se registra en días hábiles bancarios.
 *  Versión:     1.1.0
 *  Fecha:       24/06/2026
 * ============================================================
 */
package com.xpressrides.backend.service;

import com.xpressrides.backend.model.ExchangeRate;
import com.xpressrides.backend.repository.ExchangeRateRepository;
import org.jsoup.Jsoup;
import org.jsoup.nodes.Document;
import org.jsoup.nodes.Element;
import org.springframework.stereotype.Service;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

@Service
public class ExchangeRateService {

    private final ExchangeRateRepository exchangeRateRepository;
    private final com.xpressrides.backend.repository.UserRepository userRepository;

    // Inyección de dependencias por constructor
    public ExchangeRateService(ExchangeRateRepository exchangeRateRepository, com.xpressrides.backend.repository.UserRepository userRepository) {
        this.exchangeRateRepository = exchangeRateRepository;
        this.userRepository = userRepository;
    }

    // Retorna la tasa vigente más reciente
    // Si hoy es feriado o fin de semana, devuelve la del último día hábil
    public Optional<ExchangeRate> getCurrentRate() {
        return exchangeRateRepository.findCurrentRate();
    }

    // Retorna el historial completo de tasas registradas
    public List<ExchangeRate> getHistory() {
        return exchangeRateRepository.findAll();
    }

    // Registra una nueva tasa BCV para la fecha indicada
    // Si ya existe una tasa para la fecha indicada, la actualiza (Upsert)
    public ExchangeRate registerRate(ExchangeRate exchangeRate) {
        if (exchangeRate.getEffectiveDate() == null) {
            exchangeRate.setEffectiveDate(LocalDate.now());
        }

        // Resolver dinámicamente el usuario administrador autenticado
        String username = org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication().getName();
        com.xpressrides.backend.model.User user = userRepository.findByUsername(username)
                .orElseThrow(() -> new RuntimeException("Usuario autenticado no encontrado"));
        exchangeRate.setRegisteredBy(user.getId());
        exchangeRate.setCreatedAt(java.time.LocalDateTime.now());

        Optional<ExchangeRate> existingOpt = exchangeRateRepository.findByEffectiveDate(exchangeRate.getEffectiveDate());
        if (existingOpt.isPresent()) {
            ExchangeRate existing = existingOpt.get();
            existing.setRateVes(exchangeRate.getRateVes());
            existing.setRegisteredBy(user.getId());
            return exchangeRateRepository.save(existing);
        }
        return exchangeRateRepository.save(exchangeRate);
    }

    private void bypassSSL() {
        try {
            javax.net.ssl.TrustManager[] trustAllCerts = new javax.net.ssl.TrustManager[]{
                new javax.net.ssl.X509TrustManager() {
                    public java.security.cert.X509Certificate[] getAcceptedIssuers() { return null; }
                    public void checkClientTrusted(java.security.cert.X509Certificate[] certs, String authType) {}
                    public void checkServerTrusted(java.security.cert.X509Certificate[] certs, String authType) {}
                }
            };
            javax.net.ssl.SSLContext sc = javax.net.ssl.SSLContext.getInstance("SSL");
            sc.init(null, trustAllCerts, new java.security.SecureRandom());
            javax.net.ssl.HttpsURLConnection.setDefaultSSLSocketFactory(sc.getSocketFactory());
            javax.net.ssl.HttpsURLConnection.setDefaultHostnameVerifier((hostname, session) -> true);
        } catch (Exception ignored) {}
    }

    /**
     * Extrae la tasa de cambio USD desde la página web del BCV.
     * Realiza web scraping al sitio oficial https://www.bcv.org.ve/
     * y busca el valor dentro del div#dolar > strong.
     *
     * @return BigDecimal con la tasa de cambio USD/VES
     * @throws RuntimeException si no se puede obtener o parsear la tasa
     */
    public BigDecimal fetchRateFromBcvWebsite() {
        try {
            // Conectar al sitio del BCV con timeout de 15 segundos
            // Ignorar validación de certificado SSL ya que BCV suele tener problemas con eso
            bypassSSL();
            Document doc = Jsoup.connect("https://www.bcv.org.ve/")
                    .userAgent("Mozilla/5.0")
                    .timeout(15000)
                    .get();

            // Buscar el div con id="dolar" y extraer el valor del <strong>
            Element dolarDiv = doc.getElementById("dolar");
            if (dolarDiv == null) {
                throw new RuntimeException("No se encontró el elemento #dolar en la página del BCV");
            }

            Element strongTag = dolarDiv.selectFirst("strong");
            if (strongTag == null) {
                throw new RuntimeException("No se encontró el tag <strong> dentro de #dolar");
            }

            // El valor viene en formato venezolano: punto como separador de miles,
            // coma como separador decimal. Ej: "1.667,05000000"
            String rawValue = strongTag.text().trim();

            // Eliminar puntos de miles y reemplazar coma decimal por punto
            String normalized = rawValue.replace(".", "").replace(",", ".");

            return new BigDecimal(normalized);

        } catch (RuntimeException e) {
            throw e; // Re-lanzar RuntimeExceptions propias
        } catch (Exception e) {
            throw new RuntimeException("Error al consultar la tasa BCV desde la web: " + e.getMessage(), e);
        }
    }
}
