#!/bin/bash
# 验证MySQL主从复制状态

echo "========================================"
echo "MySQL主从复制状态验证"
echo "========================================"
echo ""

echo "1. 检查主库状态..."
echo "主库GTID状态:"
docker exec -i mysql-master mysql -uroot -proot123 -e "SHOW MASTER STATUS\G" 2>/dev/null || echo "主库未就绪"

echo ""
echo "主库测试数据:"
docker exec -i mysql-master mysql -uroot -proot123 -e "SELECT * FROM test_db.users;" 2>/dev/null || echo "主库未就绪"

echo ""
echo "========================================"
echo ""

echo "2. 检查从库复制状态..."
echo "复制线程状态:"
docker exec -i mysql-slave mysql -uroot -proot123 -e "SHOW SLAVE STATUS\G" 2>/dev/null | grep -E "Slave_IO_Running|Slave_SQL_Running|Last_Error" || echo "从库未就绪"

echo ""
echo "从库同步数据:"
docker exec -i mysql-slave mysql -uroot -proot123 -e "SELECT * FROM test_db.users;" 2>/dev/null || echo "从库未就绪"

echo ""
echo "========================================"
echo ""

echo "3. 测试实时同步..."
echo "在主库插入测试数据..."
docker exec -i mysql-master mysql -uroot -proot123 -e "INSERT INTO test_db.users(name, email) VALUES ('验证测试', 'verify@test.com');" 2>/dev/null && echo "插入成功" || echo "插入失败"

echo ""
echo "等待2秒后检查从库..."
sleep 2

echo ""
echo "从库查询新数据:"
docker exec -i mysql-slave mysql -uroot -proot123 -e "SELECT * FROM test_db.users WHERE email='verify@test.com';" 2>/dev/null

echo ""
echo "========================================"
echo "验证完成！"
echo "========================================"
echo ""
echo "如果看到复制状态显示:"
echo "  Slave_IO_Running: Yes"
echo "  Slave_SQL_Running: Yes"
echo "  Last_Error: (空)"
echo ""
echo "并且从库能看到主库插入的数据，说明主从复制工作正常！"
echo ""
