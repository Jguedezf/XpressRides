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
    private static final BigDecimal FACTOR_PEAK_1130 = new BigDecimal("1.15");
    private static final BigDecimal FACTOR_PEAK_17   = new BigDecimal("1.25");
    private static final BigDecimal STUDENT_FACTOR   = new BigDecimal("0.70");

    // Piso de tarifa cuando se aplica un cupón de referido — mismo valor que
    // TARIFA_MIN_CUPON_REFERIDO en sp_solicitar_traslado.
    private static final BigDecimal REFERRAL_COUPON_MIN_FARE = new BigDecimal("1.00");

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

        // 1. Obtener zonas con coordenadas
        Zone origin = zoneRepository.findById(request.getIdZoneOrigin())
            .orElseThrow(() -> new ResourceNotFoundException("Zona de origen no encontrada"));
        Zone destiny = zoneRepository.findById(request.getIdZoneDestiny())
            .orElseThrow(() -> new ResourceNotFoundException("Zona de destino no encontrada"));

        // 2. Distancia con fn_distancia_km — misma función que usa el SP
        BigDecimal distanceKm = calculateDistanceKm(origin, destiny);

        // 3. Datos del cliente autenticado
        Customer customer = customerRepository.findByUserId_Username(username)
            .orElseThrow(() -> new ResourceNotFoundException("Cliente no encontrado"));

        // 4. Tasa BCV vigente (cubre fines de semana y feriados)
        ExchangeRate rate = exchangeRateRepository.findCurrentRate()
            .orElseThrow(() -> new RuntimeException("No hay tasa BCV registrada. Contacte al administrador."));

        // 5. Recargo nocturno/fin de semana y factor hora pico (mutuamente excluyentes)
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

        // 6. Fórmula: (BASE + distancia*0.45 + recargoNocturno) × factorPico
        BigDecimal distanceCost   = distanceKm.multiply(COST_PER_KM).setScale(2, RoundingMode.HALF_UP);
        BigDecimal subtotal       = BASE_FARE.add(distanceCost).add(nightWeekendSurcharge);
        BigDecimal rawFare        = subtotal.multiply(peakFactor).setScale(2, RoundingMode.HALF_UP);
        BigDecimal peakHourSurcharge = rawFare.subtract(subtotal).setScale(2, RoundingMode.HALF_UP);

        // 7. Descuentos — primer viaje tiene prioridad sobre descuento estudiantil
        boolean firstTripFree   = !customer.isFirstTripUsed();
        boolean studentDiscount = customer.isStudent() && UNIVERSITY_ZONES.contains(destiny.getName());

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

        // 8. Conversión a bolívares
        BigDecimal finalCostVes = finalCostUsd.multiply(rate.getRateVes()).setScale(2, RoundingMode.HALF_UP);

        // 9. Cupón de referido — oferta proactiva del preview, NO lógica de
        // negocio duplicada por descuido: es una RÉPLICA INTENCIONAL del mismo
        // cálculo que hace sp_solicitar_traslado (bloque de cupón, con el piso
        // de $1 exclusivo de tipo 'referido'), igual que calculateDistanceKm ya
        // replica fn_distancia_km más arriba para que el preview coincida con lo
        // que el SP cobrará realmente. El SP sigue siendo la única fuente de
        // verdad y quien de verdad marca el cupón como usado — este bloque solo
        // anticipa el resultado para poder ofrecerlo en pantalla antes de
        // confirmar el viaje.
        //
        // Solo aplica si NO es primer viaje gratis: un primer viaje ya cuesta
        // $0, y sp_solicitar_traslado ni siquiera entra al bloque de cupón en
        // ese caso (está en el ELSE de "primer viaje"), así que ofrecerlo aquí
        // sería engañoso — el cliente lo vería "disponible" pero el SP jamás lo
        // consumiría en ese viaje.
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
    private BigDecimal calculateDistanceKm(Zone origin, Zone destiny) {
        Object result = entityManager
            .createNativeQuery("SELECT fn_distancia_km(:lat1, :lon1, :lat2, :lon2)")
            .setParameter("lat1", origin.getLatitude())
            .setParameter("lon1", origin.getLongitude())
            .setParameter("lat2", destiny.getLatitude())
            .setParameter("lon2", destiny.getLongitude())
            .getSingleResult();

        return new BigDecimal(result.toString()).setScale(2, RoundingMode.HALF_UP);
    }

    // Resuelve el factor de hora pico — misma lógica que el SP
    private BigDecimal resolvePeakFactor(int hour, int minute) {
        if (hour >= 7 && hour <= 9)                           return FACTOR_PEAK_7_9;
        if ((hour == 11 && minute >= 30) || hour == 12)       return FACTOR_PEAK_1130;
        if (hour >= 17 && hour < 19)                          return FACTOR_PEAK_17;
        return BigDecimal.ONE;
    }
}
