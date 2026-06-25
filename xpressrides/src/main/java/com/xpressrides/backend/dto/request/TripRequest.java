package com.xpressrides.backend.dto.request;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;

public class TripRequest {
    @NotNull Integer idZoneOrigin;
    @NotNull Integer idZoneDestiny;
    @NotNull @Min(1) @Max(3) private Integer passengerCount;
    private Integer customerCouponId;

    public TripRequest(@NotNull Integer idZoneOrigin, @NotNull Integer idZoneDestiny,
            @NotNull @Min(1) @Max(3) Integer passengerCount, Integer customerCouponId) {
        this.idZoneOrigin = idZoneOrigin;
        this.idZoneDestiny = idZoneDestiny;
        this.passengerCount = passengerCount;
        this.customerCouponId = customerCouponId;
    }

    public Integer getIdZoneOrigin() {
        return idZoneOrigin;
    }

    public void setIdZoneOrigin(Integer idZoneOrigin) {
        this.idZoneOrigin = idZoneOrigin;
    }

    public Integer getIdZoneDestiny() {
        return idZoneDestiny;
    }

    public void setIdZoneDestiny(Integer idZoneDestiny) {
        this.idZoneDestiny = idZoneDestiny;
    }

    public Integer getPassengerCount() {
        return passengerCount;
    }

    public void setPassengerCount(Integer passengerCount) {
        this.passengerCount = passengerCount;
    }

    public Integer getCustomerCouponId() {
        return customerCouponId;
    }

    public void setCustomerCouponId(Integer customerCouponId) {
        this.customerCouponId = customerCouponId;
    }

    

    
}
