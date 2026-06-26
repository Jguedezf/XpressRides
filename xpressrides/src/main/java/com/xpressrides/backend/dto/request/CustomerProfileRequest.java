package com.xpressrides.backend.dto.request;

public class CustomerProfileRequest {
    private String name;
    private String lastName;
    private String email;
    private String phone;
    private Boolean isStudent;

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getLastName() { return lastName; }
    public void setLastName(String lastName) { this.lastName = lastName; }

    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }

    public String getPhone() { return phone; }
    public void setPhone(String phone) { this.phone = phone; }

    public Boolean getIsStudent() { return isStudent; }
    public void setIsStudent(Boolean isStudent) { this.isStudent = isStudent; }
}
