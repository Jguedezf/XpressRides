/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Traslados — Cálculo de Tarifa
 *  Descripción: Calcula la tarifa del viaje sin crear el traslado
 *               ni modificar ningún dato. Replica el Algoritmo
 *               Híbrido Dinámico de sp_solicitar_traslado usando
 *               fn_distancia_km para garantizar que la distancia
 *               preview sea idéntica a la del SP.
 *  Versión:     1.0.0
 *  Fecha:       25/06/2026
 * ============================================================
 */
package com.xpressrides.backend.service;

import com.xpressrides.backend.dto.request.FareRequest;
import com.xpressrides.backend.dto.response.FareResponse;
import com.xpressrides.backend.exception.BadRequestException;
import com.xpressrides.backend.exception.ResourceNotFoundException;
import com.xpressrides.backend.model.Customer;
import com.xpressrides.backend.model.CustomerCoupon;
import com.xpressrides.backend.model.ExchangeRate;
import com.xpressrides.backend.model.Zone;
import com.xpressrides.backend.repository.CustomerCouponRepository;
import com.xpressrides.backend.repository.CustomerRepository;
import com.xpressrides.backend.repository.ExchangeRateRepository;
import com.xpressrides.backend.repository.ZoneRepository;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.Set;

@Service
public class FareService {

    // Constantes del Algoritmo Híbrido Dinámico — mismas que sp_solicitar_traslado
    private static final BigDecimal BASE_FARE        = new BigDecimal("1.00");
    private static final BigDecimal COST_PER_KM      = new BigDecimal("0.45");
    private static final BigDecimal NIGHT_WEEKEND    = new BigDecimal("1.50");
    private static final BigDecimal FACTOR_PEAK_7_9  = new BigDecimal("1.20");
    private static final BigDecimal FACTOR_PEAK_11_13 = new BigDecimal("1.15");
    private static final BigDecimal FACTOR_PEAK_17   = new BigDecimal("1.25");
    private static final BigDecimal STUDENT_FACTOR   = new BigDecimal("0.70");

    // Piso de tarifa cuando se aplica un cupón de referido — mismo valor que
    // TARIFA_MIN_CUPON_REFERIDO en sp_solicitar_traslado.
    private static final BigDecimal REFERRAL_COUPON_MIN_FARE = new BigDecimal("1.00");

    // Tope de distancia del primer viaje gratis — mismo mecanismo que maxDistanceKm
    // en los cupones de referido: si la distancia lo supera, el descuento no se
    // aplica y el cliente paga el viaje completo. Valor confirmado por Johanna
    // el 19/07/2026. Mismo valor que DISTANCIA_MAX_PRIMER_VIAJE en sp_solicitar_traslado.
    private static final BigDecimal FIRST_TRIP_MAX_DISTANCE_KM = new BigDecimal("15");

    // Zonas universitarias con descuento estudiantil — igual que el SP
    private static final Set<String> UNIVERSITY_ZONES = Set.of(
        "UNEG Sede Atlántico", "UNEG Sede Villa Asia", "UNEXPO"
    );

    @PersistenceContext
    private EntityManager entityManager;

    private final ZoneRepository zoneRepository;
    private final CustomerRepository customerRepository;
    private final ExchangeRateRepository exchangeRateRepository;
    private final CustomerCouponRepository customerCouponRepository;

    public FareService(ZoneRepository zoneRepository,
                       CustomerRepository customerRepository,
                       ExchangeRateRepository exchangeRateRepository,
                       CustomerCouponRepository customerCouponRepository) {
        this.zoneRepository       = zoneRepository;
        this.customerRepository   = customerRepository;
        this.exchangeRateRepository = exchangeRateRepository;
        this.customerCouponRepository = customerCouponRepository;
    }

