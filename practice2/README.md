# ShardingSphere 主从库读写分离示例

本项目演示如何使用ShardingSphere实现MySQL主从库的读写分离功能。

## 技术栈

- Spring Boot 4.0.5
- ShardingSphere 5.1.2
- MySQL 8.0（Docker容器）
- Spring Data JPA
- Lombok

## 快速开始

### 1. 启动MySQL主从容器

```bash
docker-compose up -d
```

等待容器启动完成，大约需要10-20秒。可以通过以下命令查看容器状态：

```bash
docker-compose ps
```

### 2. 验证主从复制状态

```bash
# 进入从库容器
docker exec -it practice2-slave mysql -uroot -proot -e "SHOW SLAVE STATUS\G"

# 查看 Slave_IO_Running 和 Slave_SQL_Running 是否为 Yes
```

### 3. 启动Spring Boot应用

```bash
mvn spring-boot:run
```

或者使用IDE直接运行`Practice2Application`类。

### 4. 测试API

#### 创建用户（写操作 - 主库）
```bash
curl -X POST http://localhost:8080/users \
  -H "Content-Type: application/json" \
  -d '{"username":"test","email":"test@example.com"}'
```

#### 查询所有用户（读操作 - 从库）
```bash
curl http://localhost:8080/users
```

#### 查询单个用户（读操作 - 从库）
```bash
curl http://localhost:8080/users/1
```

#### 更新用户（写操作 - 主库）
```bash
curl -X PUT http://localhost:8080/users/1 \
  -H "Content-Type: application/json" \
  -d '{"username":"updated","email":"updated@example.com"}'
```

#### 删除用户（写操作 - 主库）
```bash
curl -X DELETE http://localhost:8080/users/1
```

## 验证读写分离

### 方式1：查看ShardingSphere日志

在控制台日志中，可以看到类似以下输出：

- 写操作（INSERT/UPDATE/DELETE）：`Logic SQL: INSERT INTO users ...` → `Actual SQL: master: INSERT INTO users ...`
- 读操作（SELECT）：`Logic SQL: SELECT * FROM users` → `Actual SQL: slave: SELECT * FROM users`

### 方式2：手动验证主从同步

```bash
# 在主库插入数据
docker exec -it practice2-master mysql -uroot -proot \
  -e "USE practice_db; INSERT INTO users(username,email) VALUES('manual','manual@test.com');"

# 在从库查询数据
docker exec -it practice2-slave mysql -uroot -proot \
  -e "USE practice_db; SELECT * FROM users;"
```

### 方式3：查看数据库连接

```bash
# 查看主库连接
docker exec -it practice2-master mysql -uroot -proot \
  -e "SHOW PROCESSLIST;"

# 查看从库连接
docker exec -it practice2-slave mysql -uroot -proot \
  -e "SHOW PROCESSLIST;"
```

## 架构说明

### 主从复制架构

```
┌─────────────────┐
│  Application    │
│  (Spring Boot)  │
└────────┬────────┘
         │
         │ ShardingSphere代理
         │
    ┌────┴────┐
    │         │
┌───▼───┐  ┌─▼─────┐
│ Master │  │ Slave │
│ :3306  │  │ :3307 │
└───────┘  └───────┘
    │         │
    └────┬────┘
         │
    binlog复制
```

### 读写分离规则

- **写操作**（INSERT/UPDATE/DELETE） → 主库（master:3306）
- **读操作**（SELECT） → 从库（slave:3307）
- **事务内的操作** → 全部走主库，保证一致性

## 配置说明

### ShardingSphere配置（application.yml）

```yaml
spring:
  shardingsphere:
    datasource:
      names: master,slave
      master:
        jdbc-url: jdbc:mysql://localhost:3306/practice_db
      slave:
        jdbc-url: jdbc:mysql://localhost:3307/practice_db
    rules:
      readwrite-splitting:
        data-sources:
          readwrite-data-source:
            write-data-source-name: master
            read-data-source-names: slave
            load-balancer-name: round-robin
```

### Docker配置（docker-compose.yml）

- **主库**：server-id=1，开启binlog
- **从库**：server-id=2，配置relay log，只读模式

## 故障排查

### 主从复制失败

1. 检查主库binlog是否开启：
   ```bash
   docker exec -it practice2-master mysql -uroot -proot -e "SHOW VARIABLES LIKE 'log_bin';"
   ```

2. 查看从库复制状态：
   ```bash
   docker exec -it practice2-slave mysql -uroot -proot -e "SHOW SLAVE STATUS\G"
   ```

3. 重置从库复制：
   ```bash
   docker exec -it practice2-slave mysql -uroot -proot \
     -e "STOP SLAVE; RESET SLAVE; START SLAVE;"
   ```

### 应用连接失败

1. 确认Docker容器已启动：
   ```bash
   docker-compose ps
   ```

2. 检查网络连通性：
   ```bash
   telnet localhost 3306
   telnet localhost 3307
   ```

3. 查看应用日志，确认数据源配置正确

## 清理环境

```bash
# 停止并删除容器
docker-compose down

# 删除数据卷（可选）
docker-compose down -v
```

## 参考资料

- [ShardingSphere官方文档](https://shardingsphere.apache.org/document/current/cn/overview/)
- [MySQL主从复制](https://dev.mysql.com/doc/refman/8.0/en/replication.html)
- [Spring Data JPA](https://spring.io/projects/spring-data-jpa)
