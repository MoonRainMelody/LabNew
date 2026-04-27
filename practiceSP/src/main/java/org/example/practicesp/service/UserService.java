package org.example.practicesp.service;

import org.example.practicesp.entity.User;
import org.example.practicesp.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.List;

@Service
public class UserService {

    @Autowired
    private UserRepository userRepository;

    // 写操作 - 路由到主库
    @Transactional
    public User createUser(User user) {
        return userRepository.save(user);
    }

    // 读操作 - 路由到从库
    public User getUserById(Long id) {
        return userRepository.findById(id).orElse(null);
    }

    // 读操作 - 路由到从库
    public List<User> getAllUsers() {
        return userRepository.findAll();
    }
}
