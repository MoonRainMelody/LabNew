-- 从库初始化脚本
USE practice_db;

-- 配置主从复制
CHANGE MASTER TO
  MASTER_HOST='mysql-master',
  MASTER_USER='repl',
  MASTER_PASSWORD='repl123',
  MASTER_PORT=3306,
  MASTER_AUTO_POSITION=1,
  GET_MASTER_PUBLIC_KEY=1;

-- 启动从库复制
START SLAVE;

-- 查看从库状态
SHOW SLAVE STATUS;