    public FareResponse calculateFare(FareRequest request, String username) {

        // ZoneRepository se mantiene como dependencia completa a propósito, no es deuda
        // técnica: el plan original de migración (Plan_Migracion_Google_Places_Propuesta.docx,
        // sección 5.2) proponía retirarla, pero se decidió conservar el dual-path (zona por ID
        // O coordenadas directas) por la misma razón que sp_solicitar_traslado mantiene
        // id_zona_origen/id_zona_destino como nullable "kept for backward compatibility": no
        // romper clientes/pruebas que todavía envían zona en vez de lat/lng. Mismo criterio
        // aplica al descuento estudiantil (líneas más abajo): por nombre de zona si la
        // solicitud no trae coordenadas, por radio de 300m si sí las trae. Decisión confirmada
        // por Johanna el 14/07/2026.
        // 1. Resolver coordenadas de origen
        Double originLat = request.getOriginLat();
        Double originLng = request.getOriginLng();
        Zone originZone = null;
        if (originLat == null || originLng == null) {
            if (request.getIdZoneOrigin() == null) {
                throw new BadRequestException("Debe proporcionar coordenadas de origen o una zona de origen válida");
            }
            originZone = zoneRepository.findById(request.getIdZoneOrigin())
                .orElseThrow(() -> new ResourceNotFoundException("Zona de origen no encontrada"));
            originLat = originZone.getLatitude().doubleValue();
            originLng = originZone.getLongitude().doubleValue();
        } else if (request.getIdZoneOrigin() != null) {
            originZone = zoneRepository.findById(request.getIdZoneOrigin()).orElse(null);
        }

        // 2. Resolver coordenadas de destino
        Double destLat = request.getDestinationLat();
        Double destLng = request.getDestinationLng();
        Zone destinyZone = null;
        if (destLat == null || destLng == null) {
            if (request.getIdZoneDestiny() == null) {
                throw new BadRequestException("Debe proporcionar coordenadas de destino o una zona de destino válida");
            }
            destinyZone = zoneRepository.findById(request.getIdZoneDestiny())
                .orElseThrow(() -> new ResourceNotFoundException("Zona de destino no encontrada"));
            destLat = destinyZone.getLatitude().doubleValue();
            destLng = destinyZone.getLongitude().doubleValue();
        } else if (request.getIdZoneDestiny() != null) {
            destinyZone = zoneRepository.findById(request.getIdZoneDestiny()).orElse(null);
        }

        // 3. Distancia con fn_distancia_km — misma función que usa el SP
        BigDecimal distanceKm = calculateDistanceKm(originLat, originLng, destLat, destLng);

        // 4. Datos del cliente autenticado
        Customer customer = customerRepository.findByUserId_Username(username)
            .orElseThrow(() -> new ResourceNotFoundException("Cliente no encontrado"));

        // 5. Tasa BCV vigente (cubre fines de semana y feriados)
        ExchangeRate rate = exchangeRateRepository.findCurrentRate()
            .orElseThrow(() -> new RuntimeException("No hay tasa BCV registrada. Contacte al administrador."));

        // 6. Recargo nocturno/fin de semana y factor hora pico (mutuamente excluyentes)
        int hour   = LocalTime.now().getHour();
        int minute = LocalTime.now().getMinute();
        DayOfWeek day = LocalDate.now().getDayOfWeek();

        boolean isNightOrWeekend = (hour >= 19 || hour < 5)
            || (day == DayOfWeek.SATURDAY || day == DayOfWeek.SUNDAY);

        BigDecimal nightWeekendSurcharge = BigDecimal.ZERO;
        BigDecimal peakFactor = BigDecimal.ONE;

        if (isNightOrWeekend) {
            nightWeekendSurcharge = NIGHT_WEEKEND;
        } else {
            peakFactor = resolvePeakFactor(hour, minute);
        }

        // 7. Fórmula: (BASE + distancia*0.45 + recargoNocturno) × factorPico
        BigDecimal distanceCost   = distanceKm.multiply(COST_PER_KM).setScale(2, RoundingMode.HALF_UP);
        BigDecimal subtotal       = BASE_FARE.add(distanceCost).add(nightWeekendSurcharge);
        BigDecimal rawFare        = subtotal.multiply(peakFactor).setScale(2, RoundingMode.HALF_UP);
        BigDecimal peakHourSurcharge = rawFare.subtract(subtotal).setScale(2, RoundingMode.HALF_UP);

        // 8. Descuentos — primer viaje tiene prioridad sobre descuento estudiantil
        boolean firstTripFree = !customer.isFirstTripUsed()
            && distanceKm.compareTo(FIRST_TRIP_MAX_DISTANCE_KM) <= 0;
        boolean studentDiscount = false;
        if (customer.isStudent()) {
            boolean coordinatesNull = (request.getOriginLat() == null || request.getOriginLng() == null
                || request.getDestinationLat() == null || request.getDestinationLng() == null);
            if (coordinatesNull) {
                studentDiscount = (originZone != null && UNIVERSITY_ZONES.contains(originZone.getName()))
                    || (destinyZone != null && UNIVERSITY_ZONES.contains(destinyZone.getName()));
            } else {
                studentDiscount = isCloseToCampus(originLat, originLng) || isCloseToCampus(destLat, destLng);
            }
        }

        BigDecimal discountApplied;
        BigDecimal finalCostUsd;

        if (firstTripFree) {
            discountApplied = rawFare;
            finalCostUsd    = BigDecimal.ZERO;
        } else if (studentDiscount) {
            discountApplied = rawFare.subtract(rawFare.multiply(STUDENT_FACTOR))
                                     .setScale(2, RoundingMode.HALF_UP);
            finalCostUsd    = rawFare.multiply(STUDENT_FACTOR).setScale(2, RoundingMode.HALF_UP);
        } else {
            discountApplied = BigDecimal.ZERO;
            finalCostUsd    = rawFare;
        }

        // 9. Conversión a bolívares
        BigDecimal finalCostVes = finalCostUsd.multiply(rate.getRateVes()).setScale(2, RoundingMode.HALF_UP);

        // 10. Cupón de referido
        boolean referralCouponAvailable    = false;
        Integer referralCouponClienteId    = null;
        BigDecimal referralCouponDiscount  = BigDecimal.ZERO;
        BigDecimal costWithCouponUsd       = finalCostUsd;
        BigDecimal costWithCouponVes       = finalCostVes;

        if (!firstTripFree) {
            List<CustomerCoupon> referralCoupons = customerCouponRepository
                .findByCustomer_IdAndUsedFalseAndCoupon_TypeOrderByCreatedAtAsc(customer.getId(), "referido");

            for (CustomerCoupon candidate : referralCoupons) {
                Integer maxDistanceKm = candidate.getCoupon().getMaxDistanceKm();
                if (maxDistanceKm != null && distanceKm.compareTo(BigDecimal.valueOf(maxDistanceKm)) > 0) {
                    continue;
                }
                BigDecimal cap = finalCostUsd.subtract(REFERRAL_COUPON_MIN_FARE).max(BigDecimal.ZERO);
                referralCouponDiscount = candidate.getCoupon().getDiscountUsd().min(cap)
                    .setScale(2, RoundingMode.HALF_UP);
                referralCouponClienteId = candidate.getId();
                referralCouponAvailable = true;
                costWithCouponUsd = finalCostUsd.subtract(referralCouponDiscount).setScale(2, RoundingMode.HALF_UP);
                costWithCouponVes = costWithCouponUsd.multiply(rate.getRateVes()).setScale(2, RoundingMode.HALF_UP);
                break;
            }
        }

        return new FareResponse(
            distanceKm, BASE_FARE, distanceCost,
            peakHourSurcharge, nightWeekendSurcharge,
            discountApplied, finalCostUsd, finalCostVes,
            rate.getId(), firstTripFree, studentDiscount,
            referralCouponAvailable, referralCouponClienteId,
            referralCouponDiscount, costWithCouponUsd, costWithCouponVes
        );
    }

