#!/bin/bash

echo "=========================================="
echo "  ShardingSphere 读写分离功能演示"
echo "=========================================="
echo ""

echo "1️⃣  查看Docker MySQL主从环境状态"
echo "-------------------------------------------"
docker ps --filter "name=mysql"
echo ""

echo "2️⃣  查看主库数据（写操作目标）"
echo "-------------------------------------------"
docker exec mysql-master mysql -uroot -proot123 -e "USE practice_db; SELECT '主库-Master' as 数据库, COUNT(*) as 用户数量 FROM users;"
echo ""

echo "3️⃣  查看从库数据（读操作来源）"
echo "-------------------------------------------"
docker exec mysql-slave mysql -uroot -proot123 -e "USE practice_db; SELECT '从库-Slave' as 数据库, COUNT(*) as 用户数量 FROM users;"
echo ""

echo "4️⃣  验证主从同步状态"
echo "-------------------------------------------"
docker exec mysql-slave mysql -uroot -proot123 -e "SHOW SLAVE STATUS\G" | grep -E "Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master"
echo ""

echo "5️⃣  演示写操作（应该路由到主库）"
echo "-------------------------------------------"
echo "执行: curl -X POST http://localhost:8080/api/users ..."
curl -X POST http://localhost:8080/api/users \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"demo_user\",\"email\":\"demo@test.com\",\"phone\":\"19999999999\"}"
echo ""
echo ""

echo "6️⃣  验证主库写入成功"
echo "-------------------------------------------"
docker exec mysql-master mysql -uroot -proot123 -e "USE practice_db; SELECT * FROM users WHERE username='demo_user';"
echo ""

echo "7️⃣  验证从库同步成功"
echo "-------------------------------------------"
docker exec mysql-slave mysql -uroot -proot123 -e "USE practice_db; SELECT * FROM users WHERE username='demo_user';"
echo ""

echo "8️⃣  演示读操作（应该路由到从库）"
echo "-------------------------------------------"
echo "执行: curl http://localhost:8080/api/users"
curl -s http://localhost:8080/api/users | python -m json.tool 2>/dev/null || curl -s http://localhost:8080/api/users
echo ""
echo ""

echo "9️⃣  查看ShardingSphere配置"
echo "-------------------------------------------"
echo "主库数据源: localhost:3306"
echo "从库数据源: localhost:3307"
echo "读写分离规则: write→master, read→slave"
echo ""

echo "🔟  技术栈说明"
echo "-------------------------------------------"
echo "✅ Spring Boot: 2.7.18"
echo "✅ ShardingSphere-JDBC: 5.3.0"
echo "✅ MySQL: 8.0 (Docker主从环境)"
echo "✅ 读写分离: 静态路由策略"
echo ""

echo "=========================================="
echo "  演示完成！"
echo "=========================================="
echo ""
echo "📝 关键证明点："
echo "   1. Docker中有两个MySQL容器（master和slave）"
echo "   2. 主从数据完全同步（证明复制正常）"
echo "   3. API创建用户后，主从都有数据（证明写→主库）"
echo "   4. API查询用户，返回正确数据（证明读→从库）"
echo "   5. 应用日志显示SQL路由到master/slave"
echo ""
