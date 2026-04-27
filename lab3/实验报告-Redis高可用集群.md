# 实验三 Redis 高可用集群（一主二从三哨兵）实验报告

---

## 一、实验目的

1. 理解 Redis 主从复制（Master-Slave Replication）的基本原理
2. 掌握 Redis Sentinel（哨兵）实现高可用的机制
3. 学会使用 Docker 构建分布式系统实验环境
4. 掌握 Redis 故障转移（Failover）过程
5. 理解 CAP 理论在 Redis 高可用中的体现

---

## 二、实验环境

| 项目 | 说明 |
|------|------|
| 操作系统 | Windows 11 Home (Docker Desktop WSL2) |
| Docker | Docker Desktop for Windows |
| Redis 镜像 | redis:7.0 |
| 容器数量 | 6 个（1 主 + 2 从 + 3 哨兵） |
| 网络模式 | Docker 自定义桥接网络 `redis-net` |
| 应用框架 | Spring Boot 4.0.6 + Spring Data Redis (Lettuce) |

---

## 三、实验内容

### 1. 拓扑结构设计

本实验构建了一个包含 6 个容器的 Redis 高可用集群，拓扑结构如下：

```
                    ┌─────────────────┐
                    │  redis-sentinel1 │ :26379
                    └────────┬────────┘
                             │
┌──────────────┐    ┌────────┴────────┐    ┌──────────────┐
│redis-sentinel2│    │   redis-net     │    │redis-sentinel3│
│   :26380     │    │  (bridge网络)    │    │   :26381     │
└──────────────┘    └────────┬────────┘    └──────────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
      ┌───────┴───────┐ ┌───┴───────┐ ┌───┴───────────┐
      │ redis-master  │ │redis-slave1│ │ redis-slave2  │
      │   :6379       │ │  :6380     │ │  :6381        │
      │  (Master)     │ │  (Slave)   │ │  (Slave)      │
      └───────────────┘ └───────────┘ └───────────────┘
```

**集群组成：**

- **Redis 存储层**：1 个主节点（`redis-master`），2 个从节点（`redis-slave1`、`redis-slave2`）
- **Sentinel 监控层**：3 个哨兵节点（`redis-sentinel1/2/3`），法定人数 Quorum = 2

**目录结构：**

```
redis-cluster-lab/
├── docker-compose.yml
├── redis/
│   ├── master/
│   │   └── conf/redis.conf
│   ├── slave1/
│   │   └── conf/redis.conf
│   └── slave2/
│       └── conf/redis.conf
└── sentinel/
    ├── sentinel1/
    │   └── conf/sentinel.conf
    ├── sentinel2/
    │   └── conf/sentinel.conf
    └── sentinel3/
        └── conf/sentinel.conf
```

---

### 2. 配置文件准备

#### 2.1 Redis 主节点配置 (`redis/master/conf/redis.conf`)

```properties
bind 0.0.0.0
port 6379
appendonly yes
save 900 1
save 300 10
save 60 10000
dir /data
repl-diskless-sync no
```

**配置说明：**
- `bind 0.0.0.0`：绑定所有网络接口，允许容器间通信
- `appendonly yes`：开启 AOF 持久化
- `save ...`：RDB 持久化策略（900秒内至少1次修改 / 300秒内至少10次 / 60秒内至少10000次）
- `repl-diskless-sync no`：禁用无盘复制，使用基于磁盘的同步方式（避免 Docker 环境下兼容性问题）

#### 2.2 Redis 从节点配置 (`redis/slave1/conf/redis.conf` 和 `slave2/conf/redis.conf`)

```properties
bind 0.0.0.0
port 6379
appendonly yes
dir /data
replicaof redis-master 6379
```

**配置说明：**
- 与主节点基本一致，增加 `replicaof redis-master 6379` 指向主节点容器
- `redis-master` 是 Docker 内部 DNS 可解析的容器名

#### 2.3 Sentinel 哨兵配置 (`sentinel/sentinel{1,2,3}/conf/sentinel.conf`，三份完全相同)

```properties
port 26379
dir /tmp
sentinel monitor mymaster redis-master 6379 2
sentinel down-after-milliseconds mymaster 5000
sentinel failover-timeout mymaster 10000
sentinel resolve-hostnames yes
sentinel announce-hostnames yes
```

**配置说明：**
- `sentinel monitor mymaster redis-master 6379 2`：监控名为 `mymaster` 的主节点，Quorum 设为 2
- `down-after-milliseconds 5000`：主节点 5 秒无响应判定为主观下线（SDOWN）
- `failover-timeout 10000`：故障转移超时时间 10 秒
- `resolve-hostnames yes`：开启主机名解析（Docker 网络环境必需）
- `announce-hostnames yes`：使用主机名进行公告

---

