# Redis 高可用集群（一主二从三哨兵）工程实施方案

## 一、 架构与目录设计

为了满足实验要求的网络隔离（Docker自定义桥接网络）和数据持久化（Volume映射），请工程师在宿主机上创建以下标准的目录结构，以便统一管理配置和数据。

### 1.1 目录结构
```text
redis-cluster-lab/
├── docker-compose.yml          # 核心编排文件
├── redis/
│   ├── master/
│   │   ├── conf/redis.conf     # 主节点配置
│   │   └── data/               # 主节点数据持久化目录
│   ├── slave1/
│   │   ├── conf/redis.conf     # 从节点1配置
│   │   └── data/               # 从节点1数据持久化目录
│   └── slave2/
│       ├── conf/redis.conf     # 从节点2配置
│       └── data/               # 从节点2数据持久化目录
└── sentinel/
    ├── sentinel1/
    │   └── conf/sentinel.conf  # 哨兵1配置
    ├── sentinel2/
    │   └── conf/sentinel.conf  # 哨兵2配置
    └── sentinel3/
        └── conf/sentinel.conf  # 哨兵3配置
```
*(注：工程师需要在所有 `data` 目录上确保读写权限，避免 Docker 挂载时出现无权写入的问题。)*

---

## 二、 核心配置文件编写

### 2.1 Redis 节点配置 (`redis.conf`)

**主节点 (redis/master/conf/redis.conf):**
```properties
# 绑定所有网络接口
bind 0.0.0.0
# 端口
port 6379
# 开启AOF持久化
appendonly yes
# RDB持久化策略（默认）
save 900 1
save 300 10
save 60 10000
# 数据目录
dir /data
```

**从节点 1 & 2 (redis/slave1/conf/redis.conf & redis/slave2/conf/redis.conf):**
内容与主节点基本一致，只需增加一行配置，指向主节点：
```properties
bind 0.0.0.0
port 6379
appendonly yes
dir /data
# 声明当前节点为从节点，指向 master 容器
replicaof redis-master 6379
```

### 2.2 Sentinel 节点配置 (`sentinel.conf`)

哨兵的配置在故障转移过程中会被 Sentinel 进程自动重写，因此**强烈建议**在 Docker 容器启动时使用副本运行，或者确保挂载的文件有写权限。

**哨兵 1/2/3 配置文件内容完全相同：**
```properties
port 26379
dir /tmp
# 监控名为 mymaster 的主节点，容器名为 redis-master，端口 6379，Quorum 设置为 2
sentinel monitor mymaster redis-master 6379 2
# 主节点多久不响应心跳判定为主观下线（毫秒），此处设为5秒方便实验观察
sentinel down-after-milliseconds mymaster 5000
# 故障转移超时时间（毫秒）
sentinel failover-timeout mymaster 10000
# 开启 hostname 解析（Docker 网络环境下必须开启，否则无法解析容器名）
sentinel resolve-hostnames yes
sentinel announce-hostnames yes
```

---

## 三、 Docker Compose 编排实现 (`docker-compose.yml`)

该配置实现了全局自定义网络（`redis-net`）以及各节点的数据卷挂载。

```yaml
version: '3.8'

networks:
  redis-net:
    driver: bridge # 满足网络隔离要求

services:
  # --- Redis 层 ---
  redis-master:
    image: redis:7.0
    container_name: redis-master
    command: redis-server /etc/redis/redis.conf
    volumes:
      - ./redis/master/conf/redis.conf:/etc/redis/redis.conf
      - ./redis/master/data:/data
    networks:
      - redis-net
    ports:
      - "6379:6379"

  redis-slave1:
    image: redis:7.0
    container_name: redis-slave1
    command: redis-server /etc/redis/redis.conf
    volumes:
      - ./redis/slave1/conf/redis.conf:/etc/redis/redis.conf
      - ./redis/slave1/data:/data
    networks:
      - redis-net
    depends_on:
      - redis-master

  redis-slave2:
    image: redis:7.0
    container_name: redis-slave2
    command: redis-server /etc/redis/redis.conf
    volumes:
      - ./redis/slave2/conf/redis.conf:/etc/redis/redis.conf
      - ./redis/slave2/data:/data
    networks:
      - redis-net
    depends_on:
      - redis-master

  # --- Sentinel 层 ---
  sentinel1:
    image: redis:7.0
    container_name: redis-sentinel1
    # 巧妙处理权限问题：将宿主机配置拷贝至容器内执行，避免只读挂载导致哨兵无法重写配置
    command: >
      sh -c "cp /conf/sentinel.conf /etc/redis/sentinel.conf && 
      chmod 777 /etc/redis/sentinel.conf && 
      redis-sentinel /etc/redis/sentinel.conf"
    volumes:
      - ./sentinel/sentinel1/conf/sentinel.conf:/conf/sentinel.conf
    networks:
      - redis-net
    depends_on:
      - redis-master
      - redis-slave1
      - redis-slave2

  sentinel2:
    image: redis:7.0
    container_name: redis-sentinel2
    command: >
      sh -c "cp /conf/sentinel.conf /etc/redis/sentinel.conf && 
      chmod 777 /etc/redis/sentinel.conf && 
      redis-sentinel /etc/redis/sentinel.conf"
    volumes:
      - ./sentinel/sentinel2/conf/sentinel.conf:/conf/sentinel.conf
    networks:
      - redis-net
    depends_on:
      - redis-master

  sentinel3:
    image: redis:7.0
    container_name: redis-sentinel3
    command: >
      sh -c "cp /conf/sentinel.conf /etc/redis/sentinel.conf && 
      chmod 777 /etc/redis/sentinel.conf && 
      redis-sentinel /etc/redis/sentinel.conf"
    volumes:
      - ./sentinel/sentinel3/conf/sentinel.conf:/conf/sentinel.conf
    networks:
      - redis-net
    depends_on:
      - redis-master
```

