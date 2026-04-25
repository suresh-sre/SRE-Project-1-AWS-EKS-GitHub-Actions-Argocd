package com.example;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@SpringBootApplication
@RestController
public class App {

    public static void main(String[] args) {
        SpringApplication.run(App.class, args);
    }

    @GetMapping("/")
    public String home() {
        return "Hello from GitHub Actions and ArgoCD CI/CD Pipeline Demo Application!";
    }

    @GetMapping("/health")
    public String health() {
        return "OK";
    }

    @GetMapping("/info")
    public String info() {
        return "Version: 1.0.0 | Environment: " + System.getenv().getOrDefault("ENVIRONMENT", "unknown");
    }
}
