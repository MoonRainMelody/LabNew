package org.example.lab3;

import org.example.lab3.service.RedisService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

import java.util.concurrent.TimeUnit;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
class Lab3ApplicationTests {

    @Autowired
    private RedisService redisService;

    @Test
    void contextLoads() {
    }

    @Test
    void testRedisSetAndGet() {
        String key = "test:key";
        String value = "hello-redis";

        redisService.set(key, value);
        String result = redisService.get(key);

        assertEquals(value, result);

        // cleanup
        redisService.delete(key);
    }

    @Test
    void testRedisDelete() {
        String key = "test:delete";

        redisService.set(key, "to-be-deleted");
        assertTrue(redisService.hasKey(key));

        Boolean deleted = redisService.delete(key);
        assertTrue(deleted);
        assertFalse(redisService.hasKey(key));
    }

    @Test
    void testRedisExpire() throws InterruptedException {
        String key = "test:expire";

        redisService.set(key, "short-lived");
        redisService.expire(key, 1, TimeUnit.SECONDS);

        assertTrue(redisService.hasKey(key));
        Thread.sleep(1500);
        assertFalse(redisService.hasKey(key));
    }

    @Test
    void testRedisHashSetAndGet() {
        String key = "test:hash";

        redisService.hashPut(key, "field1", "value1");
        redisService.hashPut(key, "field2", "value2");

        var entries = redisService.hashGetAll(key);
        assertEquals("value1", entries.get("field1"));
        assertEquals("value2", entries.get("field2"));

        // cleanup
        redisService.delete(key);
    }
}
