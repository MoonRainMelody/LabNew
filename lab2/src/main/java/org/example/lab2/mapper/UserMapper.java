package org.example.lab2.mapper;

import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.example.lab2.entity.User;

import java.util.List;

@Mapper
public interface UserMapper {

    void save(User user);

    User findById(@Param("userId") Long userId);

    List<User> findAll();
}
