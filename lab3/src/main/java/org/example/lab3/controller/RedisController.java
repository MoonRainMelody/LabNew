package org.example.lab3.controller;

import org.example.lab3.dto.RedisRequest;
import org.example.lab3.service.RedisService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;

@RestController
@RequestMapping("/api/redis")
public class RedisController {

    private final RedisService redisService;

    public RedisController(RedisService redisService) {
        this.redisService = redisService;
    }

    @PostMapping("/set")
    public ResponseEntity<Map<String, Object>> set(@RequestBody RedisRequest request) {
        redisService.set(request.getKey(), request.getValue());
        return ResponseEntity.ok(response(true, "OK", null));
    }

    @GetMapping("/get/{key}")
    public ResponseEntity<Map<String, Object>> get(@PathVariable String key) {
        String value = redisService.get(key);
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("key", key);
        data.put("value", value);
        return ResponseEntity.ok(response(value != null, value != null ? "found" : "not found", data));
    }

    @DeleteMapping("/delete/{key}")
    public ResponseEntity<Map<String, Object>> delete(@PathVariable String key) {
        Boolean deleted = redisService.delete(key);
        return ResponseEntity.ok(response(Boolean.TRUE.equals(deleted), deleted ? "deleted" : "not found", null));
    }

    @GetMapping("/exists/{key}")
    public ResponseEntity<Map<String, Object>> exists(@PathVariable String key) {
        Boolean exists = redisService.hasKey(key);
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("key", key);
        data.put("exists", exists);
        return ResponseEntity.ok(response(true, exists ? "exists" : "not exists", data));
    }

    @GetMapping("/keys")
    public ResponseEntity<Map<String, Object>> keys() {
        Set<String> keys = redisService.keys("*");
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("count", keys != null ? keys.size() : 0);
        data.put("keys", keys);
        return ResponseEntity.ok(response(true, "OK", data));
    }

    @PostMapping("/hash/set")
    public ResponseEntity<Map<String, Object>> hashSet(@RequestBody RedisRequest request) {
        redisService.hashPut(request.getKey(), "field", request.getValue());
        return ResponseEntity.ok(response(true, "OK", null));
    }

    @GetMapping("/hash/get/{key}")
    public ResponseEntity<Map<String, Object>> hashGet(@PathVariable String key) {
        Map<Object, Object> entries = redisService.hashGetAll(key);
        return ResponseEntity.ok(response(true, "OK", entries));
    }

    private Map<String, Object> response(boolean success, String message, Object data) {
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("success", success);
        result.put("message", message);
        result.put("data", data);
        result.put("timestamp", Instant.now().toString());
        return result;
    }
}
