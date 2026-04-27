package com.example.demo;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api")
public class GameController {

    @Autowired
    private PlayerRepository playerRepository;

    // 测试接口：依然保留 Hello World
    @GetMapping("/hello")
    public String hello() {
        return "Hello World! Server is running.";
    }

    // 新增玩家接口
    @GetMapping("/player")
    public Player addPlayer(@RequestParam String nickname, @RequestParam Integer level) {
        Player p = new Player();
        p.setNickname(nickname);
        p.setLevel(level);
        return playerRepository.save(p); // 直接保存到 MySQL
    }

    // 获取所有玩家接口
    @GetMapping("/players")
    public List<Player> getAllPlayers() {
        return playerRepository.findAll(); // 从 MySQL 查询所有
    }
}