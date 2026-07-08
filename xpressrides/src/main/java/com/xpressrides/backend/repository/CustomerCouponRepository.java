package com.xpressrides.backend.repository;

import com.xpressrides.backend.model.CustomerCoupon;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface CustomerCouponRepository extends JpaRepository<CustomerCoupon, Integer> {
    List<CustomerCoupon> findByCustomer_IdAndUsedFalse(Integer customerId);
    boolean existsByCoupon_IdAndCustomer_Id(Integer couponId, Integer customerId);

    long countByCustomer_IdAndUsedFalse(Integer customerId);
    List<CustomerCoupon> findByCustomer_IdAndUsedTrue(Integer customerId);

    // Cupones sin usar de un tipo específico, del más antiguo al más reciente
    // (FIFO) — usado para ofrecer proactivamente el cupón de referido al
    // calcular el estimado de tarifa.
    List<CustomerCoupon> findByCustomer_IdAndUsedFalseAndCoupon_TypeOrderByCreatedAtAsc(
        Integer customerId, String type);
}
