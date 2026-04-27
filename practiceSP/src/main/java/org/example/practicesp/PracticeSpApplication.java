package org.example.practicesp;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;

@SpringBootApplication
@EnableJpaRepositories(basePackages = "org.example.practicesp.repository")
public class PracticeSpApplication {

    public static void main(String[] args) {
        SpringApplication.run(PracticeSpApplication.class, args);
    }

}