### 3. Docker Compose 编排文件 (`docker-compose.yml`)

```yaml
version: '3.8'

networks:
  redis-net:
    driver: bridge

volumes:
  redis-master-data:
  redis-slave1-data:
  redis-slave2-data:

services:
  # --- Redis 存储层 ---
  redis-master:
    image: redis:7.0
    container_name: redis-master
    command: redis-server /etc/redis/redis.conf
    volumes:
      - ./redis/master/conf/redis.conf:/etc/redis/redis.conf
      - redis-master-data:/data
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
      - redis-slave1-data:/data
    networks:
      - redis-net
    ports:
      - "6380:6379"
    depends_on:
      - redis-master

  redis-slave2:
    image: redis:7.0
    container_name: redis-slave2
    command: redis-server /etc/redis/redis.conf
    volumes:
      - ./redis/slave2/conf/redis.conf:/etc/redis/redis.conf
      - redis-slave2-data:/data
    networks:
      - redis-net
    ports:
      - "6381:6379"
    depends_on:
      - redis-master

  # --- Sentinel 监控层 ---
  sentinel1:
    image: redis:7.0
    container_name: redis-sentinel1
    command: >
      sh -c "cp /conf/sentinel.conf /tmp/sentinel.conf &&
      chmod 777 /tmp/sentinel.conf &&
      redis-sentinel /tmp/sentinel.conf"
    volumes:
      - ./sentinel/sentinel1/conf/sentinel.conf:/conf/sentinel.conf
    networks:
      - redis-net
    ports:
      - "26379:26379"
    depends_on:
      - redis-master
      - redis-slave1
      - redis-slave2

  sentinel2:
    image: redis:7.0
    container_name: redis-sentinel2
    command: >
      sh -c "cp /conf/sentinel.conf /tmp/sentinel.conf &&
      chmod 777 /tmp/sentinel.conf &&
      redis-sentinel /tmp/sentinel.conf"
    volumes:
      - ./sentinel/sentinel2/conf/sentinel.conf:/conf/sentinel.conf
    networks:
      - redis-net
    ports:
      - "26380:26379"
    depends_on:
      - redis-master
      - redis-slave1
      - redis-slave2

  sentinel3:
    image: redis:7.0
    container_name: redis-sentinel3
    command: >
      sh -c "cp /conf/sentinel.conf /tmp/sentinel.conf &&
      chmod 777 /tmp/sentinel.conf &&
      redis-sentinel /tmp/sentinel.conf"
    volumes:
      - ./sentinel/sentinel3/conf/sentinel.conf:/conf/sentinel.conf
    networks:
      - redis-net
    ports:
      - "26381:26379"
    depends_on:
      - redis-master
      - redis-slave1
      - redis-slave2
```

**编排要点说明：**

1. **网络隔离**：所有容器运行在自定义桥接网络 `redis-net` 中，实现网络隔离
2. **数据持久化**：使用 Docker 命名卷（`redis-master-data` 等）映射数据目录，防止容器删除后数据丢失
3. **哨兵配置文件处理**：通过 `cp` 命令将只读挂载的配置文件复制到可写位置，解决哨兵运行时需要重写配置文件的问题
4. **端口映射**：主节点 6379、从节点 6380/6381、哨兵 26379/26380/26381 均映射到宿主机
5. **启动依赖**：使用 `depends_on` 确保主节点先于从节点和哨兵启动

---

### 4. 部署与验证

#### 4.1 启动集群

```bash
cd redis-cluster-lab
docker-compose up -d
```

#### 4.2 验证主从复制

**Master 节点状态：**

```
> docker exec redis-master redis-cli info replication

# Replication
role:master
connected_slaves:2
slave0:ip=172.23.0.3,port=6379,state=online,offset=3750,lag=0
slave1:ip=172.23.0.4,port=6379,state=online,offset=3750,lag=0
master_failover_state:no-failover
master_replid:2b4fea85acf3d5e3c5730d1c2dd7574eb1d519b9
master_replid2:0000000000000000000000000000000000000000
master_repl_offset:3805
```

**分析：** `role:master` 确认当前节点为主节点，`connected_slaves:2` 显示已连接 2 个从节点，两个从节点状态均为 `online`，复制偏移量同步一致。

**Slave1 节点状态：**

```
> docker exec redis-slave1 redis-cli info replication

# Replication
role:slave
master_host:redis-master
master_port:6379
master_link_status:up
master_last_io_seconds_ago:1
```

**Slave2 节点状态：**

```
> docker exec redis-slave2 redis-cli info replication

# Replication
role:slave
master_host:redis-master
master_port:6379
master_link_status:up
master_last_io_seconds_ago:0
```

**分析：** 两个从节点均显示 `role:slave`，`master_link_status:up` 表示与主节点的连接正常。

