package com.xpressrides.backend.dto.request;

import com.fasterxml.jackson.annotation.JsonAlias;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;

public class TripRequest {
    @JsonAlias("zonaOrigenId")
    @NotNull Integer idZoneOrigin;

    @JsonAlias("zonaDestinoId")
    @NotNull Integer idZoneDestiny;

    @JsonAlias("cantPasajeros")
    @NotNull @Min(1) @Max(3) private Integer passengerCount;

    @JsonAlias("codigoCupon")
    private Integer customerCouponId;

    public TripRequest() {}

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