    // Llama a fn_distancia_km de MySQL — garantiza el mismo resultado que el SP
    private BigDecimal calculateDistanceKm(Double lat1, Double lon1, Double lat2, Double lon2) {
        Object result = entityManager
            .createNativeQuery("SELECT fn_distancia_km(:lat1, :lon1, :lat2, :lon2)")
            .setParameter("lat1", lat1)
            .setParameter("lon1", lon1)
            .setParameter("lat2", lat2)
            .setParameter("lon2", lon2)
            .getSingleResult();

        return new BigDecimal(result.toString()).setScale(2, RoundingMode.HALF_UP);
    }

    private boolean isCloseToCampus(Double lat, Double lng) {
        double[][] campuses = {
            {8.2721185, -62.7357291},
            {8.2822200, -62.7233869},
            {8.2797000, -62.7303000}
        };
        for (double[] campus : campuses) {
            BigDecimal dist = calculateDistanceKm(lat, lng, campus[0], campus[1]);
            if (dist.compareTo(new BigDecimal("0.3")) <= 0) {
                return true;
            }
        }
        return false;
    }

    // Resuelve el factor de hora pico — misma lógica que el SP
    private BigDecimal resolvePeakFactor(int hour, int minute) {
        if (hour >= 7 && hour < 9)                            return FACTOR_PEAK_7_9;
        if (hour >= 11 && hour < 13)                          return FACTOR_PEAK_11_13;
        if (hour >= 17 && hour < 19)                          return FACTOR_PEAK_17;
        return BigDecimal.ONE;
    }
}
