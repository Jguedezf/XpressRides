package com.xpressrides.backend;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class XpressridesApplication {

	public static void main(String[] args) {
		SpringApplication.run(XpressridesApplication.class, args);
	}
}
