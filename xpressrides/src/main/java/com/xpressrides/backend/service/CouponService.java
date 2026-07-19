/**
 * ============================================================
 *  XpressRides (Decarrerita) — Sistemas de Base de Datos I
 *  UNEG · Prof. María Raquel Herrera E. · Junio 2026
 *  Equipo: Johanna Guédez · Eliuber González · Freddy Salazar
 *          Manuel Jaimes · Ángel Martínez
 * ============================================================
 *  Módulo:      Cupones
 *  Descripción: Lógica de negocio para creación y asignación de
 *               cupones de descuento por personal administrativo
 *  Versión:     1.0.0
 *  Fecha:       25/06/2026
 * ============================================================
 */
package com.xpressrides.backend.service;

import com.xpressrides.backend.dto.request.CouponRequest;
import com.xpressrides.backend.exception.BadRequestException;
import com.xpressrides.backend.exception.ResourceNotFoundException;
import com.xpressrides.backend.model.Coupon;
import com.xpressrides.backend.model.Customer;
import com.xpressrides.backend.model.CustomerCoupon;
import com.xpressrides.backend.repository.CouponRepository;
import com.xpressrides.backend.repository.CustomerCouponRepository;
import com.xpressrides.backend.repository.CustomerRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

@Service
public class CouponService {

    private final CouponRepository couponRepository;
    private final CustomerRepository customerRepository;
    private final CustomerCouponRepository customerCouponRepository;

    public CouponService(CouponRepository couponRepository,
                         CustomerRepository customerRepository,
                         CustomerCouponRepository customerCouponRepository) {
        this.couponRepository        = couponRepository;
        this.customerRepository      = customerRepository;
        this.customerCouponRepository = customerCouponRepository;
    }

    // Crea un cupón nuevo — el código debe ser único en el sistema
    @Transactional
    public Coupon createCoupon(CouponRequest request) {
        if (couponRepository.existsByCode(request.getCode().toUpperCase())) {
            throw new BadRequestException("Ya existe un cupón con el código: " + request.getCode().toUpperCase());
        }

        Coupon coupon = new Coupon();
        coupon.setCode(request.getCode().toUpperCase());
        coupon.setType(request.getType());
        coupon.setDiscountUsd(request.getDiscountUsd());
        coupon.setMaxDistanceKm(request.getMaxDistanceKm());
        coupon.setActive(true);
        coupon.setCreatedAt(LocalDateTime.now());

        return couponRepository.save(coupon);
    }

    // Retorna todos los cupones — panel administrativo
    public List<Coupon> listarTodosLosCupones() {
        return couponRepository.findAll();
    }

    // Actualiza un cupón existente
    @Transactional
    public Coupon updateCoupon(Integer id, CouponRequest request) {
        Coupon coupon = couponRepository.findById(id)
            .orElseThrow(() -> new ResourceNotFoundException("Cupón no encontrado con ID: " + id));

        String nuevoCodigo = request.getCode().toUpperCase();
        if (couponRepository.existsByCodeAndIdNot(nuevoCodigo, id)) {
            throw new BadRequestException("Ya existe un cupón con el código: " + nuevoCodigo);
        }

        coupon.setCode(nuevoCodigo);
        coupon.setType(request.getType());
        coupon.setDiscountUsd(request.getDiscountUsd());
        coupon.setMaxDistanceKm(request.getMaxDistanceKm());

        return couponRepository.save(coupon);
    }

    // Desactiva un cupón — soft delete, mismo patrón que Bank
    @Transactional
    public Coupon deactivateCoupon(Integer id) {
        Coupon coupon = couponRepository.findById(id)
            .orElseThrow(() -> new ResourceNotFoundException("Cupón no encontrado con ID: " + id));
        coupon.setActive(false);
        return couponRepository.save(coupon);
    }

    // Asigna un cupón existente a un cliente específico
    @Transactional
    public CustomerCoupon assignToClient(Integer couponId, Integer clientId) {
        Coupon coupon = couponRepository.findById(couponId)
            .orElseThrow(() -> new ResourceNotFoundException("Cupón no encontrado con ID: " + couponId));

        if (!Boolean.TRUE.equals(coupon.getActive())) {
            throw new BadRequestException("El cupón '" + coupon.getCode() + "' está inactivo");
        }

        Customer customer = customerRepository.findById(clientId)
            .orElseThrow(() -> new ResourceNotFoundException("Cliente no encontrado con ID: " + clientId));

        if (customerCouponRepository.existsByCoupon_IdAndCustomer_Id(couponId, clientId)) {
            throw new BadRequestException("El cliente ya tiene asignado el cupón '" + coupon.getCode() + "'");
        }

        CustomerCoupon assignment = new CustomerCoupon();
        assignment.setCoupon(coupon);
        assignment.setCustomer(customer);
        assignment.setUsed(false);
        assignment.setUsedDate(null);
        assignment.setCreatedAt(LocalDateTime.now());

        return customerCouponRepository.save(assignment);
    }
}
