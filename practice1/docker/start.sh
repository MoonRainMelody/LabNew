#!/bin/bash
# MySQL主从复制集群快速启动脚本

echo "========================================"
echo "MySQL GTID 主从复制集群启动脚本"
echo "========================================"
echo ""

# 检查Docker是否运行
if ! docker info > /dev/null 2>&1; then
    echo "错误: Docker未运行，请先启动Docker"
    exit 1
fi

echo "1. 启动MySQL集群..."
docker-compose up -d

echo ""
echo "2. 等待容器启动（约30秒）..."
sleep 30

echo ""
echo "3. 检查容器状态..."
docker-compose ps

echo ""
echo "========================================"
echo "集群启动完成！"
echo "========================================"
echo ""
echo "主库连接信息:"
echo "  Host: localhost"
echo "  Port: 3306"
echo "  User: root"
echo "  Password: root123"
echo ""
echo "从库连接信息:"
echo "  Host: localhost"
echo "  Port: 3307"
echo "  User: root"
echo "  Password: root123"
echo ""
echo "运行以下命令验证主从复制:"
echo "  bash verify.sh"
echo ""
