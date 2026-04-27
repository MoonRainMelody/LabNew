package org.example.lab2.service;

import org.example.lab2.entity.User;
import org.example.lab2.mapper.UserMapper;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.List;

@Service
public class UserService {

    private final UserMapper userMapper;

    public UserService(UserMapper userMapper) {
        this.userMapper = userMapper;
    }

    public void save(User user) {
        user.setCreateTime(LocalDateTime.now());
        userMapper.save(user);
    }

    public User findById(Long userId) {
        return userMapper.findById(userId);
    }

    public List<User> findAll() {
        return userMapper.findAll();
    }
}
