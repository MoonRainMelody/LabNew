#!/bin/bash
# 从库初始化脚本：配置主从复制

# 等待MySQL完全启动
sleep 30

# 配置从库连接到主库
mysql -uroot -proot123 << EOF
  -- 设置主库信息
  CHANGE MASTER TO
    MASTER_HOST='mysql-master',
    MASTER_USER='repl_user',
    MASTER_PASSWORD='repl_pass',
    MASTER_PORT=3306,
    MASTER_AUTO_POSITION=1;

  -- 启动从库复制
  START SLAVE;

  -- 显示从库状态
  SHOW SLAVE STATUS\G
EOF

echo "从库复制配置完成！"
