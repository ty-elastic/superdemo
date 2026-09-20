package com.example.recorder;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableAsync;

@SpringBootApplication
@EnableAsync
public class Main {
	public final static String ATTRIBUTE_PREFIX = "com.example";

	public static void main(String[] args) {
		SpringApplication.run(Main.class, args);
	}

}