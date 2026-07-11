package com.xpressrides.backend.dto.request;

import com.fasterxml.jackson.annotation.JsonAlias;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;

public class TripRequest {
    @JsonAlias("zonaOrigenId")
    private Integer idZoneOrigin;

    @JsonAlias("zonaDestinoId")
    private Integer idZoneDestiny;

    @JsonAlias("cantPasajeros")
    @NotNull @Min(1) @Max(3) private Integer passengerCount;

    @JsonAlias("codigoCupon")
    private Integer customerCouponId;

    private String originAddress;
    private Double originLat;
    private Double originLng;
    private String destinationAddress;
    private Double destinationLat;
    private Double destinationLng;

    public TripRequest() {}

    public TripRequest(Integer idZoneOrigin, Integer idZoneDestiny,
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

    public String getOriginAddress() {
        return originAddress;
    }

    public void setOriginAddress(String originAddress) {
        this.originAddress = originAddress;
    }

    public Double getOriginLat() {
        return originLat;
    }

    public void setOriginLat(Double originLat) {
        this.originLat = originLat;
    }

    public Double getOriginLng() {
        return originLng;
    }

    public void setOriginLng(Double originLng) {
        this.originLng = originLng;
    }

    public String getDestinationAddress() {
        return destinationAddress;
    }

    public void setDestinationAddress(String destinationAddress) {
        this.destinationAddress = destinationAddress;
    }

    public Double getDestinationLat() {
        return destinationLat;
    }

    public void setDestinationLat(Double destinationLat) {
        this.destinationLat = destinationLat;
    }

    public Double getDestinationLng() {
        return destinationLng;
    }

    public void setDestinationLng(Double destinationLng) {
        this.destinationLng = destinationLng;
    }
}