---

## 四、 实验验收与故障模拟指南（交付测试清单）

请工程师按照以下步骤运行并抓取实验报告所需的截图和日志：

### 第一步：启动集群
在 `docker-compose.yml` 所在目录执行：
```bash
docker-compose up -d
```

### 第二步：验证主从复制（截图点 1）
进入 Master 容器查看状态：
```bash
docker exec -it redis-master redis-cli info replication
```
**期望输出：** `role:master` 且 `connected_slaves:2`。

### 第三步：验证哨兵监控
进入 Sentinel 容器查看：
```bash
docker exec -it redis-sentinel1 redis-cli -p 26379 sentinel masters
```
**期望输出：** 包含 `num-slaves 2` 以及 `num-other-sentinels 2`（表示集群健康）。

### 第四步：故障注入与验证（截图点 2）
1. 宕机主节点：
   ```bash
   docker stop redis-master
   ```
2. 立即实时查看哨兵日志：
   ```bash
   docker logs -f redis-sentinel1
   ```
   **期望观察到的关键日志（供实验报告截取）：**
   * `+sdown master mymaster` （主观下线）
   * `+odown master mymaster` （客观下线，达到 Quorum 票数）
   * `+vote-for-leader` （选举领头哨兵）
   * `+failover-end` （故障转移完成）
   * `+switch-master` （切换新主节点，记录新主节点的 IP/容器名）

3. 恢复原主节点：
   ```bash
   docker start redis-master
   docker exec -it redis-master redis-cli info replication
   ```
   **期望结果：** 此时 `role` 应该变为 `slave`，说明它已被哨兵降级并重新加入集群。

---

## 五、 实验报告理论问题解答（辅助工程师编写文档）

针对实验要求中的两个重点理论问题，提供以下标准解答供报告使用：

**1. 主节点宕机后，哨兵如何选出新主节点？（选举算法逻辑）**
整个过程分为两步（Raft 算法思想体现）：
* **领头哨兵选举：** 当一个哨兵发现 Master 客观下线（ODOWN）后，会发起投票请求其他哨兵选举自己为 Leader。只要获得半数以上票数（3个哨兵中拿到至少2票），该哨兵就成为 Leader，全权负责本次故障转移。
* **新主节点挑选：** 领头哨兵会在健康的从节点中按照以下顺序挑选新的 Master：
  1. 过滤掉不健康的节点（如网络断开、响应慢）。
  2. 比较优先级（`slave-priority` 越小越高）。
  3. 比较复制偏移量（`repl-offset` 最大的胜出，代表其数据最全、最接近原主节点）。
  4. 若偏移量相同，比较运行 ID（`Run ID` 字典序最小的胜出）。

**2. 若哨兵节点只部署 2 个，在主节点宕机时可能会出现什么问题？**
在分布式系统中，这是经典的**高可用失效与脑裂风险**问题，也是 CAP 理论中对 C（一致性）和 P（分区容错性）的取舍：
* **无法完成故障转移：** 实验要求法定人数（Quorum）为 2。如果一共只有 2 个哨兵，当其中一台哨兵所在宿主机/网络发生故障挂掉时，剩下的 1 台哨兵哪怕发现了 Master 宕机，也**永远凑不够 2 票**来选举 Leader。这就导致整个集群无法执行 Failover，直接失去可用性。
* **为了高可用，必须保持奇数：** 哨兵集群的容错机制要求大多数（Majority）存活才能工作。3 个哨兵允许 1 个宕机；而 2 个哨兵允许 0 个宕机（挂掉1个系统就瘫痪），没有任何容灾能力。