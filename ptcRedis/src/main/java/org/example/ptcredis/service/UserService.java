package org.example.ptcredis.service;

import org.example.ptcredis.model.User;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.CachePut;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;

import java.util.HashMap;
import java.util.Map;

@Service
public class UserService {

    private static final Logger log = LoggerFactory.getLogger(UserService.class);
    private final Map<Long, User> userStore = new HashMap<>();

    @Cacheable(value = "users", key = "#id", unless = "#result == null")
    public User getUserById(Long id) {
        log.info(">>> 查询数据库：getUserById({})", id);
        simulateSlowQuery();
        return userStore.get(id);
    }

    @CachePut(value = "users", key = "#user.id")
    public User saveOrUpdateUser(User user) {
        log.info(">>> 保存用户：{}", user);
        userStore.put(user.getId(), user);
        return user;
    }

    @CacheEvict(value = "users", key = "#id")
    public void deleteUser(Long id) {
        log.info(">>> 删除用户：id={}", id);
        userStore.remove(id);
    }

    private void simulateSlowQuery() {
        try {
            Thread.sleep(1000);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
}
