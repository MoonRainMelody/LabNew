package org.example.lab2.controller;

import org.example.lab2.entity.User;
import org.example.lab2.service.UserService;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/user")
public class UserController {

    private final UserService userService;

    public UserController(UserService userService) {
        this.userService = userService;
    }

    @PostMapping("/save")
    public String save(@RequestBody User user) {
        userService.save(user);
        return "success";
    }

    @GetMapping("/find")
    public User find(@RequestParam("id") Long id) {
        return userService.findById(id);
    }

    @GetMapping("/list")
    public List<User> list() {
        return userService.findAll();
    }
}
