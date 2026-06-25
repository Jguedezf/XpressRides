package com.xpressrides.backend.dto.response;


public class TripResponse {
    private boolean success;
    private Data data;
    private String message;;

    public TripResponse() {
    }

    public boolean isSuccess() {
        return success;
    }
    public void setSuccess(boolean success) {
        this.success = success;
    }

    public Data getData() {
        return data;
    }

    public void setData(Data data) {
        this.data = data;
    }

    public String getMessage() {
        return message;
    }
    public void setMessage(String message) {
        this.message = message;
    }

    public static class Data {
        private Integer tripId;
        private String state;
        private Drive driver;
        public Integer getTripId() {
            return tripId;
        }
        public void setTripId(Integer tripId) {
            this.tripId = tripId;
        }
        public String getState() {
            return state;
        }
        public void setState(String state) {
            this.state = state;
        }
        public Drive getDriver() {
            return driver;
        }
        public void setDriver(Drive driver) {
            this.driver = driver;
        }
        
    
    }

     public static class Drive {
        private String name;
        private String phone;
        private Double score;
        private Car car;

        public String getName() { return name; }
        public void setName(String name) { this.name = name; }

        public String getPhone() { return phone; }
        public void setPhone(String phone) { this.phone = phone; }

        public Double getScore() { return score; }
        public void setScore(Double score) { this.score = score; }

        public Car getVehicle() { return car; }
        public void setVehiculo(Car car) { this.car = car; }
    }

    public static class Car {
        private String brand;
        private String model;
        private String color;
        private String plate;

        public String getBrand() {
            return brand;
        }
        public void setBrand(String brand) {
            this.brand = brand;
        }
        public String getModel() {
            return model;
        }
        public void setModel(String model) {
            this.model = model;
        }
        public String getColor() {
            return color;
        }
        public void setColor(String color) {
            this.color = color;
        }
        public String getPlate() {
            return plate;
        }
        public void setPlate(String plate) {
            this.plate = plate;
        }

        
        
    }

    
}