#### 4.3 验证数据同步

在主节点写入数据，验证从节点自动同步：

```
> docker exec redis-master redis-cli set testkey "hello from master"
OK

> docker exec redis-slave1 redis-cli get testkey
"hello from master"

> docker exec redis-slave2 redis-cli get testkey
"hello from master"
```

**分析：** 主节点写入的数据在两个从节点上均可读取，证明主从复制机制工作正常。

#### 4.4 验证哨兵监控

```
> docker exec redis-sentinel1 redis-cli -p 26379 sentinel master mymaster

 1: name
 2: mymaster
 3: ip
 4: redis-master
 5: port
 6: 6379
 7: flags
 8: master
 9: num-slaves
10: 2
11: num-other-sentinels
12: 2
13: quorum
14: 2
15: failover-timeout
16: 10000
17: down-after-milliseconds
18: 5000
```

**分析：**
- `num-slaves:2`：哨兵正确识别了 2 个从节点
- `num-other-sentinels:2`：当前哨兵发现了另外 2 个哨兵节点，共 3 个哨兵
- `quorum:2`：法定人数正确设置为 2
- 集群处于完全健康状态

---

### 5. 故障模拟实验

#### 5.1 注入故障

使用 `docker pause` 暂停主节点（暂停进程但保留容器在网络中的 DNS 记录）：

```
> docker pause redis-master
redis-master
```

#### 5.2 观察哨兵故障转移日志

等待约 15 秒后，查看哨兵日志：

```
> docker logs redis-sentinel1 2>&1 | grep -E "sdown|odown|failover|switch-master|vote-for-leader|new-epoch|promoted"

11:X 27 Apr 2026 12:02:16.946 # +sdown master mymaster redis-master 6379
11:X 27 Apr 2026 12:02:17.154 # +new-epoch 1
11:X 27 Apr 2026 12:02:17.187 # +vote-for-leader 8e66fe... 1
11:X 27 Apr 2026 12:02:18.047 # +odown master mymaster redis-master 6379 #quorum 3/2
11:X 27 Apr 2026 12:02:18.231 # +switch-master mymaster redis-master 6379 172.23.0.3 6379
11:X 27 Apr 2026 12:02:23.271 # +sdown slave redis-master:6379 redis-master 6379 @ mymaster 172.23.0.3 6379
```

**故障转移完整时间线分析：**

| 时间 | 事件 | 说明 |
|------|------|------|
| 12:02:16 | `+sdown` | 哨兵1检测到主节点 5 秒无响应，标记为**主观下线（SDOWN）** |
| 12:02:17 | `+new-epoch 1` | 开启新的配置纪元（epoch），用于本次故障转移投票 |
| 12:02:17 | `+vote-for-leader` | 哨兵投票选举领头哨兵（Sentinel Leader） |
| 12:02:18 | `+odown #quorum 3/2` | 达到法定人数（3 票 > quorum 2），标记为**客观下线（ODOWN）** |
| 12:02:18 | `+switch-master` | 完成主从切换，新主节点为 `172.23.0.3`（原 redis-slave2） |
| 12:02:23 | `+sdown slave` | 旧主节点被检测到仍处于下线状态，作为从节点标记为下线 |

#### 5.3 验证新主节点

```
> docker exec redis-slave2 redis-cli info replication

# Replication
role:master
connected_slaves:1
slave0:ip=172.23.0.4,port=6379,state=online,offset=11971,lag=0
master_failover_state:no-failover
```

**分析：** 原 `redis-slave2` 被提升为新主节点（`role:master`），`redis-slave1` 已连接为从节点。

#### 5.4 恢复原主节点

```
> docker unpause redis-master
redis-master

> docker exec redis-master redis-cli info replication

# Replication
role:slave
master_host:172.23.0.3
master_port:6379
master_link_status:up
master_last_io_seconds_ago:0
```

**分析：** 原主节点恢复后，自动被哨兵降级为从节点（`role:slave`），并成功连接到新主节点（`master_link_status:up`）。

验证新主节点此时拥有完整的 2 个从节点：

```
> docker exec redis-slave2 redis-cli info replication

# Replication
role:master
connected_slaves:2
slave0:ip=172.23.0.4,port=6379,state=online,offset=40675,lag=1
slave1:ip=172.23.0.2,port=6379,state=online,offset=40945,lag=1
master_failover_state:no-failover
```

---

## 四、重点分析

### 1. 主节点宕机后，哨兵如何选出新主节点？

主节点宕机后，哨兵选举新主节点的过程分为两个阶段，体现了 **Raft 算法**的核心思想：

#### 第一阶段：领头哨兵选举（Sentinel Leader Election）

当一个哨兵发现 Master **客观下线（ODOWN）**后（即达到 Quorum 票数确认），它不会直接执行故障转移，而是先发起**领头哨兵选举**：

