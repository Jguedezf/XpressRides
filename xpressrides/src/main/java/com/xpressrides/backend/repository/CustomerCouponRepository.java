package com.xpressrides.backend.repository;

import com.xpressrides.backend.model.CustomerCoupon;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface CustomerCouponRepository extends JpaRepository<CustomerCoupon, Integer> {
    List<CustomerCoupon> findByCustomer_IdAndUsedFalse(Integer customerId);
}
