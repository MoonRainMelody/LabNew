package com.example.demo; // 确保这里的包名和你自己的一致

import jakarta.persistence.*;

@Entity
@Table(name = "players") // 数据库里的表名
public class Player {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String nickname;
    private Integer level;

    // Getter 和 Setter (必须有，否则 Spring 无法赋值)
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getNickname() { return nickname; }
    public void setNickname(String nickname) { this.nickname = nickname; }
    public Integer getLevel() { return level; }
    public void setLevel(Integer level) { this.level = level; }
}