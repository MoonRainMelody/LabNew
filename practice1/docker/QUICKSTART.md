# MySQL GTID 主从复制 - 快速参考

## 📁 文件结构
```
docker/
├── docker-compose.yml      # 容器编排配置
├── README.md              # 详细使用说明
├── QUICKSTART.md          # 本文件
├── start.sh               # 一键启动脚本
├── verify.sh              # 验证脚本
├── stop.sh                # 停止脚本
├── init-slave.sh          # 从库初始化脚本
└── mysql/
    ├── master/my.cnf      # 主库配置（GTID开启）
    ├── slave/my.cnf       # 从库配置（只读+GTID）
    └── init/
        └── init.sql       # 初始化测试数据
```

## 🚀 三步启动

### 第一步：启动集群
```bash
cd docker
./start.sh
```
或手动启动：
```bash
cd docker
docker-compose up -d
```

### 第二步：验证状态
```bash
./verify.sh
```

### 第三步：测试同步
```bash
# 主库插入数据
docker exec -i mysql-master mysql -uroot -proot123 \
  -e "INSERT INTO test_db.users(name, email) VALUES ('test', 'test@test.com');"

# 从库查询验证
docker exec -i mysql-slave mysql -uroot -proot123 \
  -e "SELECT * FROM test_db.users WHERE email='test@test.com';"
```

## 📊 连接信息

| 服务 | 地址 | 端口 | 用户 | 密码 |
|------|------|------|------|------|
| 主库 | localhost | 3306 | root | root123 |
| 从库 | localhost | 3307 | root | root123 |

## 🔍 关键验证命令

### 检查主库
```bash
docker exec -i mysql-master mysql -uroot -proot123 -e "SHOW MASTER STATUS\G"
docker exec -i mysql-master mysql -uroot -proot123 -e "SELECT * FROM test_db.users;"
```

### 检查从库
```bash
docker exec -i mysql-slave mysql -uroot -proot123 -e "SHOW SLAVE STATUS\G" | grep -E "Slave_IO_Running|Slave_SQL_Running|Last_Error"
docker exec -i mysql-slave mysql -uroot -proot123 -e "SELECT * FROM test_db.users;"
```

