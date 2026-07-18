package com.xpressrides.backend.dto.request;

import jakarta.validation.constraints.NotBlank;

public class BankRequest {
    @NotBlank String name;
    @NotBlank String bcvCode;
    Boolean acceptsUsd;
    Boolean acceptsVes;

    public BankRequest(String name, String bcvCode, Boolean acceptsUsd, Boolean acceptsVes) {
        this.name = name;
        this.bcvCode = bcvCode;
        this.acceptsUsd = acceptsUsd;
        this.acceptsVes = acceptsVes;
    }

    public BankRequest() {
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getBcvCode() {
        return bcvCode;
    }

    public void setBcvCode(String bcvCode) {
        this.bcvCode = bcvCode;
    }

    public Boolean getAcceptsUsd() {
        return acceptsUsd;
    }

    public void setAcceptsUsd(Boolean acceptsUsd) {
        this.acceptsUsd = acceptsUsd;
    }

    public Boolean getAcceptsVes() {
        return acceptsVes;
    }

    public void setAcceptsVes(Boolean acceptsVes) {
        this.acceptsVes = acceptsVes;
    }
}
