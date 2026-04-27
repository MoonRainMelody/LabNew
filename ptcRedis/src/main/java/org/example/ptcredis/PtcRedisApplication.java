package org.example.ptcredis;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cache.annotation.EnableCaching;

@SpringBootApplication
@EnableCaching
public class PtcRedisApplication {

    public static void main(String[] args) {
        SpringApplication.run(PtcRedisApplication.class, args);
    }

}