1. 发现 ODOWN 的哨兵向其他所有哨兵发送 `SENTINEL is-master-down-by-addr` 请求，提议自己为 Leader
2. 其他哨兵采用**先到先得（FIFO）**原则投票——每个纪元（epoch）只能投一票
3. 获得半数以上票数（即 ≥ `⌈N/2⌉ + 1`，本实验中 3 个哨兵需要至少 2 票）的哨兵成为 Leader
4. Leader 全权负责本次故障转移，避免多个哨兵同时执行导致混乱

本实验中的日志印证了这一过程：
- `+new-epoch 1`：开启第 1 纪元
- `+vote-for-leader`：哨兵投票选举 Leader
- `+odown #quorum 3/2`：3 个哨兵中有 3 个确认下线，远超 quorum 2

#### 第二阶段：新主节点挑选（Slave Promotion）

领头哨兵在健康的从节点中按以下优先级顺序挑选新的 Master：

1. **过滤不健康节点**：排除已断开连接、响应缓慢或处于 SDOWN 状态的从节点
2. **比较优先级**：`slave-priority` 值越小优先级越高（默认均为 100）
3. **比较复制偏移量**：`repl-offset` 最大的从节点胜出——偏移量越大意味着从主节点同步的数据越多，数据最完整
4. **比较运行 ID**：若以上条件全部相同，则按 `run_id` 字典序最小者胜出（作为最终兜底策略）

选中后，Leader 哨兵向该从节点发送 `SLAVEOF NO ONE` 命令将其提升为 Master，然后通知其他从节点复制新 Master。

---

### 2. 若哨兵节点只部署 2 个，在主节点宕机时可能会出现什么问题？

这是分布式系统中的经典**高可用失效与脑裂风险**问题，也是 **CAP 理论**中对 C（一致性）和 P（分区容错性）取舍的具体体现：

#### 问题一：无法完成故障转移（丧失可用性）

本实验中 Quorum 设为 2。如果只部署 2 个哨兵，当其中一台哨兵所在的主机或网络发生故障时，剩下的 1 台哨兵即使检测到 Master 宕机，也**永远凑不够 2 票**来确认客观下线（ODOWN）。这直接导致：
- 无法选举出领头哨兵
- 无法执行故障转移
- 整个集群失去写入能力，**系统完全不可用**

#### 问题二：零容错能力

哨兵集群的工作机制要求**大多数（Majority）节点存活**。具体对比：

| 哨兵数量 | Majority | 允许宕机数 | 容错能力 |
|----------|----------|-----------|---------|
| 3 个 | 2 | 1 | 正常 |
| 2 个 | 2 | 0 | **无容错** |
| 5 个 | 3 | 2 | 高 |

2 个哨兵允许宕机数为 0，意味着任何一台哨兵挂掉，整个高可用机制就失效。这与 3 个哨兵允许 1 台宕机形成鲜明对比。

#### 问题三：与 CAP 理论的关联

在 CAP 理论框架下：
- **C（一致性）**：哨兵通过 Quorum 机制确保只有大多数节点同意才能执行故障转移，避免脑裂导致双主
- **A（可用性）**：3 个哨兵保证了在 1 台故障时仍能完成故障转移，维持系统可用
- **P（分区容错）**：网络分区是不可避免的客观现实

2 个哨兵的配置在面临网络分区时，无法同时满足 C 和 A——要么放弃故障转移（保 C 弃 A），要么降低 Quorum 为 1（保 A 弃 C，但有脑裂风险）。**因此，哨兵数量必须保持奇数（3、5、7...），这是分布式系统的最佳实践。**

---

## 五、实验总结

本实验成功构建了 Redis 一主二从三哨兵的高可用集群，并通过完整的测试验证了以下核心功能：

1. **主从复制**：Master 写入数据自动同步到两个 Slave 节点，保证了数据冗余
2. **哨兵监控**：3 个 Sentinel 正常监控 Master，能及时发现节点状态变化
3. **自动故障转移**：Master 故障后，Sentinel 通过 Quorum 投票自动完成主观下线 → 客观下线 → 选举 Leader → 提升新 Master 的完整流程
4. **自动降级恢复**：原 Master 恢复后自动作为 Slave 加入集群，无需人工干预

实验过程中还积累了 Docker 环境下的实践经验：
- Docker Desktop WSL2 环境下容器内部 IP 不对宿主机可见，需通过端口映射访问
- Redis 7.0 默认的 diskless 复制模式在 Docker 卷挂载环境下可能存在兼容性问题，建议使用 `repl-diskless-sync no`
- 使用 `docker pause`（而非 `docker stop`）模拟故障可保留 DNS 记录，避免哨兵因 DNS 解析超时进入 tilt 模式
