# 向老师演示的快速参考卡

## ⚡ 30秒快速演示

```bash
cd docker
./demo.sh
```

## 📋 演示要点总结

### ✅ 必须展示的核心内容

1. **容器运行状态** - 两个容器都是healthy
2. **GTID启用证明** - `SELECT @@GTID_MODE` 返回ON
3. **复制线程正常** - IO和SQL线程都是Yes
4. **数据一致性** - 主从数据完全一样
5. **实时同步效果** - 主库插入，从库立即可见

### 演示流程（5分钟版本）

```bash
# 第1步：启动并检查状态
docker-compose ps

# 第2步：证明GTID启用
docker exec -i mysql-master mysql -uroot -proot123 -e "SELECT @@SERVER_ID, @@GTID_MODE;"
docker exec -i mysql-slave mysql -uroot -proot123 -e "SELECT @@SERVER_ID, @@GTID_MODE;"

# 第3步：展示数据一致性
docker exec -i mysql-master mysql -uroot -proot123 -e "SELECT * FROM test_db.users;"
docker exec -i mysql-slave mysql -uroot -proot123 -e "SELECT * FROM test_db.users;"

# 第4步：证明复制正常（关键！）
docker exec -i mysql-slave mysql -uroot -proot123 -e "SHOW SLAVE STATUS\G" | grep -E "Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master"

# 第5步：实时同步演示（最直观！）
docker exec -i mysql-master mysql -uroot -proot123 -e "INSERT INTO test_db.users(name, email) VALUES ('演示', 'demo@test.com');"
sleep 2
docker exec -i mysql-slave mysql -uroot -proot123 -e "SELECT * FROM test_db.users WHERE email='demo@test.com';"

# 第6步：从库只读保护
docker exec -i mysql-slave mysql -uroot -proot123 -e "INSERT INTO test_db.users(name, email) VALUES ('失败', 'fail@test.com';"
# 会报错，证明从库只读
```

### 关键指标说明

| 指标 | 命令 | 期望结果 |
|------|------|----------|
| GTID状态 | `SELECT @@GTID_MODE` | ON |
| Server ID | `SELECT @@SERVER_ID` | 主库=1, 从库=2 |
| IO线程 | `SHOW SLAVE STATUS` | Slave_IO_Running: Yes |
| SQL线程 | `SHOW SLAVE STATUS` | Slave_SQL_Running: Yes |
| 延迟 | `SHOW SLAVE STATUS` | Seconds_Behind_Master: 0 |
| 错误 | `SHOW SLAVE STATUS` | Last_Error: (空) |

### 演示话术

```
"老师，我使用Docker搭建了MySQL主从复制集群。

关键特性：
1. 启用了GTID模式，每个事务有全局唯一ID
2. 主库server-id=1，从库server-id=2
3. 复制线程正常运行，无延迟
4. 从库配置为只读，保证数据一致性

现在我演示实时数据同步效果..."
```

### 常见问题应对

**Q: 如果演示时复制延迟怎么办？**
A: 说"网络稍有延迟，这是正常现象"，然后等待几秒再查询

**Q: 如果脚本报错怎么办？**
A: 运行 `docker-compose restart`，等待20秒后重新演示

**Q: 老师问配置文件在哪里？**
A: `mysql/master/my.cnf` 和 `mysql/slave/my.cnf`

### 相关文件

- `demo.sh` - 自动演示脚本
- `DEMO_GUIDE.md` - 详细演示指南
- `docker-compose.yml` - 容器编排配置
- `mysql/master/my.cnf` - 主库GTID配置
- `mysql/slave/my.cnf` - 从库GTID配置
