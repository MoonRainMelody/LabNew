#!/bin/bash
# MySQL主从复制集群停止脚本

echo "========================================"
echo "MySQL主从复制集群停止脚本"
echo "========================================"
echo ""

echo "选择停止方式:"
echo "1) 停止容器（保留数据）"
echo "2) 停止并删除容器（保留数据卷）"
echo "3) 完全清理（包括数据卷）"
echo ""
read -p "请选择 [1-3]: " choice

case $choice in
    1)
        echo "停止容器..."
        docker-compose stop
        echo "容器已停止，数据保留"
        ;;
    2)
        echo "停止并删除容器..."
        docker-compose down
        echo "容器已删除，数据卷保留"
        ;;
    3)
        echo "完全清理（包括数据卷）..."
        docker-compose down -v
        echo "已完全清理，下次启动将重新初始化"
        ;;
    *)
        echo "无效选择"
        exit 1
        ;;
esac

echo ""
echo "完成！"
